pub const VsState = enum(u2) {
    off = 0,
    initial = 1,
    clean = 2,
    dirty = 3,
};

pub fn setStatusVS(state: VsState) void {
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

pub fn getStatusVS() VsState {
    var current: usize = 0;
    asm volatile ("csrr %0, sstatus"
        : "=r" (current),
        :
        : "memory"
    );
    const field: u2 = @intCast((current >> 9) & 0x3);
    return @enumFromInt(field);
}

pub fn readVlenb() usize {
    var value: usize = 0;
    asm volatile ("csrr %0, vlenb"
        : "=r" (value),
        :
        : "memory"
    );
    return value;
}

pub fn intrDisable() usize {
    var previous: usize = 0;
    asm volatile ("csrrci %0, sstatus, 2"
        : "=r" (previous),
        :
        : "memory"
    );
    return previous;
}

pub fn intrRestore(flags: usize) void {
    asm volatile ("csrw sstatus, %0"
        :
        : "r" (flags),
        : "memory"
    );
}
