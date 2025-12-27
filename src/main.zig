const std = @import("std");

extern var __bss_start: u8;
extern var __bss_end: u8;
extern fn trap_entry() void;

const TrapFrame = extern struct {
    x1: usize,
    x2: usize,
    x3: usize,
    x4: usize,
    x5: usize,
    x6: usize,
    x7: usize,
    x8: usize,
    x9: usize,
    x10: usize,
    x11: usize,
    x12: usize,
    x13: usize,
    x14: usize,
    x15: usize,
    x16: usize,
    x17: usize,
    x18: usize,
    x19: usize,
    x20: usize,
    x21: usize,
    x22: usize,
    x23: usize,
    x24: usize,
    x25: usize,
    x26: usize,
    x27: usize,
    x28: usize,
    x29: usize,
    x30: usize,
    x31: usize,
    sepc: usize,
    sstatus: usize,
    scause: usize,
    stval: usize,
};

export fn clear_bss() void {
    var current = @intFromPtr(&__bss_start);
    const end = @intFromPtr(&__bss_end);
    while (current < end) : (current += 1) {
        const ptr: *u8 = @ptrFromInt(current);
        ptr.* = 0;
    }
}

fn sbi_putchar(ch: u8) void {
    asm volatile ("ecall"
        :
        : [a0] "{a0}" (ch),
          [a7] "{a7}" (@as(usize, 1)),
        : "memory"
    );
}

fn sbi_print(message: []const u8) void {
    for (message) |ch| {
        if (ch == '\n') {
            sbi_putchar('\r');
        }
        sbi_putchar(ch);
    }
}

fn print_hex(value: usize) void {
    const hex = "0123456789abcdef";
    var shift: usize = @bitSizeOf(usize);
    while (shift > 0) {
        shift -= 4;
        const nibble = (value >> shift) & 0xf;
        sbi_putchar(hex[@intCast(nibble)]);
    }
}

fn init_trap_vector() void {
    const addr = @intFromPtr(&trap_entry);
    asm volatile ("csrw stvec, %[addr]"
        :
        : [addr] "r" (addr),
        : "memory"
    );
}

pub export fn trap_handler(frame: *TrapFrame) void {
    const is_interrupt = (frame.scause >> (@bitSizeOf(usize) - 1)) == 1;
    const code = frame.scause & ((@as(usize, 1) << (@bitSizeOf(usize) - 1)) - 1);

    if (is_interrupt) {
        sbi_print("[trap] interrupt scause=");
    } else {
        sbi_print("[trap] exception scause=");
    }
    print_hex(frame.scause);
    sbi_print(" code=");
    print_hex(code);
    sbi_print("\n");
}

pub export fn kmain() noreturn {
    init_trap_vector();
    sbi_print("[vector-first] booted into Zig kmain()\n");
    sbi_print("Phase 1: OpenSBI console ready.\n");

    while (true) {
        asm volatile ("wfi");
    }
}
