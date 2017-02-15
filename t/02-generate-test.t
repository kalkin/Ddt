use v6;
use Test;
use File::Temp;

my class Result {
    has $.out;
    has $.err;
    has $.exit;
    method success() { $.exit == 0 }
}

my $base = $*SPEC.catdir($?FILE.IO.dirname, "..");
sub ddt(*@arg) is export {
    my ($o, $out) = tempfile;
    my ($e, $err) = tempfile;
    my $s = run $*EXECUTABLE, "-I$base/lib", "$base/bin/ddt", |@arg, :out($out), :err($err);
    .close for $out, $err;
    my $r = Result.new(:out($o.IO.slurp), :err($e.IO.slurp), :exit($s.exitcode));
    unlink($_) for $o, $e;
    $r;
}

plan 1;

subtest "Generate a test file", {
    plan 2;
    temp $*CWD = tempdir.IO;
    ddt "new", "Foo::Bar";
    chdir "Foo-Bar";
    ok ddt('generate', 'test', 'foo'), "Generate test command exited succesful";
    ok <t/foo.t>.IO.e, "Test file was created";
}
