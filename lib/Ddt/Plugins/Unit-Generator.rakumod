use Ddt;
use Ddt::Distribution;
unit module Ddt::Plugins::Unit-Generator;

subset Unit of Str where * eq "class"|"role"|"package"|"grammar"|"module";

#| Generate a unit
sub generate(
    Unit:D $unit,           #= class, , role package, grammer or module
    Str:D $name is copy,    #= Unit name i.e Foo::Bar
    )  {
    my $dist = Ddt::Distribution.new: TOPDIR;
    my Str:D $prefix = $dist.META6<provides>.keys.sort[0];

    $name = to-name $name, $prefix;

    my $path = TOPDIR.child(<lib>).child(name-to-file $name);

    my IO::Path:D $parent-dir = $path.dirname.IO;
    $parent-dir.mkdir;

    my $license = $dist.license;
    if $license {
        my $header = $license.header;
        $header = "#`(\n" ~ $header ~ ")\n\n" if $header;
        spurt $path, $header ~ "unit $unit $name;\n", :createonly;
    } else {
        spurt $path, "unit $unit $name;\n", :createonly;
    }
}

#| Generate a class
multi MAIN("generate", "class",
            Str:D $name,    #= Class name i.e Foo::Bar
          ) is export {
    generate "class", $name;
}

#| Generate a role
multi MAIN("generate", "role",
            Str:D $name,    #= role name i.e Foo::Bar
          ) is export {
    generate "role", $name;
}

#| Generate a package
multi MAIN("generate", "package",
            Str:D $name,    #= package name i.e Foo::Bar
          ) is export {
    generate "package", $name;
}

#| Generate a grammar
multi MAIN("generate", "grammar",
            Str:D $name,    #= grammar name i.e Foo::Bar
          ) is export {
    generate "grammar", $name;
}

#| Generate a module
multi MAIN("generate", "module",
            Str:D $name,    #= module name i.e Foo::Bar
          ) is export {
    generate "module", $name;
}

#| Generate stub test file
multi MAIN("generate", "test", 
    Str:D $name is copy #=(Test name),
    Str $description? #=(Test description),
    Bool :f(:$force) = False) {
    my $dist = Ddt::Distribution.new: TOPDIR;

    $name ~= '.t';
    my IO::Path:D $test-dir = TOPDIR.child(<t>);
    my IO::Path:D $new-test = $test-dir.child($name);
    if !$force && $new-test ~~ :e {
        note "A test named $name already exists in dir t/";
        exit -1;
    }
    my $license = $dist.license.?header;
    $license = "#`(\n" ~ $license ~ ')' with $license;
    with $description {
        spurt $new-test, qq:to/END/;
        use v6;
        $license
        use Test;
        plan 1;

        subtest "$description", \{
            flunk "$new-test is not yet implemented";
        \}
        END
    } else {
        spurt $new-test, qq:to/END/;
        use v6;
        $license
        use Test;
        plan 1;

        todo "$new-test is not yet implemented";
        END
    }
}
