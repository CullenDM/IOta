const riscv = @import("riscv.zig");
const vector_context = @import("vector_context.zig");

pub const VectorOwner = enum {
    none,
    kernel,
    user,
};

var current_owner: VectorOwner = .none;
var current_user_context: ?*vector_context.VectorContext = null;

fn saveUserContext(ctx: *vector_context.VectorContext) void {
    _ = ctx;
    // TODO: Save vector registers to ctx.regs and control fields.
}

pub fn restoreUserContext(ctx: *vector_context.VectorContext) void {
    _ = ctx;
    // TODO: Restore vector registers from ctx.regs and control fields.
}

pub fn setCurrentUserContext(ctx: ?*vector_context.VectorContext) void {
    current_user_context = ctx;
    current_owner = if (ctx == null) .none else .user;
}

pub fn getOwner() VectorOwner {
    return current_owner;
}

pub const VectorGuard = struct {
    saved_flags: usize,

    pub fn enter() VectorGuard {
        const flags = riscv.intrDisable();
        if (current_owner == .user and riscv.getStatusVS() == .dirty) {
            if (current_user_context) |ctx| {
                saveUserContext(ctx);
            }
        }
        current_owner = .kernel;
        riscv.setStatusVS(.initial);
        return .{ .saved_flags = flags };
    }

    pub fn leave(self: *VectorGuard) void {
        current_owner = .none;
        riscv.setStatusVS(.off);
        riscv.intrRestore(self.saved_flags);
    }
};
