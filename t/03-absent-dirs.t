use v6;
use Test;
use File::Temp;
use Ddt :TEST;

plan 1;

subtest "Handle project directory without a “bin/”", {
    plan 2;
    temp $*CWD = tempdir.IO;
    ddt "new", "Foo-Bar";
    chdir "Foo-Bar";
    "bin".IO.rmdir if "bin".IO.e;
    is "bin".IO.e, False, "”bin/” removed";
    ok ddt('deps').success, "ddt deps handle missing ”bin/”";
}
