use META6;
use File::Find;
use License::Software;
use Ddt::Template;
unit class Ddt::Distribution;

has META6 $.META6;
has Str $.main-comp-unit;
has Bool $.relaxed-name = '-' ∈ $!META6.name.comb;
has IO::Path $.main-dir where *.d;
has IO::Path $.meta-file where *.f;
has IO::Path $.bin-dir   = $!main-dir.child(<bin>);
has IO::Path $.hooks-dir = $!main-dir.child(<hooks>);
has IO::Path $.lib-dir   = $!main-dir.child(<lib>);
has IO::Path $.test-dir  = $!main-dir.child(<t>);

multi method new(IO::Path $meta-file) {
    my META6 $meta = META6.new(file => $meta-file);
    self.bless: META6 => $meta,
                meta-file => $meta-file,
                main-dir => $meta-file.parent,
                main-comp-unit => $meta.name.subst('-', '::', :g)
}
multi method new(Str $meta-file) { self.new($meta-file.IO) }

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
    $meta.license = self!license.url unless !$meta.license.defined;

    $.meta-file.IO.spurt: $meta.to-json: :skip-null;
}

method generate-README {
    my $module-file = self!name-to-file: $.main-comp-unit;
    my @cmd = $*EXECUTABLE, "--doc=Markdown", "-I$.lib-dir", $module-file;
    my $p = run(|@cmd, :out);
    die "Failed @cmd[]" if $p.exitcode != 0;
    my $markdown = $p.out.slurp-rest;
    my ($user, $repo) = guess-user-and-repo();
    my $header = do if $user and ".travis.yml".IO.e {
        "[![Build Status](https://travis-ci.org/$user/$repo.svg?branch=master)]"
            ~ "(https://travis-ci.org/$user/$repo)"
            ~ "\n\n";
    } else {
        "";
    }

    $.main-dir.child("README.md").spurt: $header ~ $markdown;
}

method !make-content {
    my $license = self!license;
    my $module = $.META6.name.subst: '-', '::', :g;
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


method !license of License::Software::Abstract {
    License::Software::from-url($.META6.license).new: author() ~ " " ~ email();
}

method find-provides {
    find dir => $!lib-dir, name => /\.pm6?$/
        ==> map { self!to-module($_) => $_.relative($.main-dir) } ==> sort;
}

sub author { qx{git config --global user.name}.chomp }
sub email { qx{git config --global user.email}.chomp }
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
    $url .= Str;
    $url ~~ s/^https?/git/; # panda does not support http protocol
    if $url ~~ m/'git@' $<host>=[.+] ':' $<repo>=[<-[:]>+] $/ {
        $url = "git://$<host>/$<repo>";
    } elsif $url ~~ m/'ssh://git@' $<rest>=[.+] / {
        $url = "git://$<rest>";
    }
    $url;
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
    $module.subst('-', '::', :g);
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
