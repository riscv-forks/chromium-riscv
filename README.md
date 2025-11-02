# Chromium RISC-V CI

This CI is designed to catch bugs in Chromium that breaks RISC-V builds.
We do not run it on every commit like the upstream CQ bots.
Instead, this CI runs periodically in order to save computation resource.

The goal is to discover and fix RISC-V build errors before they gets into a Chromium release
so that downstream Linux distributions won't need to apply extra patches.

Currently it mainly tests whether Debug/Release build passes
and runs part of Chromium's unit tests.

## Plans

- Run more tests
- Release binaries for Chromium and ChromeDriver.
