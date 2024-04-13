const std = @import("std");
const log = std.log;

pub fn main() !void {
    log.info("bruh", .{});
}

test {
    // std.testing.refAllDecls(@import("ast.zig"));
    // std.testing.refAllDecls(@import("tokenization.zig"));
    // std.testing.refAllDecls(@import("types.zig"));
    // std.testing.refAllDecls(@import("bytecode.zig"));
    // std.testing.refAllDecls(@import("runtime.zig"));
    _ = @import("ast.zig");
    _ = @import("tokenization.zig");
    _ = @import("types.zig");
    _ = @import("bytecode.zig");
    _ = @import("runtime.zig");
}
