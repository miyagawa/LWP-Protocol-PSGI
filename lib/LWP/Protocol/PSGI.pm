package LWP::Protocol::PSGI;

use strict;
use 5.008_001;
our $VERSION = '0.03';

use parent qw(LWP::Protocol);
use HTTP::Message::PSGI qw( req_to_psgi res_from_psgi );
use Guard;
use Carp;

my @protocols = qw( http https );
my %orig;
my %options;

my $app;

sub register {
    my $class = shift;
    $app = shift;

    %options = @_;

    for my $proto (@protocols) {
        if (my $orig = LWP::Protocol::implementor($proto)) {
            $orig{$proto} = $orig;
            LWP::Protocol::implementor($proto, $class);
        } else {
            Carp::carp("LWP::Protocol::$proto is unavailable. Skip registering overrides for it.") if $^W;
        }
    }

    if (defined wantarray) {
        return guard { $class->unregister; %options = () };
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

    if ($self->handles($request)) {
        my $env = req_to_psgi $request;
        res_from_psgi $app->($env);
    } else {
        $orig{$self->{scheme}}->new($self->{scheme}, $self->{ua})->request($request);
    }
}

# for testing
sub create {
    my($class, %opt) = @_;
    %options = %opt;
    $class->new;
}

sub handles {
    my($self, $request) = @_;

    if ($options{host}) {
        $self->_matcher($options{host})->($request->uri->host);
    } elsif ($options{uri}) {
        $self->_matcher($options{uri})->($request->uri);
    } else {
        1;
    }
}

sub _matcher {
    my($self, $stuff) = @_;
    if (ref $stuff eq 'Regexp') {
        sub { $_[0] =~ $stuff };
    } elsif (ref $stuff eq 'CODE') {
        $stuff;
    } elsif (!ref $stuff) {
        sub { $_[0] eq $stuff };
    } else {
        croak "Don't know how to match: ", ref $stuff;
    }
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

  # Register the $psgi_app to handle all LWP requests
  LWP::Protocol::PSGI->register($psgi_app);

  # can hijack any code or module that uses LWP::UserAgent underneath, with no changes
  my $ua  = LWP::UserAgent->new;
  my $res = $ua->get("http://www.google.com/search?q=bar");
  print $res->content; # "googling bar"

  # Only hijacks specific hosts
  LWP::Protocol::PSGI->register($psgi_app, host => 'localhost:3000');

  my $ua = LWP::UserAgent->new;
  $ua->get("http://localhost:3000/app"); # this routes $psgi_app
  $ua->get("http://google.com/api");     # this doesn't - handled with actual HTTP requests

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

  LWP::Protocol::PSGI->register($app, %options);
  my $guard = LWP::Protocol::PSGI->register($app, %options);

Registers an override hook to hijack HTTP requests. If called in a
non-void context, returns a L<Guard> object that automatically resets
the override when it goes out of context.

  {
      my $guard = LWP::Protocol::PSGI->register($app);
      # hijack the code using LWP with $app
  }

  # now LWP uses the original HTTP implementations

When C<%options> is specified, the option limits which URL and hosts
this handler overrides. You can either pass C<host> or C<uri> to match
requests, and if it doesn't match, the handler falls back to the
original LWP HTTP protocol implementor.

  LWP::Protocol::PSGI->register($app, host => 'www.google.com');
  LWP::Protocol::PSGI->register($app, host => qr/\.google\.com$/);
  LWP::Protocol::PSGI->register($app, uri => sub { my $uri = shift; ... });

The options can take eithe a string, where it does a complete match, a
regular expression or a subroutine reference that returns boolean
given the value of C<host> (only the hostname) or C<uri> (the whole
URI, including query parameters).

=item unregister

  LWP::Protocol::PSGI->unregister;

Resets all the overrides for LWP. If you use the guard interface
described above, it will be automatically called for you.

=back

=head1 SEE ALSO

L<Test::LWP::UserAgent>

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
