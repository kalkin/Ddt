
use Ddt;
use Ddt::Distribution;
use META6;
use Shell::Command;

module Ddt::Plugins::Dist
{
    #| Create a tarball for the distribution, use the force to override errors
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
    # get the dist files from the MANIFEST
    # (if there is one)
    multi sub find-dist-files($ddt, $file where $file.IO.e = "MANIFEST")
    {
        return ($file.IO.lines».chomp).grep: * !~~ "";
    }

    # get the dist files from disk
    multi sub find-dist-files($ddt)
    {
        my @files = run("git", "ls-files", :out).out.lines(:close);
        return prune-files( @files );
    }

    # check the distribution for errors
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

        @problems.push( "you can't specify just empty strings as <author> or <authors>" )
            if $meta.authors.all(* ~~ "");

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
        for @dist-files -> $file {
            add-to-dist( $dist-name, $file )
        }

        unless my $result = package-dist( $dist-name ) {
            say $result;
            exit(-1);
        }
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
            return
                "Can't create tarball ({$err||'unknown error'}), exitcode = $exitcode"
                but False;
        }

        return True;
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

=begin pod

=head1 Ddt::Plugins::Dist

Plugin to create a distribution tarball for CPAN

=head1 Usage

    root> ddt dist

This will create a tarball for your project.

If a MANIFEST file is present in the root of your project,
it will be read and only the files listed in there will end
up in the tarball.

Otherwise the file list resulting from a C<git ls-files> command
will be used.

This list may be filtered by using a MANIFEST.SKIP file. If such a
file is present, it will be read and files listed therein will not
be part of the tarball.

=head1 Author

Markus «holli» Holzer <holli.holzer@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright 2015 Markus Holzer

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
