const std = @import("std");

extern var __bss_start: u8;
extern var __bss_end: u8;
extern fn trap_entry() void;

var expected_illegal_probe: bool = false;
var kernel_vlenb: usize = 0;
var kernel_vector_context_bytes: usize = 0;

const debug_vector_probe = false;

const VectorContext = extern struct {
    vstart: usize,
    vcsr: usize,
    vl: usize,
    vtype: usize,
    regs: [*]u8,
};

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

fn read_vlenb() usize {
    var value: usize = 0;
    asm volatile ("csrr %0, vlenb"
        : "=r" (value),
        :
        : "memory"
    );
    return value;
}

const VsState = enum(u2) {
    off = 0,
    initial = 1,
    clean = 2,
    dirty = 3,
};

fn set_sstatus_vs(state: VsState) void {
    const mask: usize = @as(usize, 0x3) << 9;
    var current: usize = 0;
    asm volatile ("csrr %0, sstatus"
        : "=r" (current),
        :
        : "memory"
    );
    current = (current & ~mask) | (@as(usize, @intFromEnum(state)) << 9);
    asm volatile ("csrw sstatus, %0"
        :
        : "r" (current),
        : "memory"
    );
}

fn align_up(value: usize, alignment: usize) usize {
    const mask = alignment - 1;
    return (value + mask) & ~mask;
}

fn calc_vector_context_bytes(vlenb: usize) usize {
    const control_bytes = 4 * @sizeOf(usize);
    const reg_bytes = 32 * vlenb;
    return align_up(control_bytes + reg_bytes, 16);
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
    const scause_ecall_s_mode: usize = 9;
    const scause_illegal_instruction: usize = 2;
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
    sbi_print(" sepc=");
    print_hex(frame.sepc);
    sbi_print(" stval=");
    print_hex(frame.stval);
    sbi_print("\n");

    if (!is_interrupt) {
        switch (code) {
            scause_ecall_s_mode => {
                sbi_print("[trap] handled s-mode ecall, advancing sepc\n");
                frame.sepc += 4;
            },
            scause_illegal_instruction => {
                sbi_print("[trap] illegal instruction\n");
                if (expected_illegal_probe) {
                    expected_illegal_probe = false;
                    sbi_print("[trap] expected probe, advancing sepc\n");
                    frame.sepc += 4;
                } else {
                    sbi_print("[trap] unexpected illegal instruction, halting\n");
                    while (true) {
                        asm volatile ("wfi");
                    }
                }
            },
            else => {
                sbi_print("[trap] unhandled exception, halting\n");
                while (true) {
                    asm volatile ("wfi");
                }
            },
        }
    }
}

pub export fn kmain() noreturn {
    init_trap_vector();
    sbi_print("[vector-first] booted into Zig kmain()\n");
    sbi_print("Phase 1: OpenSBI console ready.\n");
    sbi_print("Triggering S-mode ecall to validate trap handling.\n");
    asm volatile ("ecall");
    sbi_print("Back in kmain! Trap handled.\n");
    if (debug_vector_probe) {
        sbi_print("Phase 2: probing vlenb with VS off (expect illegal instruction).\n");
        expected_illegal_probe = true;
        _ = read_vlenb();
        if (expected_illegal_probe) {
            sbi_print("[vector-first] warning: vlenb read did not trap.\n");
            expected_illegal_probe = false;
        }
    }
    sbi_print("Enabling vector unit (sstatus.VS=Initial).\n");
    set_sstatus_vs(.initial);
    kernel_vlenb = read_vlenb();
    kernel_vector_context_bytes = calc_vector_context_bytes(kernel_vlenb);
    sbi_print("Detected vlenb=");
    print_hex(kernel_vlenb);
    sbi_print("\n");
    sbi_print("Vector context bytes (aligned) =");
    print_hex(kernel_vector_context_bytes);
    sbi_print("\n");

    while (true) {
        asm volatile ("wfi");
    }
}
