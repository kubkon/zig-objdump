# zig-objdump

`objdump` utility but in Zig.

## Why?

We need a set of good disassemblers and encoders for Zig's self-hosted native backends, and
what better way than to test them than by disassembling actual relocatables and binaries.

## Building

This project using the experimental Zig's package manager and so you need the latest Zig
nightly to build it.

```
$ zig build
```
