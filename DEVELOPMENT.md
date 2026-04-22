# XLSX Development

## Dependencies

1. Make sure you have `ops` installed, in one of the following ways:
 - as a gem via `gem install ops_team` or
 - as a tool via `brew tap nickthecook/crops && brew install ops`
2. If you not using macOS, or a Linux that uses `apt`, please [install Crystal](https://crystal-lang.org/install/)

## Getting started

|Command                         |Description                                                                       |
|--------------------------------|----------------------------------------------------------------------------------|
|`ops up`                        |Gets everything setup including `crystal` via `apt` or `brew` if applicable.      |
|`ops build-debug` or `ops build`|Make a debug build of `benchmark` sample, in `bin/debug` folder.                  |
|`ops build-release` or `ops br` |Make a release / production build of `benchmark` sample,  in `bin/release` folder.|
|`ops lint`                      |Run `ameba` on the source code                                                    |
|`ops clean`                     |Remove debug and release build files                                              |
|`ops wipe`                      |In addition to cleaning, remove all compiler caches                               |

### Build and run for development

Use `ops run samples/<SOURCEFILE>` to compile and run the specific source. Without parameters you will get some usage info.

### Verify passing tests

Use `ops test` to run the tests. Make sure they all pass.

### Build to run later

The `samples/csv2xlsx.cr` app is built as a pre-defined target.

1. Run `ops build-release` to make a release build in the `bin/release/` folder
2. Run `ops build-debug` to make a debug build in the `bin/debug/` folder

## Contributions

See [README](./README.md)
