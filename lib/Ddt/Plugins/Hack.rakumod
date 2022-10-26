use Ddt;
use Ddt::Distribution;

use Zef::Distribution;

unit module Ddt::Plugins::Hack;

sub cand-name($candi) of Str:D {
    if $candi.dist.source-url {
        my Str:D $name = $candi.dist.source-url.IO.basename;
        if $name.IO.extension eq 'git' {
            $name = $name.comb[0..*-5].join;
        }
        return $name;
    }
    return $candi.dist.name.subst('::', '-', :g);
}


#| Checkout a Distribution and start hacking on it
multi MAIN("hack", Str:D $identity, Str $dir?) is export {
    if !$dir.defined && TOPDIR().defined {
        note "You are already in a repository please specify exact dir to clone to";
        exit 1;
    }

    my @candidates = search-unit($identity);
    unless @candidates {
        note "No candidates found";
        exit 1;
    }

    my Str:D $target = ($dir || cand-name @candidates.first);
    if $target.IO.e {
        note "Directory $target already exists";
        exit 1;
    }

    my Str $uri;
    unless @candidates.first.dist.source-url {
        note "The project has no source url";
        exit 1;
    }

    $uri = @candidates.first.dist.source-url;

    if $uri ~~ /^.*\.(tar\.gz|tar\.bz2|tar)$/ {
        note "Only found an archive url " ~ $uri;
        exit 1;
    }

    my (:@remote, :@local) := @candidates.classify: {.dist !~~ Zef::Distribution::Local ?? <remote> !! <local>}
    unless @local.first {
        @local.push: unit-fetch(@remote[0])
    }

    my $candi = @local.first;
    my IO::Path:D $local-mirror = local-mirror $uri;
    say qqx{git clone $uri --reference-if-able $local-mirror.Str() $target};
    say "Checked out $uri to $target";
    say "You can now do `cd $target`";
}

