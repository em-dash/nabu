const std = @import("std");

const types = @import("types.zig");
const Object = types.Object;

/// Stack frame.
const Frame = struct {
    /// Program counter.
    pc: u32,
    /// Index of the start of the previous stack frame (within this call stack).
    prev: u32,
    /// Register stack.
    regs: []types.Object,
};

const Thread = struct {
    call_stack: []u8,

    fn init(entry_point: u32, options: Options) !Thread {
        _ = entry_point; // autofix
        var result: Thread = undefined;
        result.call_stack = std.heap.page_allocator.alloc(u8, options.size);
    }

    const Options = struct {
        /// Stack size in bytes.  Default 1MB.
        .size = 1024 * 1024,
    };
};
