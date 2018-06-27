use Ddt;
use Ddt::Distribution;
use License::Software;
use Zef::Distribution;
use META6;

#| Create new module
multi MAIN("new",
            $module is copy, #= Module::To::Create
            :$license-name = 'GPLv3' #= License name
        ) is export
{
    my $main-dir = $module.subst: '::', '-', :g;
    die "Already exists $main-dir" if $main-dir.IO ~~ :d;

    mkdir $main-dir;
    my $license-holder = author() ~ " " ~ email();
    my $spdx = License::Software::get($license-name).new($license-holder).spdx;
    my $meta = META6.new:   name => $module,
                            authors => [author()],
                            license => $spdx,
                            version => Version.new('0.0.1'),
                            perl-version => $*PERL.version;

    my $meta-file = $main-dir.IO.child(<META6.json>);
    $meta-file.spurt: $meta.to-json(:skip-null);
    my $ddt = Ddt::Distribution.new: $meta-file;
    $ddt.generate-all: :force;
    note "Successfully created $main-dir";
}

#| Build the module in current directory
multi MAIN("build") is export 
{
    my $ddt = Ddt::Distribution.new: TOPDIR;
    $ddt.generate-README;
    $ddt.generate-META6;
    return unless "Build.pm".IO.e;
    run "zef", "build", ".";
}

#| Run distribution tests
multi MAIN("test",
            Str  :$state,       #= Control prove's persistent state
            Bool :$timer,       #= Print elapsed time after each test
            Bool :v(:$verbose), #= Print all test lines
            Bool :c(:$color),   #= Colored test output (default when terminal)
            Bool :C(:$continues), # Run tests on file change
                 *@tests        #= Files or directories
           ) is export
{
    temp $*CWD = TOPDIR;
    if @tests ~~ Empty {
        @tests.push: TOPDIR.child(<t>) if TOPDIR.child(<t>) ~~ :e & :d;
        @tests.push: TOPDIR.child(<xt>) if TOPDIR.child(<xt>) ~~ :e & :d;
    }
    my Str @args = [];
    my $ddt = Ddt::Distribution.new: TOPDIR;
    @args.push: '--timer' if $timer.defined;
    @args.push: '-c' if $color.defined || $*IN.t;
    @args.push: '-v' if $verbose.defined;
    @args.push: "--state=$state" if $state.defined;

    if $continues {
        my Proc::Async $proc .= new: 'prove', @args, '--exec', 'perl6 -Ilib', @tests;
        $proc.start;

        $ddt.watch.act: {
            with $proc { .kill(9) }
            say "Restarting tests";
            $proc = Proc::Async.new: 'prove', @args, '--exec', 'perl6 -Ilib', @tests;
            $proc.start;
        };
        without $proc { $proc = Proc::Async.new: 'prove', @args, '--exec', 'perl6 -Ilib', @tests;}
        loop { FIRST { say "Waiting for changes" } }
    } else {
        run 'prove', @args, '--exec', 'perl6 -Ilib', @tests;
    }
}

#| Make release
multi MAIN("release") is export
{
    my $ddt = Ddt::Distribution.new: TOPDIR;
    my ($user, $repo) = guess-user-and-repo($ddt.META6<source-url>);
    my Str:D $meta-file = $ddt.meta-file.basename;
    my Str:D $module = $ddt.name;
    die "Cannot find user and repository settting" unless $repo;
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
        die "You are already in a repository please specify exact dir to clone to"
    }

    my @candidates = search-unit($identity);
    unless @candidates {
        note "No candidates found";
        exit 1;
    }

    my Str:D $target = ($dir || cand-name @candidates.first);
    die "Directory $target already exists" if $target.IO.e;

    my Str:D $uri = @candidates.first.dist.source-url;

    my (:@remote, :@local) := @candidates.classify: {.dist !~~ Zef::Distribution::Local ?? <remote> !! <local>}
    unless @local.first {
        @local.push: unit-fetch(@remote[0])
    }

    my $candi = @local.first;
    my IO::Path:D $local-mirror = local-mirror $uri;
    say qqx{git clone $uri --reference $local-mirror.Str() $target};
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

