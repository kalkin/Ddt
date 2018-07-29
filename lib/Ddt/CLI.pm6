use Ddt;
use Ddt::Distribution;
use Zef::Distribution;
use META6;

#| Make release
multi MAIN("release") is export
{
    my $ddt = Ddt::Distribution.new: TOPDIR;
    my ($user, $repo) = guess-user-and-repo($ddt.META6<source-url>);
    my Str:D $meta-file = $ddt.meta-file.basename;
    my Str:D $module = $ddt.name;
    unless $repo {
        note "Cannot find user and repository settting";
        exit 1;
    }
    say  qq:to/EOF/;
    Are you ready to release your module? Congrats!
    For this, follow these steps:

    1. Fork https://github.com/perl6/ecosystem repository.
    2. Add https://raw.githubusercontent.com/$user/$repo/master/$meta-file to META.list.
    3. And raise a pull request!


    Once your pull request is merged, we can install your module by:

    \$ zef install $module
    EOF
}

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

sub guess-user-and-repo(Str:D $url) {
    return if $url eq "";
    if $url ~~ m{ (git|https?) '://'
        [<-[/]>+] '/'
        $<user>=[<-[/]>+] '/'
        $<repo>=[.+?] [\.git]?
    $} {
        return $/<user>, $/<repo>;
    } else {
        return;
    }
}

