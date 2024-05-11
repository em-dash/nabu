const std = @import("std");
const mem = std.mem;
const hp = std.heap;
const ts = std.testing;
const mta = std.meta;

const ast = @import("ast.zig");
const bc = @import("bytecode.zig");
const rt = @import("runtime.zig");
const tok = @import("tokenization.zig");

pub const ModuleGen = struct {
    gpa: mem.Allocator,
    arena: mem.Allocator,
    tree: ast.Block,
    source: []const u8,
    // TODO name table field
    /// Pointers to const and global objects to go in the object table of a module, including
    /// functions.
    objects: std.ArrayListUnmanaged(*rt.ObjectHeader) = .{},
    code: std.ArrayListUnmanaged(u8) = .{},
    strings: std.ArrayListUnmanaged(u8) = .{},

    pub fn deinit(self: ModuleGen) void {
        self.arena.deinit();
    }

    pub fn generate(
        gpa: mem.Allocator,
        tree: ast.Block,
    ) !ModuleGen {
        var arena = hp.ArenaAllocator.init(gpa);
        var self: ModuleGen = .{
            .gpa = gpa,
            .tree = tree,
            .arena = arena.allocator(),
        };
        try self.genBlock(self.tree);
        return self;
    }

    fn genBlock(self: *ModuleGen, block: ast.Block) !void {
        for (block.statements) |statement| {
            try self.genStatement(statement);
        }
    }

    fn genStatement(self: *ModuleGen, statement: *const ast.Statement) !void {
        switch (statement.*) {
            .expression => |expression| {
                try self.genExpression(expression);
            },
            .assignment => {
                @panic("assignment not implemented lol");
            },
            .declaration => {
                @panic("decl not implemented lol");
            },
        }
    }

    fn genExpression(self: *ModuleGen, expression: *const ast.Expression) !void {
        switch (expression.*) {
            .literal => |literal| {
                try self.genLiteral(literal);
            },
            .identifier => {
                @panic("not implemented lol");
            },
            .binary_operation => {
                @panic("not implemented lol");
            },
            .unary_operation => {
                @panic("not implemented lol");
            },
            .function_call => |function_call| {
                try self.genFunction(&function_call);
            },
        }
    }

    fn genLiteral(self: *ModuleGen, literal: *const tok.Token) !void {
        switch (literal.*) {
            .string_literal => |string_token| {
                try self.strings.appendSlice(
                    self.gpa,
                    self.source[string_token.start..string_token.end],
                );
                const string = try self.arena.create(rt.String);
                string.* = .{
                    // guarenteed this is an off by one error somehow
                    .items = self.strings[self.string.len - string_token.start .. self.string.len],
                };
                self.objects.append(self.gpa, &string);
            },
            .integer_literal => {
                @panic("not implemented");
            },
        }
    }

    fn genFunction(self: *ModuleGen, function_call: *const ast.FunctionCall) !void {
        _ = self; // autofix
        _ = function_call; // autofix
        // Check whether this is a builtin function
        if (mta.stringToEnum(bc.Builtin, function_call.identifier.)) {}
    }
};

fn testCreateTree(arena: *std.heap.ArenaAllocator, source: []const u8) !ast.Block {
    const allocator = arena.allocator();
    var tokenizer = try tok.Tokenizer.init(allocator, source);
    const tokens = try tokenizer.tokenize();

    return try ast.Block.parse(allocator, tokens);
}

test "ast gen basics" {
    const source =
        \\print("hello world");
    ;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const tree = try testCreateTree(&arena, source);
    _ = try ModuleGen.generate(ts.allocator, tree);
}
