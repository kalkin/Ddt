use v6;

use Zef;
use Zef::Client;
use Zef::Config;
use Zef::Identity;

unit module Ddt::Unit;

sub get-client {
    my $config = do {
        # The .Str.IO thing is due to a weird rakudo bug I can't figure out .
        # A bare .IO will complain that its being called on a type Any (not true)
        my $path = Zef::Config::guess-path;
        my $IO   = $path.Str.IO;
        my %hash = Zef::Config::parse-file($path).hash;
        class :: {
            has $.IO;
            has %.hash handles <AT-KEY EXISTS-KEY DELETE-KEY push append iterator list kv keys values>;
        }.new(:%hash, :$IO);
    }
    my $verbosity = DEBUG;
    my $client = Zef::Client.new(:$config);
    my $logger = $client.logger;
    my $log    = $logger.Supply.grep({ .<level> <= $verbosity });
    $log.tap: -> $m {
        given $m.<phase> {
            when BEFORE { say "===> {$m.<message>}" }
            when AFTER  { say "===> {$m.<message>}" }
            default     { say $m.<message> }
        }
    }
    $client;
}

my $zef-client;

sub unit-search(*@names) is export {
    $zef-client = get-client unless $zef-client.defined;
    $zef-client.search(@names.map(&str2identity) );
}


sub unit-fetch(Zef::Distribution:D $distri) is export {
    $zef-client = get-client unless $zef-client.defined;
    $zef-client.fetch($distri);
}

sub local-mirror($uri) of IO::Path:D is export {
    $zef-client = get-client unless $zef-client.defined;
    $zef-client.config<TempDir>.IO.child($uri.IO.basename)
}
