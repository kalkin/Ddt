# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [0.5.11] - 2022-04-21

### Changed

- Generated files use *.raku suffix instead of *.pm6
- Remove deprecated usage of $*PERL.version

### Fixed

- fix: Running ddt test

## [0.5.10] - 2021-06-20

### Fixed

- Handling no dependencies

## [v0.5.9]

### Fixed

- Building in rakudo ecosystem

## [v0.5.8]

### Added

- `xt/` directory to list of watched directories
- license header to generated test files

### Fixed

- deps plugin ignore `v6.c`, `v6.d` & ect… deps

## v0.5.7 - 2019-12-07

### Added

- lib/.precomp to gitignore template

### Fixed

- failing to generate META6.json when not GitHub ssh url

### Changed

- Do not initialize git repo if already in one
