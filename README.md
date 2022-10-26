NAME
====

Ddt - Distribution Development Tool

SYNOPSIS
========



    $ ddt --license-name=LGPL new Foo::Bar # create Foo-Bar distribution
    $ cd Foo-Bar
    $ ddt build        # build the distribution and re-generate
                       # README.md & META6.json
    $ ddt -C test      # Run tests when files change

DESCRIPTION
===========



**Ddt** is an authoring and distribution development tool for Raku. It provides scaffolding for generating new distributions, packages, modules, grammers, classes and roles.

WARNING
=======

This project is a technology preview. It may change at any point. The only API which can be considered stable up to the `v1.0` is the command line interface.

USAGE
=====



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

INSTALLATION
============

    # with zef
    > zef install Ddt

Differences to Mi6
==================

  * Support for different licenses via `License::Software`

  * META6 is generated using `META6`

  * Meta test

  * Use prove for tests

  * Run tests on changes

  * Extended .gitignore

  * Support for different licenses

  * Support for Distributions with a hyphen in the name

FAQ
===

  * How can I manage depends, build-depends, test-depends?

Use `ddt -u deps`

  * Where is the spec of META6.json?

The documentation site describes the current practices pretty well at [https://docs.raku.org/language/modules#Distributing_modules](https://docs.raku.org/language/modules#Distributing_modules). The original design document of META6.json is available at [http://design.perl6.org/S22.html](http://design.perl6.org/S22.html).

  * How do I remove the travis badge?

Remove .travis.yml

SEE ALSO
========

  * [https://github.com/skaji/mi6](https://github.com/skaji/mi6)

  * [https://github.com/tokuhirom/Minilla](https://github.com/tokuhirom/Minilla)

  * [https://github.com/rjbs/Dist-Zilla](https://github.com/rjbs/Dist-Zilla)

AUTHOR
======

  * Bahtiar `kalkin-` Gadimov <bahtiar@gadimov.de>

  * Shoichi Kaji <skaji@cpan.org>

COPYRIGHT AND LICENSE
=====================

  * Copyright © 2015 Shoichi Kaji

  * Copyright © 2016-2017 Bahtiar `kalkin-` Gadimov

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

