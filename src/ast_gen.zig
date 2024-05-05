const std = @import("std");
const mem = std.mem;
const heap = std.heap;

const ast = @import("ast.zig");
const bc = @import("bytecode.zig");

pub const AstGen = struct {
    // arena: mem.Allocator,
    gpa: mem.Allocator,
    tree: ast.Block,
    output: []const u8,

    /// Caller owns returned memory; allocated by `gpa`.
    pub fn generate(
        gpa: mem.Allocator,
    ) AstGen {
        const arena = heap.ArenaAllocator.init(gpa);
        defer arena.deinit();
    }

    // fn init(
    //     // arena: mem.Allocator,
    //     gpa: mem.Allocator,
    //     tree: ast.Block,
    // ) AstGen {
    //     return .{
    //         // .arena = arena,
    //         .gpa = gpa,
    //         .tree = tree,
    //     };
    // }
};
