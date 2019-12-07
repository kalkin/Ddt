use META6;
use JSON::Fast;
use Ddt::JSON;
use File::Find;
use License::Software:ver<0.3.0>;
use Ddt::Template;
use File::Ignore;
unit class Ddt::Distribution;

sub all-files(IO::Path:D $dir, File::Ignore:D $rules) {
    my @todo = [$dir];
    gather while @todo {
        my IO::Path:D $d = shift @todo;
        next unless $d.e;
        for $d.dir {
            when $rules.ignore-path: $_ { next }
            when .d { push @todo, $_}
            when .f { take $_ }
        }
    }
}

sub enhance-io-path-class($o, $rules) {
    $o but role {
        method files {
            all-files(self, $rules);
        }
    }
}

has META6 $.META6;
has Str $.main-comp-unit;
has Bool $.relaxed-name             = '-' ∈ $!META6.name.comb;

has IO::Path $.main-dir  where *.d;
has IO::Path $.meta-file where *.f;

has IO::Path $.vcs-ignore    =  $!main-dir.child(<.gitignore>);
has $.ignore-rules  =  do {
    my Str:D $rules= ".git/*\n";
    $rules ~= $!vcs-ignore.slurp if $!vcs-ignore.e;
    File::Ignore.parse: $rules;
};
has IO::Path $.bin-dir       =  enhance-io-path-class $!main-dir.child(<bin>), $!ignore-rules;
has IO::Path $.hooks-dir     =  $!main-dir.child(<hooks>);
has IO::Path $.lib-dir       =  enhance-io-path-class $!main-dir.child(<lib>), $!ignore-rules;
has IO::Path $.test-dir      =  enhance-io-path-class $!main-dir.child(<t>), $!ignore-rules;

sub find-meta-file(IO::Path:D $top-dir where *.d) of IO::Path:D {
    my IO::Path:D @candidates = $top-dir.child(<META6.json>),
                                $top-dir.child(<META.info>);
    return @candidates.grep(:f & :!l).first;
}

multi method new(IO::Path:D $top-dir where *.d) {
    my $meta-file = find-meta-file $top-dir;
    callwith $meta-file;
}

multi method new(IO::Path $meta-file) {
    my META6 $meta = META6.new(file => $meta-file);
    self.bless: META6 => $meta,
                meta-file => $meta-file,
                main-dir => $meta-file.parent,
                main-comp-unit => $meta.name
}
multi method new(Str $meta-file) { self.new($meta-file.IO) }

method name of Str:D { return $.META6<name>; }

method watch {
    my Supplier $supplier .= new;
    my $rules = $.ignore-rules;
    my @dirs = [$.lib-dir, $.test-dir, $.bin-dir];
    while @dirs {
        my $d = shift @dirs;
        next if !$d.e;
        IO::Notification.watch-path($d).tap: { $supplier.emit: $_ };
        for dir($d) -> $p {
            when $rules.ignore-path($p) { next }
            when $p.d { @dirs.push: $p };
            default { IO::Notification.watch-path($p).tap: { $supplier.emit: $_ } };
        }
    }
    $supplier.Supply.stable(0.5)
}

method generate-all(:$force?) {
    self!make-directories;
    self!make-content;
    self.generate-META6;
    self.generate-README;
    self!init-vcs-repo;
}

method !make-directories {
    $.main-dir.mkdir;
    $.bin-dir.mkdir;
    $.hooks-dir.mkdir;
    $.lib-dir.mkdir;
    $.test-dir.mkdir;
}

method generate-META6 {
    my $meta = $.META6;

    $meta.perl-version = $*PERL.version unless $meta.perl-version.defined;
    if $meta.authors ~~ Empty || author() ∉ $meta.authors {
        $meta.authors.push: author()
    }
    if $meta.test-depends ~~ Empty || "Test::META" ∉ $meta.test-depends {
        $meta.test-depends.push: "Test::META"
    }
    $meta.description = find-description(self!name-to-file: $.main-comp-unit) || $meta.description;
    $meta.provides = self.find-provides;
    $meta.source-url = find-source-url() unless $meta.source-url.defined;
    $meta.version = "*" unless $meta.source-url.defined;
    $meta.license = self.license.spdx unless !$meta.license.defined;

    $.meta-file.IO.spurt: meta-to-json($meta);
}

method generate-README {
    my $module-file = self!name-to-file: $.main-comp-unit;
    my @pcandidates = self.find-pod-for( $module-file );

    for @pcandidates -> $file
    {
        if my $markdown = self.render-markdown( $file )
        {
            my ($user, $repo) = guess-user-and-repo();
            my $header = do if $user and ".travis.yml".IO.e {
                "[![Build Status](https://travis-ci.org/$user/$repo.svg?branch=master)]"
                    ~ "(https://travis-ci.org/$user/$repo)"
                    ~ "\n\n";
            } else {
                "";
            }

            return $.main-dir.child("README.md").spurt: $header ~ $markdown;
        }
    }

    note "Could not find any pod for the README.md"
}

method render-markdown( $file )
{
    if False {
        # Hack for ddt deps command
        use Pod::To::Markdown;
    }
    my @cmd = $*EXECUTABLE, "--doc=Markdown", "-I$.lib-dir", $file;
    my $p = run(|@cmd, :out);
    die "Failed @cmd[]" if $p.exitcode != 0;
    return $p.out.slurp-rest;
}

method find-pod-for( $module-file )
{
    my @candidates =
        "README.pod6",
        $module-file.subst( / \. pm6 $ /, '.pod6'),
        $module-file,
        $module-file.subst( / \. pm6 $ /, '.pod6').subst('lib', 'docs');

    return @candidates.grep({ .IO.e });
}


method !make-content {
    my $license = self.license;
    my $module = $.META6.name;
    my IO::Path $module-file = $.lib-dir;

    for $.main-comp-unit.split(<::>) { $module-file = $module-file.child: $_ };
    $module-file = IO::Path.new: $module-file.Str ~ ".pm6";
    $module-file.parent.mkdir;

    my %content = Ddt::Template::template($module, $license, $.relaxed-name);
    my %map = <<
        $module-file module
        $.test-dir.child(<00-meta.t>)  test-meta
        $.test-dir.child(<01-basic.t>) test
        $.main-dir.child(<.gitignore>)   gitignore
        $.main-dir.child(<.travis.yml>)  travis
    >>;
    for %map.kv -> $f, $c {
        spurt($f, %content{$c});
    }
    for $license.files().kv -> $f, $text {
        spurt($.main-dir.child($f), $text);
    }
}

method !init-vcs-repo {
    my $git-dir = $.main-dir.absolute;
    shell("cd $git-dir && git init", :out).out.slurp-rest;
    shell("cd $git-dir && git add .", :out).out.slurp-rest;
}


method license of License::Software::Abstract {
    license($.META6.license).new: author() ~ " " ~ email();
}

method find-provides {
    find dir => $!lib-dir, name => /\.pm6?$/
        ==> map { self!to-module($_) => $_.relative($.main-dir) } ==> sort;
}

sub author { qx{git config user.name}.chomp }
sub email { qx{git config user.email}.chomp }
sub find-description($module-file) {
    my $content = $module-file.IO.slurp;
    if $content ~~ /^^
        '=' head. \s+ NAME
        \s+
        \S+ \s+ '-' \s+ (\S<-[\n]>*)
    / {
        return $/[0].Str;
    } else {
        return "";
    }
}

# Normalizes the url output by git-remote(1). Transforms ssh git urls of the
# form git@example.com:asd/foo to ssh://git@example.com/asd/foo
submethod normalize-url(Str:D $url --> Str:D) {
    return $url if $url ~~ m/\w+'://'.+/;
    given $url {
        when m/^($<user>=[.+]'@')?$<host>=[.+]':'$<repo>=[.+]$/ {
            return "ssh://{$0<user>}@$<host>/$<repo>" if $[0].defined;
            return "ssh://$<host>/$<repo>"
        }
        when "" { return "" }
    }
    die "Strange url “$url”. Skipping it";
}

sub find-source-url() {
    try my @line = qx{git remote -v 2>/dev/null};
    return "" unless @line;
    my $url = gather for @line -> $line {
        my ($, $url) = $line.split(/\s+/);
        if $url {
            take $url;
            last;
        }
    }
    return "" unless $url;
    return $url;
}

method !to-module(IO::Path $file where *.f) {
    my $dir-sep = $file.SPEC.dir-sep;
    $file.relative($.lib-dir).subst($dir-sep, <::>, :g).subst(/\.pm6?$/, '');
};


method !to-file(Str $module) {
    my $dir-sep = $.lib-dir.SPEC.dir-sep;
    my $file = $module.subst('::', $dir-sep, :g).join ~ ".pm6";
    return $.lib-dir.child($file);
}

method !name-to-file(Str $module is copy) {
    self!to-file: $module;
}

sub guess-user-and-repo() {
    my $url = find-source-url();
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

# A hack for getting identical json on each run
sub meta-to-json(META6 $meta --> Str:D) {
    my %h = from-json($meta.to-json: :skip-null).pairs.grep: *.value !~~ Empty;
    to-sorted-json(%h);
}
