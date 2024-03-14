const std = @import("std");
const log = std.log;

pub fn main() !void {
    log.info("bruh", .{});
}

test {
    std.testing.refAllDeclsRecursive(@import("ast.zig"));
    std.testing.refAllDeclsRecursive(@import("tokenization.zig"));
    std.testing.refAllDeclsRecursive(@import("types.zig"));
    std.testing.refAllDeclsRecursive(@import("bytecode.zig"));
    std.testing.refAllDeclsRecursive(@import("runtime.zig"));
}
