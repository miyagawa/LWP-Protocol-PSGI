package LWP::Protocol::PSGI;

use strict;
use 5.008_001;
our $VERSION = '0.02';

use parent qw(LWP::Protocol);
use HTTP::Message::PSGI qw( req_to_psgi res_from_psgi );
use Guard;
use Carp;

my @protocols = qw( http https );
my %orig;

my $app;

sub register {
    my $class = shift;
    $app = shift;

    for my $proto (@protocols) {
        if (my $orig = LWP::Protocol::implementor($proto)) {
            $orig{$proto} = $orig;
            LWP::Protocol::implementor($proto, $class);
        } else {
            Carp::carp("LWP::Protocol::$proto is unavailable. Skip registering overrides for it.") if $^W;
        }
    }

    if (defined wantarray) {
        return guard { $class->unregister };
    }
}

sub unregister {
    my $class = shift;
    for my $proto (@protocols) {
        if ($orig{$proto}) {
            LWP::Protocol::implementor($proto, $orig{$proto});
        }
    }
}

sub request {
    my($self, $request) = @_;
    my $env = req_to_psgi $request;
    res_from_psgi $app->($env);
}

1;
__END__

=encoding utf-8

=for stopwords

=head1 NAME

LWP::Protocol::PSGI - Override LWP's HTTP/HTTPS backend with your own PSGI applciation

=head1 SYNOPSIS

  use LWP::UserAgent;
  use LWP::Protocol::PSGI;

  # can be Mojolicious, Catalyst ... any PSGI application
  my $psgi_app = do {
      use Dancer;
      setting apphandler => 'PSGI';
      get '/search' => sub {
          return 'googling ' . params->{q};
      };
      dance;
  };

  LWP::Protocol::PSGI->register($psgi_app);

  # can hijack any code or module that uses LWP::UserAgent underneath, with no changes
  my $ua  = LWP::UserAgent->new;
  my $res = $ua->get("http://www.google.com/search?q=bar");
  print $res->content; # "googling bar"

=head1 DESCRIPTION

LWP::Protocol::PSGI is a module to hijack B<any> code that uses
L<LWP::UserAgent> underneath such that any HTTP or HTTPS requests can
be routed to your own PSGI application.

Because it works with any code that uses LWP, you can override various
WWW::*, Net::* or WebService::* modules such as L<WWW::Mechanize>,
without modifying the calling code or its internals.

  use WWW::Mechanize;
  use LWP::Protocol::PSGI;

  LWP::Protocol::PSGI->register($my_psgi_app);

  my $mech = WWW::Mechanize->new;
  $mech->get("http://amazon.com/"); # $my_psgi_app runs

=head1 METHODS

=over 4

=item register

  LWP::Protocol::PSGI->register($app);
  my $guard = LWP::Protocol::PSGI->register($app);

Registers an override hook to hijack HTTP requests. If called in a
non-void context, returns a L<Guard> object that automatically resets
the override when it goes out of context.

  {
      my $guard = LWP::Protocol::PSGI->register($app);
      # hijack the code using LWP with $app
  }

  # now LWP uses the original HTTP implementations

=item unregister

  LWP::Protocol::PSGI->unregister;

Resets all the overrides for LWP. If you use the guard interface
described above, it will be automatically called for you.

=back

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

=head1 COPYRIGHT

Copyright 2011- Tatsuhiko Miyagawa

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Plack::Client> L<LWP::UserAgent>

=cut
