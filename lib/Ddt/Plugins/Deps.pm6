use Ddt;
use Ddt::Distribution;
unit module Ddt::Plugins::Deps;

#| Show all the modules used (HACK!)
multi MAIN('deps', 'distri', Bool:D :v($verbose) = False) is export {

    my $ddt = Ddt::Distribution.new: TOPDIR;
    all-deps $ddt, $ddt.bin-dir, $ddt.lib-dir, $ddt.test-dir
    ==> my @imports;

    note "Searching distributions providing {@imports.join: ', '}.";
    note "This may take a few seconds";

    my @candidates = search-unit(@imports);
    my %result;
    for @candidates {
        my $dist = $_.dist;
        my $name = $dist.name;
        next if $name.ends-with('::bin');
        unless %result{$name}:exists {
            my @provides = $dist.provides.keys.grep(* ∈ @imports).grep(* !~~ $name);
            %result{$name} = @provides;
        }
    }
    if $verbose {
        for %result.kv -> $name, @deps {
            say $name, @deps.elems ?? ":" !! "";
            for @deps -> $d { say "\t$d" }
        }
    } else {
        for %result.keys.sort { .say };
    }
}

# List all foreign units used.
multi MAIN('deps', Bool:D :u(:$update) = False) is export {
    my $ddt = Ddt::Distribution.new: TOPDIR;
    my @depends = all-deps $ddt, $ddt.bin-dir, $ddt.lib-dir;
    print-diff($ddt.META6.depends, @depends, "D");

    my @test-depends = all-deps $ddt, $ddt.test-dir;

    print-diff($ddt.META6.test-depends, @test-depends, "T");

    if $update {
        $ddt.META6.depends = @depends;
        $ddt.META6.test-depends = @test-depends;
        $ddt.generate-META6;
    }
}

sub print-diff(@a, @b, $prefix) {
    for (@a ∪ @b).keys.sort -> $d {
        when $d ∉ @b {
            say "- $prefix: $d";
        }
        when $d (elem) @b {
            if $d (elem) @a {
                say "  $prefix: $d";
            } else {
                say "+ $prefix: $d";
            }
        }
    }
}

sub all-deps(Ddt::Distribution:D $ddt, *@paths where { $_.all ~~ IO::Path:D }) {
    my %own-units = $ddt.find-provides;
    @paths  ==> map *.files()
            ==> flat()
            ==> map *.lines
            ==> flat()
            ==> grep({ $_ ~~ m/^\s* use \s* (.*) ‘;’$/ })
            ==> map(-> $l is copy {
                $l ~~ s/^\h* use \h* (\S*) ‘;’$/$0/;
            })
            ==> grep( { $_ if $_ } )
            ==> map({ $_[0].Str })
            ==> unique()
            ==> grep !*.contains: '$'
            ==> grep none <nqp v6 Test>
            ==> grep * ∉ %own-units.keys
            ==> sort()
            ==> my @imports;

}
