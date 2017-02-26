use v6;
use File::Temp;
use Zef;
use Zef::Client;
use Zef::Config;
use Zef::Identity;

unit module Ddt;

sub to-name(Str:D $name, Str $dist-prefix?) of Str:D is export {
    when  !$dist-prefix.defined {
        if $name.starts-with: '::' {
            die 'unit name starts with "::" but no $dist-prefix provided'
        }
        return $name
    }
    when $name.starts-with: $dist-prefix { return $name }
    when $name.starts-with: '::'         { return $dist-prefix ~ $name }
    default { return $dist-prefix ~ '::' ~ $name }
}

sub name-to-file(Str:D $name) of Str:D is export {
    join("/",  gather for $name.split('::') -> $c {
        take $c
    }) ~ ".pm6"
}

sub author is export { qx{git config --global user.name}.chomp }
sub email is export { qx{git config --global user.email}.chomp }
sub TOPDIR of IO::Path:D is export {
    my Proc:D $proc = Proc.new(:out, :err);
    $proc.shell: 'git rev-parse --show-toplevel';
    my $dir = $proc.out.slurp-rest;
    unless $dir {
        return fail "Not in a repository"
    }
    return $dir.chomp.IO
}

class Result is export(:TEST) {
    has $.out;
    has $.err;
    has $.exit;
    method success() { $.exit == 0 }
}

sub ddt(*@arg) is export(:TEST) {
    my $base = $*SPEC.catdir($?FILE.IO.dirname, "..");
    my ($o, $out) = tempfile;
    my ($e, $err) = tempfile;
    my $s = run $*EXECUTABLE, "-I$base/lib", "$base/bin/ddt", |@arg, :out($out), :err($err);
    .close for $out, $err;
    my $r = Result.new(:out($o.IO.slurp), :err($e.IO.slurp), :exit($s.exitcode));
    unlink($_) for $o, $e;
    $r;
}


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

sub search-unit(*@names) is export {
    $zef-client = get-client unless $zef-client.defined;
    $zef-client.search( @names.map(&str2identity) );
}

sub unit-fetch(Zef::Distribution:D $distri) is export {
    $zef-client = get-client unless $zef-client.defined;
    $zef-client.fetch($distri);
}

sub local-mirror($uri) of IO::Path:D is export {
    $zef-client = get-client unless $zef-client.defined;
    $zef-client.config<TempDir>.IO.child($uri.IO.basename)
}

=begin pod

=head1 NAME

Ddt - Distribution Development Tool similar to mi6

=head1 SYNOPSIS

  > ddt new Foo::Bar # create Foo-Bar distribution
  > cd Foo-Bar
  > ddt build        # build the distribution and re-generate README.md & META6.json
  > ddt test         # Run tests

=head1 INSTALLATION

  # with zef
  > zef install Ddt

=head1 DESCRIPTION

Ddt is an authoring and distribution development tool for Perl6.

=head2 Features

=item Create new distribution
=item Hack existing distribution
=item Build distribution
=item Test distribution
=item List distributions dependencies (even those not added to META6.json yet)
=item Sync module imports to META6.json

=head3 New distribution scaffolding

=item Create a distribution skeleton for Perl6

=item Generate README.md from lib/Main/Module.pm6's pod

=item Generate a META6.json

=item Generate a META test by default

=item Support for different licenses


=head2 Differences to Mi6

=item Support for different licenses via C<License::Software>

=item META6 is generated using C<META6>

=item Meta test

=item Use zef for tests

=item Extended .gitignore

=item Support for different licenses

=item Support for Distributions with a hyphen in the namel

=head1 FAQ

=item How can I manage depends, build-depends, test-depends?

  Write them to META6.json directly :)

=item Where is Changes file?

  TODO

=item Where is the spec of META6.json?

  Maybe https://github.com/perl6/ecosystem/blob/master/spec.pod or http://design.perl6.org/S22.html

=item How do I remove travis badge?

  Remove .travis.yml

=head1 SEE ALSO

L<<https://github.com/tokuhirom/Minilla>>

L<<https://github.com/rjbs/Dist-Zilla>>

=head1 AUTHOR

=item Bahtiar `kalkin-` Gadimov <bahtiar@gadimov.de>

=item Shoichi Kaji <skaji@cpan.org>

=head1 COPYRIGHT AND LICENSE

=item Copyright © 2015 Shoichi Kaji
=item Copyright © 2016-2017 Bahtiar `kalkin-` Gadimov

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
