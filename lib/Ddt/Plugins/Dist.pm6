#
# Plugin to create a distribution tarball
# for CPAN
#
# Author: holli <holli.holzer@gmail.com>
#

use Ddt;
use Ddt::Distribution;
use META6;
use Shell::Command;

module Ddt::Plugins::Dist
{
    #| Create a tarball for the distribution, --force to override errors
    multi MAIN( "dist", Bool :$force = False ) is export {
        my $ddt = Ddt::Distribution.new: TOPDIR;
        make-dist-tarball( $ddt, $force );
    }

    sub make-dist-tarball( $ddt, $force )
    {
        my $dist-name = dist-name( $ddt.main-comp-unit );

        if can-write-dist( $dist-name )
        {
            my @dist-files = find-dist-files( $ddt );

            my $check-result = check-dist( $dist-name, @dist-files );

            if $check-result
            {
                return prepare-and-package-dist( $dist-name, @dist-files )
            }
            else
            {
                if ( $force )
                {
                    $check-result = $check-result
                        .subst( /can\'t/, "shouldn't", :g)
                        .subst( /must/, "should", :g);

                    say "Warning:\n$check-result";

                    return prepare-and-package-dist( $dist-name, @dist-files )
                }
                else
                {
                  say "Error:\n$check-result";
                }
            }
        }

        return;
    }

    sub dist-name( $module )
    {
        my $name    = $module.subst("::", "-", :g);
        my $meta    = get-meta;
        my $version = $meta.version;

        return "{$name}-{$version}";
    }

    sub get-meta
    {
        die "You must have a META6.json"
            unless "META6.json".IO.e;

        return quietly META6.new( file => "META6.json" );
    }

    sub can-write-dist( $dist-name )
    {
        my $tarball = "$dist-name.tar.gz";

        try {
          rm_rf $dist-name if $dist-name.IO.d;
          unlink $tarball  if $tarball.IO.e;

          CATCH {
            warn "something went wrong while unlinking an old dist: $_";
          }
        }

        return !$dist-name.IO.e && !$tarball.IO.e;
    }

    # that's quite dirty, but amazing
    multi sub find-dist-files($ddt, $file where $file.IO.e = "MANIFEST")
    {
        return ($file.IO.lines».chomp).grep: * !~~ "";
    }

    multi sub find-dist-files($ddt)
    {
        my @files = run("git", "ls-files", :out).out.lines(:close);
        return prune-files( @files );
    }

    sub check-dist( $dist-name, @files )
    {
        use Test::META;
        #set up Test::Meta so it doesn't chat
        #and looks in the right directory for files
        $Test::META::TESTING = True;
        my $*DIST-DIR = $*CWD;

        my $meta = get-meta;
        my @problems;

        @problems.push( "you must specify a valid description")
          unless $meta.description !~~ ""|"blah blah blah";

        @problems.push( "you must specify all required entries" )
            unless Test::META::check-mandatory($meta);

        @problems.push( "all files must exist that are specified via <provides>" )
            unless Test::META::check-provides($meta);

        @problems.push( "You must specify at least one <author>" )
            unless $meta.authors.elems > 0;

        @problems.push( "you can't specify empty strings as <author> or <authors>" )
            if $meta.authors.grep(* ~~ "");

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

        for @files {
          @problems.push("all files in the git repository / MANIFEST must exist ($_ doesn't)")
            unless $_.IO.e;
        }

        return "To make dist tarball, {@problems} in META6.json" but False
          if @problems.elems == 1;

        return "To make dist tarball,\n" ~
                @problems.map({ "- $_"}).join("\n") ~
                "\nin META6.json" but False
                    if @problems.elems > 1;

        return True;
    }

    sub add-to-dist( $dist-name, $file )
    {
        say "adding to dist: $file";
        my $target = "$dist-name/$file";
        my $dir = $target.IO.dirname;
        mkpath $dir unless $dir.IO.d;
        $file.IO.copy($target);
    }

    sub prepare-and-package-dist( $dist-name, @dist-files )
    {
        for @dist-files -> $file
        {
            add-to-dist( $dist-name, $file )
        }

        return package-dist( $dist-name );
    }

    # code taken from mi6
    sub package-dist( $dist-name )
    {
         my %env = %*ENV;
         %env<$_> = 1 for <COPY_EXTENDED_ATTRIBUTES_DISABLE COPYFILE_DISABLE>;
         my $proc = run "tar", "czf", "$dist-name.tar.gz", $dist-name, :!out, :err, :%env;
         rm_rf $dist-name if $dist-name.IO.d;
         LEAVE $proc && $proc.err.close;
         if $proc.exitcode != 0 {
             my $exitcode = $proc.exitcode;
             my $err = $proc.err.slurp;
             die $err ?? $err !! "can't create tarball, exitcode = $exitcode";
         }
    }

    sub prune-files( @files ) {
        my @prune = (
          ".travis.yml", ".gitignore", "approvar.yml",
          ".approvar.yml", "circle.yml"
        );

        if "MANIFEST.SKIP".IO.e {
            my @skip = "MANIFEST.SKIP".IO.lines».chomp;
            @prune.append( @skip );
        }

        return @files.grep( * ∉ @prune );
    }
}
