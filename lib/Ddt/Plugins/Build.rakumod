use Ddt;
use Ddt::Distribution;
unit module Ddt::Plugins::Build;

#| Build the module in current directory
multi MAIN("build") is export 
{
    my $ddt = Ddt::Distribution.new: TOPDIR;
    $ddt.generate-README;
    $ddt.generate-META6;
    return unless "Build.pm".IO.e;
    run "zef", "build", ".";
}

