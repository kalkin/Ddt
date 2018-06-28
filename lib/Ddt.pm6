use v6;
use File::Temp;
use Ddt::Unit;

unit module Ddt;

sub to-name(Str:D $name, Str $dist-prefix?) of Str:D is export {
    when  !$dist-prefix.defined {
        if $name.starts-with: '::' {
            die 'unit name starts with "::" but no $dist-prefix provided'
        }
        return $name
    }
    when $name.starts-with: $dist-prefix { return $name }
    when $name.starts-with: '::'         { return $dist-prefix ~ $name }
    default { return $dist-prefix ~ '::' ~ $name }
}

sub name-to-file(Str:D $name) of Str:D is export {
    join("/",  gather for $name.split('::') -> $c {
        take $c
    }) ~ ".pm6"
}

sub author is export { qx{git config  user.name}.chomp }
sub email is export { qx{git config user.email}.chomp }
sub TOPDIR of IO::Path:D is export {
    my Proc:D $proc = Proc.new(:out, :err);
    $proc.shell: 'git rev-parse --show-toplevel';
    my $dir = $proc.out.slurp-rest;
    unless $dir {
        return fail "Not in a repository"
    }
    return $dir.chomp.IO
}

class Result is export(:TEST) {
    has $.out;
    has $.err;
    has $.exit;
    method success() { $.exit == 0 }
}

sub ddt(*@arg) is export(:TEST) {
    my $base = $*SPEC.catdir($?FILE.IO.dirname, "..");
    my ($o, $out) = tempfile;
    my ($e, $err) = tempfile;
    my $s = run $*EXECUTABLE, "-I$base/lib", "$base/bin/ddt", |@arg, :out($out), :err($err);
    .close for $out, $err;
    my $r = Result.new(:out($o.IO.slurp), :err($e.IO.slurp), :exit($s.exitcode));
    unlink($_) for $o, $e;
    $r;
}

=begin pod

=NAME Ddt - Distribution Development Tool

=SYNOPSIS

  $ ddt --license-name=LGPL new Foo::Bar # create Foo-Bar distribution
  $ cd Foo-Bar
  $ ddt build        # build the distribution and re-generate
                     # README.md & META6.json
  $ ddt -C test      # Run tests when files change

=DESCRIPTION

B<Ddt> is an authoring and distribution development tool for Perl6. It provides
scaffolding for generating new distributions, packages, modules, grammers,
classes and roles.

=WARNING
This project is a technology preview. It may change at any point. The only API
which can be considered stable up to the C<v1.0> is the command line interface.

=USAGE

  ddt [--license-name=«NAME»] new <module> -- Create new module
  ddt build                                -- Build the distribution and
                                              update README.md
  ddt [-C|--continues] test [<tests> …]    -- Run distribution tests
  ddt release                              -- Make release
  ddt hack <identity> [<dir>]              -- Checkout a Distribution and
                                              start hacking on it
  ddt generate class <name>                -- Generate a class
  ddt generate role <name>                 -- Generate a role
  ddt generate package <name>              -- Generate a package
  ddt generate grammar <name>              -- Generate a grammar
  ddt generate module <name>               -- Generate a module
  ddt generate test <name> [<description>] -- Generate stub test file
  ddt [-v] deps distri                     -- Show all the modules used
  ddt [-u|--update] deps                   -- Update META6.json dependencies
  ddt watch [<cmd>…]                       -- Watch lib/, bin/ & t/ for
                                              changes respecting .gitignore
                                              and execute given cmd

=head1 INSTALLATION

  # with zef
  > zef install Ddt


=head1 Differences to Mi6

=item Support for different licenses via C<License::Software>

=item META6 is generated using C<META6>

=item Meta test

=item Use prove for tests

=item Run tests on changes

=item Extended .gitignore

=item Support for different licenses

=item Support for Distributions with a hyphen in the name

=head1 FAQ

=item How can I manage depends, build-depends, test-depends?

Use C<ddt -u deps>


=item Where is the spec of META6.json?

Maybe https://github.com/perl6/ecosystem/blob/master/spec.pod or http://design.perl6.org/S22.html

=item How do I remove the travis badge?

Remove .travis.yml


=head1 SEE ALSO

=item L<https://github.com/skaji/mi6>

=item L<https://github.com/tokuhirom/Minilla>

=item L<https://github.com/rjbs/Dist-Zilla>

=head1 AUTHOR

=item Bahtiar `kalkin-` Gadimov <bahtiar@gadimov.de>

=item Shoichi Kaji <skaji@cpan.org>

=head1 COPYRIGHT AND LICENSE

=item Copyright © 2015 Shoichi Kaji
=item Copyright © 2016-2017 Bahtiar `kalkin-` Gadimov

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
