use strict;
use Test::More;
use LWP::UserAgent;
use LWP::Protocol::PSGI;

my $psgi_app = sub { 
    my $env = shift;

    return [
        200,
        [ "Content-Type", "text/plain" ],
        [ "IP:$env->{REMOTE_ADDR} HOST:$env->{REMOTE_HOST}" ],
    ];
};

{
    my $guard = LWP::Protocol::PSGI->register($psgi_app, host => "localhost");
    my $ua  = LWP::UserAgent->new;
    my $res = $ua->get("http://localhost:5000/");
    is $res->content, "IP:127.0.0.1 HOST:localhost";
}

{
    my $guard = LWP::Protocol::PSGI->register($psgi_app, host => "localhost:5000");
    my $ua  = LWP::UserAgent->new(local_address => "127.5.4.1");
    my $res = $ua->get("http://localhost:5000/");
    is $res->content, "IP:127.5.4.1 HOST:localhost";
}

{
    if ($ENV{AUTHOR_TESTING}) { # Don't want to force network requirement do we?
        require Socket;
        my $host = "example.net";
        my $pip = gethostbyname("example.net");
        my $ip = Socket::inet_ntoa($pip);

        my $guard = LWP::Protocol::PSGI->register($psgi_app, host => "localhost:5000");
        my $ua  = LWP::UserAgent->new(local_address => $host);
        my $res = $ua->get("http://localhost:5000/");
        is $res->content, "IP:$ip HOST:$host";
    }
}

done_testing;
