use strict;
use Test::More;
use LWP::UserAgent;
use LWP::Protocol::PSGI;

my $psgi_app = sub {
    my $env = shift;
    return [
        200,
        [
            "Content-Type", "text/plain",
            "X-Foo" => "bar",
        ],
        [ "query=$env->{QUERY_STRING}" ],
    ];
};

{
    my $guard = LWP::Protocol::PSGI->register($psgi_app);

    my $ua  = LWP::UserAgent->new;
    my $res = $ua->get("http://www.google.com/search?q=bar");
    is $res->content, "query=q=bar";
    is $res->header('X-Foo'), "bar";

    use LWP::Simple;
    my $body = get "http://www.google.com/?q=x";
    is $body, "query=q=x";
}

done_testing;

