# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [0.7.0] - 2022-10-30

### Added

- Modules can have unmanaged licenses that aren't present in License::Software

## [0.6.1] - Unreleased

### Changed

- Unicode in JSON not escaped anymore - using JSON::Fast to produce META6

## [0.6.0] - Unreleased

### Added

- 'new here' subcommand to generate a module in the current directory

## [0.5.11] - Unreleased

### Changed

- Source files to conform the 'Raku' name
- Extension of generated files 'pm6' -> 'rakumod'

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
