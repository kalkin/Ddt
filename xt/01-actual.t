use v6;
use Test;
use File::Temp;
use Ddt :TEST;
use JSON::Fast;

plan 2;

subtest "ddt new command", {
    plan 8;
    temp $*CWD = tempdir.IO;
    nok ddt("new").success;
    nok ddt("unknown").success;
    my $r = ddt '--license-name=Apache2', "new", "Foo-Bar";
    unless $r.success {
        diag $r.out;
        diag $r.err;
        skip-rest "Failed to create distribution";
    }
    ok "Foo-Bar".IO.d, "Distribution directory is created";
    chdir "Foo-Bar";
    subtest "All expected files exist", {
        my @expected = <.git  .gitignore  .travis.yml  LICENSE  META6.json  README.md  bin  lib  t>;
        plan @expected.elems;
        for @expected {
            ok $*CWD.child($_).e, "$_ exists"
        }
    }
    ok !"xt".IO.d, "By default no xt/ dir";
    ok "lib/Foo-Bar.pm6".IO.e, "Unit file created";
    ok ddt("test").success, "Tests passed";

    "t/01-fail.t".IO.spurt: q:to/EOF/;
    use Test;
    plan 1;
    ok False;
    EOF
    nok ddt("test").success, "Tests should fail";
}

subtest "META6 description", {
    temp $*CWD = tempdir.IO;
    plan 2;
    my $r = ddt "new", "Hello";
    chdir "Hello";
    my $meta = from-json( "META6.json".IO.slurp );
    is $meta<description>, "blah blah blah", "Default generated description";
    "lib/Hello.pm6".IO.spurt: q:to/EOF/;
    use v6;
    unit module Hello;

    =begin pod

    =head1 NAME

    Hello - This is hello module.

    =head1 DESC

    =end pod
    EOF
    $r = ddt "build";
    unless $r.success {
        diag $r.out;
        diag $r.err;
        skip-rest "Failed to regenerate distribution description";
    }
    $meta = from-json( "META6.json".IO.slurp );
    is $meta<description>, "This is hello module.", "Updated generated description";
}
