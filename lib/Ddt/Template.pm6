unit module Ddt::Template;

our sub template($module, $license, $relaxed-name) {
    my %template =
gitignore => qq:to/EOF/,
/blib/
/src/*.o
/src/Makefile
/resources/*.so
/resources/*.dylib
.precomp/
# Prove saved state
.prove
# Vim swap files
[._]*.s[a-w][a-z]
[._]s[a-w][a-z]
# Vim session
Session.vim
# temporary
.netrwhist
*~
# Vim auto-generated tag files
tags
EOF

travis => qq:to/EOF/,
os:
  - linux
  - osx
language: perl6
perl6:
  - latest
install:
  - rakudobrew build zef
  - zef --/test --depsonly install .
script:
  - zef test .
sudo: false
EOF

test => qq:to/END_OF_TEST/,
use v6;
#`(
$license.header()
)
use Test;
use $module;

pass "replace me";

done-testing;
END_OF_TEST

test-meta => qq:to/END_OF_META_TEST/,
use v6;
#`(
$license.header()
)
use Test;
use Test::META;

plan 1;

# That's it
meta-ok relaxed-name => $relaxed-name;
END_OF_META_TEST

module => qq:to/EOD_OF_MODULE/,
use v6;
#`(
$license.header()
)

unit class $module;


=begin pod

=head1 NAME

$module - blah blah blah

=head1 SYNOPSIS

  use $module;

=head1 DESCRIPTION

$module is ...

{ '=head1 AUTHOR' if $license.holders.elems == 1 }
{ '=head1 AUTHORS' if $license.holders.elems > 1 }

{ join: $license.holders.map( *.name ), "\n" }

=head1 COPYRIGHT AND LICENSE

$license.note()

=end pod
EOD_OF_MODULE

    %template;
}

