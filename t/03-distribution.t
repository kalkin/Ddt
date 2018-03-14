use v6;
use Test;
use Ddt::Distribution;

plan 2;

my $dist =  Ddt::Distribution.new($*CWD);
ok $dist, "Found the META6.json file";
ok $dist.license, "Has a license field";
