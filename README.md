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

### Milestone 2.1: Discovery & Verification

1. Task 2.1.1: The "Negative" Test
   * Action: In `kmain`, attempt to execute a vector instruction (or read `vlenb`) before touching `sstatus.VS`.
   * Requirement: Confirm this triggers a trap with `scause = 2` (Illegal Instruction).
   * Caveat: If it doesn't trap, check QEMU flags (`-cpu rv64,v=true`) or explicitly disable VS first.
2. Task 2.1.2: The Enabler
   * Action: Implement a helper `riscv.setStatusVS(state: VSState)`.
   * Requirement: Set `sstatus` bits [10:9] to `01` (Initial).
   * Verification: Read `vlenb` successfully after enabling and print bytes to UART.
3. ~~Task 2.1.3: Dynamic Sizing Calculation~~
   * ~~Action: Create global `kernel_vlenb` (`u64`).~~
   * ~~Logic: Compute context size as `(32 * vlenb) + 8 (vstart) + 8 (vcsr) + 8 (vl) + 8 (vtype)`.~~
   * ~~Requirement: Round total size up to 16-byte alignment.~~

### Milestone 2.2: Memory Infrastructure

1. ~~Task 2.2.1: The Vector Context Struct~~
   * ~~Action: Define a Zig `VectorContext` that holds scalar control registers and a pointer to the register blob.~~
   * ~~Constraint: The register blob is runtime-sized; do not embed `[32][vlenb]u8` directly in the struct.~~
2. ~~Task 2.2.2: The Slab Allocator~~
   * ~~Action: Implement a simple slab allocator for vector contexts.~~
   * ~~Logic: After discovering `vlenb`, carve a region into fixed-size blocks of `(32 * vlenb)` plus control space.~~
   * ~~Requirement: `alloc()` must return a pointer aligned to `vlenb` (or at least 16 bytes).~~

### Milestone 2.3: The "Vector Guard" (Kernel Safety)

1. ~~Task 2.3.1: Preemption Primitives~~
   * ~~Action: Implement `intr_disable()` and `intr_restore(flags)`.~~
   * ~~Requirement: Use atomic CSR operations (e.g., `csrci sstatus, 2`).~~
2. ~~Task 2.3.2: The Guard Object~~
   * ~~Action: Create the `VectorGuard` struct in Zig.~~
   * ~~Logic (enter):~~
     * ~~Disable interrupts.~~
     * ~~If the current vector owner is a user process and `sstatus.VS == Dirty`, save its registers to its `VectorContext`.~~
     * ~~Set `current_vector_owner = .Kernel`.~~
     * ~~Set `sstatus.VS = Initial` for kernel use.~~
   * ~~Logic (leave):~~
     * ~~Set `current_vector_owner = .None`.~~
     * ~~Set `sstatus.VS = Off` (or `Initial` if desired).~~
     * ~~Restore interrupts.~~

### Milestone 2.4: Lazy Context Switching (User Space)

1. Task 2.4.1: Trap Handler Update
   * Action: Modify `trap_handler` to catch `scause = 2` (Illegal Instruction).
   * Logic:
     * Decode the instruction (use `stval` or read from `sepc`).
     * If vector opcode and no context yet: allocate `VectorContext`, set `sstatus.VS = Initial`, return to retry.
     * If vector opcode and context exists: set `sstatus.VS = Initial`, load registers, return.
2. Task 2.4.2: The Context Switcher
   * Action: In `scheduler.switch()`:
     * If previous process has `sstatus.VS == Dirty`, save vector regs to its context.
     * Always set `sstatus.VS = Off` for the next process.
   * Result: Vector state is restored lazily on the next illegal-instruction trap.

**Requirements**
* `vlenb` must be read dynamically (bytes, not bits).
* `sstatus.VS` transitions must avoid manually setting Dirty.
* Vector contexts must be aligned (at least 16 bytes; prefer `vlenb`).

## Phase 3: Memory Management (Goal: virtual memory and kernel mapping)

### Milestone 3.1: Page Table Architecture

1. Task 3.1.1: Physical Memory Manager (PMM)
   * Action: Implement a bitmap or free-list allocator for 4KiB pages.
   * Requirement: Parse the device tree or OpenSBI memory map to avoid MMIO ranges.
2. Task 3.1.2: Page Table Definitions
   * Action: Define `PageTableEntry` as a Zig `packed struct(u64)`.
   * Fields: PPN, Valid, Read, Write, Execute, User, Global, Accessed, Dirty.
   * Constraint: Use the RISC-V PTE bit positions (flags in bits 0-9).

### Milestone 3.2: The Mapping Strategy

1. Task 3.2.1: Identity Mapping (Bootstrap)
   * Action: Create a root page table and map the kernel physical range to the same virtual addresses.
   * Why: Without identity mapping, enabling paging will fault on the next fetch.
2. Task 3.2.2: Higher-Half Mapping (Destination)
   * Action: Map the kernel into a high virtual range (e.g., `0xFFFF_FFFF_8000_0000` for Sv39).
   * Requirement: Adjust the linker script to link at the high address but load at the physical address.

### Milestone 3.3: Enabling Paging

1. Task 3.3.1: The Jump
   * Action: Write the sequence to enable paging:
     * Write root table address to `satp`.
     * Execute `sfence.vma`.
     * Jump to the virtual address of the next instruction.
2. Task 3.3.2: Trap Handler Adjustment
   * Action: Update `stvec` to the virtual address of the trap handler.
   * Verification: Trigger a trap to validate vector jumps.

### Milestone 3.4: Internal Abstraction (Microkernel Prep)

1. Task 3.4.1: The Device Interface
   * Action: Define `const Device = struct { read: fn(), write: fn() };`.
   * Requirement: Refactor the UART driver to implement this interface.
2. Task 3.4.2: Policy Enforcement
   * Action: Replace direct MMIO pointer dereferences with mapped virtual addresses.
   * Requirement: Avoid hard-coded MMIO magic numbers in driver code.

**Requirements**
* Page tables must be initialized before enabling paging.
* Kernel mappings must cover text, rodata, data, and bss.
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
