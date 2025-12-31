const kernel_config = @import("kernel_config.zig");

const slab_bytes = 64 * 1024;

var slab_storage: [slab_bytes]u8 align(16) = undefined;

const Node = extern struct {
    next: ?*Node,
};

fn align_up(value: usize, alignment: usize) usize {
    const mask = alignment - 1;
    return (value + mask) & ~mask;
}

pub const VectorSlab = struct {
    free_list: ?*Node = null,
    block_size: usize = 0,
    alignment: usize = 16,
    total_blocks: usize = 0,

    pub fn init(self: *VectorSlab) void {
        self.block_size = kernel_config.getVectorContextSize();
        if (self.block_size == 0) {
            return;
        }
        const vlenb = @as(usize, @intCast(kernel_config.getVlenb()));
        self.alignment = if (vlenb > 16) vlenb else 16;

        var start = @intFromPtr(&slab_storage);
        const end = start + slab_storage.len;
        start = align_up(start, self.alignment);

        var cursor = start;
        while (cursor + self.block_size <= end) : (cursor += self.block_size) {
            const node: *Node = @ptrFromInt(cursor);
            node.next = self.free_list;
            self.free_list = node;
            self.total_blocks += 1;
        }
    }

    pub fn alloc(self: *VectorSlab) ?[*]u8 {
        const node = self.free_list orelse return null;
        self.free_list = node.next;
        return @ptrCast(node);
    }

    pub fn free(self: *VectorSlab, ptr: [*]u8) void {
        const node: *Node = @ptrCast(ptr);
        node.next = self.free_list;
        self.free_list = node;
    }

    pub fn getBlockSize(self: *const VectorSlab) usize {
        return self.block_size;
    }

    pub fn getTotalBlocks(self: *const VectorSlab) usize {
        return self.total_blocks;
    }
};

pub var slab = VectorSlab{};

pub fn init() void {
    slab.init();
}

pub fn alloc() ?[*]u8 {
    return slab.alloc();
}

pub fn free(ptr: [*]u8) void {
    slab.free(ptr);
}

pub fn blockSize() usize {
    return slab.getBlockSize();
}

pub fn totalBlocks() usize {
    return slab.getTotalBlocks();
}
