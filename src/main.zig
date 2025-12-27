const std = @import("std");

extern var __bss_start: u8;
extern var __bss_end: u8;

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

pub export fn kmain() noreturn {
    sbi_print("[vector-first] booted into Zig kmain()\n");
    sbi_print("Phase 1: OpenSBI console ready.\n");

    while (true) {
        asm volatile ("wfi");
    }
}
