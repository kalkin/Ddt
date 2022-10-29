use Ddt;
use Ddt::Distribution;

use META6;
use License::Software:ver<0.3.*>;

unit module Ddt::Plugins::New;

#| Create new module
multi MAIN("new",
            $module, #= Module::To::Create
            :$license-name = 'Artistic2' #= License name
        ) is export
{
    my $main-dir = $module.subst: '::', '-', :g;
    if $main-dir.IO ~~ :d {
        note "Already exists $main-dir";
        exit 1;
    }

    mkdir $main-dir;
    populate-dir $main-dir, $module, $license-name;
}


#| Create new module
multi MAIN("new",
            "here", #= create the module based on the current folder
            :$license-name = 'Artistic2', #= License name
            Bool :$as-name #= interpret the first argument of 'new' as module name
        ) is export
{
    nextsame if $as-name;
    populate-dir $*CWD, $*CWD.basename, $license-name;
}

sub populate-dir(IO() $main-dir, $module-name, $license-name) {
    my $license-holder = git-user() ~ " " ~ git-email;
    my $spdx = (quietly license($license-name)).?new($license-holder).?spdx // $license-name;
    my $meta = META6.new:   name => $module-name,
                            authors => [git-user],
                            license => $spdx // $license-name,
                            version => Version.new('0.0.1'),
                            raku-version => $*RAKU.version;

    my $meta-file = $main-dir.child(<META6.json>);
    $meta-file.spurt: $meta.to-json(:skip-null);
    my $ddt = Ddt::Distribution.new: $meta-file;
    $ddt.generate-all: :force;
    note "Successfully created $main-dir";
}
