# IOta

## Vector-First RISC-V Kernel

This repository is the starting point for a vector-first RISC-V kernel in Zig. The project is organized into phased milestones, each with explicit tasks and requirements.

## Phase 1: Bare Metal Foundation (Goal: reach `kmain()` in S-Mode)

1. ~~Set up `build.zig` to cross-compile a freestanding `riscv64-unknown-none` kernel and link with a custom linker script.~~
2. ~~Create the minimal assembly entry point (`_start`) that sets up a stack and jumps into Zig.~~
3. ~~Add a tiny OpenSBI-backed UART console helper to prove early boot (`kmain()` hello).~~
4. ~~Define and install the S-mode trap vector (`stvec`) with a Zig trap handler.~~
5. ~~Implement a `TrapFrame` for x1-x31 and `scause` decoding to separate interrupts from exceptions.~~
6. ~~Trigger a deliberate S-mode `ecall` and advance `sepc` to validate trap entry/return.~~

**Requirements**
* Boot via OpenSBI into S-Mode.
* Console output via OpenSBI `ecall` UART helper.
* Working trap entry/return path with a validated synchronous exception.

## Phase 2: Vector Subsystem & Safety Architecture (Goal: vector discovery and lazy-loading)

1. ~~Probe `vlenb` with `sstatus.VS` off and confirm illegal-instruction trap (debug-only).~~
2. ~~Add `sstatus.VS` helper to set `Initial` state.~~
3. ~~Read `vlenb` after enabling vectors and store it globally.~~
4. Define vector context sizing: `32 * vlenb` plus control CSRs (`vstart`, `vcsr`, `vl`, `vtype`) and alignment padding.
5. Implement a slab allocator for vector contexts using runtime `vlenb`.
6. Add a kernel-side `VectorGuard` that:
   * Disables interrupts/preemption on enter.
   * Saves user vector state if dirty.
   * Marks vector ownership as kernel.
7. Implement lazy context switching:
   * Disable vectors for tasks that do not use them.
   * On illegal instruction, allocate context, enable vectors, and retry.

**Requirements**
* `vlenb` must be read dynamically (bytes, not bits).
* `sstatus.VS` transitions must avoid manually setting Dirty.
* Vector contexts must be aligned (at least 16 bytes; prefer `vlenb`).

## Phase 3: Memory Management (Goal: virtual memory and kernel mapping)

1. Set up Sv39 or Sv48 paging structures.
2. Identity-map kernel text/data at boot.
3. Define strict driver interfaces (e.g., `BlockDevice`, `CharDevice`) to enforce microkernel-friendly boundaries.

**Requirements**
* Page tables must be initialized before enabling paging.
* Kernel mapping must cover text, rodata, data, and bss.
* Driver access should go through interfaces only.

## Phase 4: User Space & IPC (Goal: isolate drivers and define syscalls)

1. Move UART driver to a separate ELF.
2. Implement synchronous IPC/message passing.
3. Expose vectors to user space via instruction traps (not syscalls).

**Requirements**
* Drivers run outside the kernel image.
* IPC is the only communication path between tasks.
* Vector usage is mediated by trap/exception handling.

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
