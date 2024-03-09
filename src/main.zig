const std = @import("std");
const log = std.log;

pub fn main() !void {
    log.info("bruh", .{});
}

test {
    _ = @import("ast.zig");
    _ = @import("tokenization.zig");
    _ = @import("types.zig");
    _ = @import("render.zig");
}
