pub const Control = extern struct {
    vstart: usize,
    vcsr: usize,
    vl: usize,
    vtype: usize,
};

pub const VectorContext = struct {
    control: *Control,
    regs: [*]u8,

    pub fn init(block: [*]u8) VectorContext {
        const control_ptr: *Control = @ptrFromInt(@intFromPtr(block));
        const regs_ptr: [*]u8 = block + @sizeOf(Control);
        return .{
            .control = control_ptr,
            .regs = regs_ptr,
        };
    }
};
