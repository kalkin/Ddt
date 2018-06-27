use Ddt;
use Ddt::Distribution;
unit module Ddt::DDT::Plugins::Check;

#| Check META6.json file for common errors
multi MAIN("check") is export {
    my $ddt = Ddt::Distribution.new: TOPDIR;

    use Test::META;
    #set up Test::Meta so it doesn't chat
    #and looks in the right directory for files
    $Test::META::TESTING = True;

    my $meta = $ddt.META6;
    my @problems;

    @problems.push( "you must specify a valid description")
    unless $meta.description !~~ ""|"blah blah blah";

    @problems.push( "you must specify all required entries" )
    unless Test::META::check-mandatory($meta);

    @problems.push( "all files must exist that are specified via <provides>" )
    unless Test::META::check-provides($meta);

    @problems.push( "You must specify at least one <author>" )
    unless $meta.authors;

    @problems.push( "you can't specify just empty strings as <author> or <authors>" )
    if $meta.authors.grep("", :v);

    @problems.push( "you must specify an <author> (not only <authors>)" )
    unless Test::META::check-authors($meta);

    @problems.push( "you must specify a correct <license>" )
    unless Test::META::check-license($meta);

    @problems.push( "you must specify a correct <name> (with double colons instead of hypens)" )
    unless Test::META::check-name($meta, :relaxed-name(False)) && $meta.name.defined && $meta.name !~~ "";

    @problems.push( "you must specify a valid <version> (not '*' or empty)" )
    unless Test::META::check-version($meta) && $meta.version.defined && $meta.version !~~ "";

    @problems.push( "you must specify a <source-url>")
    unless $meta.source-url.defined && $meta.source-url !~~ "";

    @problems.push( "you must specify valid urls as sources" )
    unless Test::META::check-sources($meta);

    for @problems {
        say 'ERROR: ' ~ $_;
        LAST { exit 1 }
    }
}
