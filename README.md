# IOta

## Vector-First RISC-V Kernel (Phase 1)

This repository is the starting point for a vector-first RISC-V kernel in Zig. Phase 1 focuses on bootstrapping a freestanding binary that runs under OpenSBI in QEMU and reaches `kmain()`.

## Phase 1 Task List (execution order)

1. ~~Set up `build.zig` to cross-compile a freestanding `riscv64-unknown-none` kernel and link with a custom linker script.~~
2. ~~Create the minimal assembly entry point (`_start`) that sets up a stack and jumps into Zig.~~
3. ~~Add a tiny OpenSBI-backed UART console helper to prove early boot (`kmain()` hello).~~
4. Define and install the S-mode trap vector (`stvec`) with a Zig trap handler.
5. Implement a `TrapFrame` for x1-x31 and `scause` decoding to separate interrupts from exceptions.

## Build & Run

Build the kernel:

```sh
zig build
```

Run in QEMU (requires OpenSBI, bundled as `-bios default`):

```sh
zig build qemu
```

Expected output (nographic console):

```
[vector-first] booted into Zig kmain()
Phase 1: OpenSBI console ready.
```

## Notes

* QEMU command uses `-cpu rv64,v=true` so the Vector 1.0 extension is available once we enable it in later phases.
* The kernel is linked at `0x8020_0000`, matching OpenSBI’s default jump address.
* Early assembly initializes `gp` and clears `.bss` before calling `kmain()` to keep Zig globals predictable.
