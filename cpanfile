requires 'Guard';
requires 'HTTP::Message::PSGI';
requires 'LWP', '5';
requires 'LWP::Protocol';
requires 'parent';
requires 'perl', '5.008001';

on build => sub {
    requires 'ExtUtils::MakeMaker', '6.59';
    requires 'Test::More', '0.88';
    requires 'Test::Requires';
};
