use Ddt;
use Ddt::Distribution;

use META6;
use License::Software:ver<0.2.0>;

unit module Ddt::Plugins::New;

#| Create new module
multi MAIN("new",
            $module is copy, #= Module::To::Create
            :$license-name = 'GPLv3' #= License name
        ) is export
{
    my $main-dir = $module.subst: '::', '-', :g;
    if $main-dir.IO ~~ :d {
        note "Already exists $main-dir";
        exit 1;
    }

    mkdir $main-dir;
    my $license-holder = author() ~ " " ~ email();
    my $spdx = license($license-name).new($license-holder).spdx;
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
