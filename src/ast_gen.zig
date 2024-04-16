const std = @import("std");
const mem = std.mem;

const ast = @import("ast.zig");

pub const AstGen = struct {
    arena: mem.Allocator,
    gpa: mem.Allocator,
};
