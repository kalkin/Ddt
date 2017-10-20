use Ddt;
use Ddt::Distribution;
use META6;
use Shell::Command;
use CPAN::Uploader::Tiny;

module Ddt::Plugins::Publish
{
    my $cred-file = ".ddt/credentials";

    #| Publish the created tarball to CPAN
    multi MAIN( "publish", Str $user="", Str $password="", Bool :$store = False ) is export {
        my $ddt = Ddt::Distribution.new: TOPDIR;

        store-credentials( $user, $password )
            if $store;

        say my $result = upload-dist-tarball( $ddt, |get-credentials($user, $password) );

        exit $result ?? 0 !! 42;
    }

    sub store-credentials( $user, $password )
    {
        die "Can't write credentials (Unable to create .ddt directory)"
            unless ".ddt".IO.e || mkdir ".ddt";

        ".gitignore".IO.spurt("\n", :append)
            unless $cred-file ∈ ".gitignore".IO.lines;

        $cred-file.IO.spurt("$user;$password");

        say "Note:\n",
            "Your credentials have been stored in '$cred-file'.\n",
            "This file has been added to .gitignore to avoid leaking.\n";
    }

    sub get-credentials( $user, $password )
    {
        my $credentials =
          ".ddt/credentials".IO.e ??
          ".ddt/credentials".IO.lines[0] !!
          Any;

        my ($fu, $fp) =
          $credentials ??
          $credentials.split(";") !!
          ();

        return $user||$fu, $password||$fp;
    }

    sub upload-dist-tarball( $ddt, $user, $password )
    {
        my $dist-name = dist-name( $ddt.main-comp-unit );
        my $tarball   = "{$dist-name}.tar.gz";

        if my $result = is-upload-possible( $tarball, $user, $password )
        {
            try
            {
                my $client = CPAN::Uploader::Tiny.new( :$user, :$password );
                $client.upload($tarball, subdirectory => "Perl6");
                return "Successfully uploaded $dist-name to CPAN.";

                CATCH {
                  return "Error:\nUpload failed ($_)." but False;
                }
            }
        }
        else
        {
          return "Error:\n$result" but False;
        }
    }

    sub is-upload-possible( $tarball, $user, $password )
    {
        my @problems;

        @problems.push( "Can't find the file to upload ( $tarball )" )
            unless $tarball.IO.e;

        @problems.push( "Can't upload without knowing the user" )
            unless $user;

        @problems.push( "Can't upload without knowing the password" )
            unless $password;

        return @problems.join("\n") but False
            if @problems.elems > 0;

        return True;
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
}

=begin pod

=head1 Ddt::Plugins::Publish

Plugin to upload a distribution tarball to CPAN

=head1 Usage

    # You can enter your credentials every time
    root> ddt publish [<user>] [<password>]

    # Or you tell ddt to remember it
    root> ddt --store publish <user> <password>

    # In which case you can omit them from then on
    root> ddt publish

The credentials will be stored per project in
the file .ddt/credentials. Ddt will add that line
to .gitignore so you will not accidentally leak password
information.

=head1 Author

Markus «holli» Holzer <holli.holzer@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright 2015 Markus Holzer

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
