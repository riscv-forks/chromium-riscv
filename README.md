# Chromium RISC-V CI/CD

## Continuous Integration

This CI is designed to catch bugs in Chromium that breaks RISC-V builds.
We do not run it on every commit like the upstream CQ bots.
Instead, this CI runs periodically in order to save computation resource.

The goal is to discover and fix RISC-V build errors before they gets into a Chromium release
so that downstream Linux distributions won't need to apply extra patches.

Currently it mainly tests whether Debug/Release build passes
and runs part of Chromium's unit tests.

## Continuous Delivery

The latest stable version of Chromium is built and released to GitHub Releases weekly.

## Plans

- Run more tests
