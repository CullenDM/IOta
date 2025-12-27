pub const SystemConfig = struct {
    /// Vector Length in Bytes (read from 'vlenb' CSR).
    vlenb: u64 = 0,

    /// Total bytes required for a single context save (regs + control + padding).
    vector_context_size: usize = 0,

    /// Number of active harts (cores).
    hart_count: usize = 1,
};

var config = SystemConfig{};

fn align_up(value: usize, alignment: usize) usize {
    const mask = alignment - 1;
    return (value + mask) & ~mask;
}

fn read_vlenb() u64 {
    var value: usize = 0;
    asm volatile ("csrr %0, vlenb"
        : "=r" (value),
        :
        : "memory"
    );
    return @intCast(value);
}

pub fn init() void {
    const vlenb = read_vlenb();
    const control_bytes = 4 * @sizeOf(usize);
    const reg_bytes = 32 * @as(usize, @intCast(vlenb));
    const raw_size = control_bytes + reg_bytes;
    const aligned_size = align_up(raw_size, 16);

    config.vlenb = vlenb;
    config.vector_context_size = aligned_size;
}

pub fn getVlenb() u64 {
    return config.vlenb;
}

pub fn getVectorContextSize() usize {
    return config.vector_context_size;
}
