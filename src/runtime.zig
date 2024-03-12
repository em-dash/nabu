const std = @import("std");

const Stack = struct {
    bytes: []u8,

    fn init(size: usize) !Stack {
        var result: Stack = undefined;
        result.bytes = std.heap.page_allocator.alloc(u8, size);
    }
};
