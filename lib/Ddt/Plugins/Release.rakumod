use Ddt;
use Ddt::Distribution;
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

    1. Fork https://github.com/Raku/ecosystem repository.
    2. Add https://raw.githubusercontent.com/$user/$repo/master/$meta-file to META.list.
    3. And raise a pull request!


    Once your pull request is merged, we can install your module by:

    \$ zef install $module
    EOF
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

