const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;
const assert = std.debug.assert;
const log = std.log;
const tokenize = @import("tokenization.zig");
const Tokenizer = tokenize.Tokenizer;
const Token = tokenize.Token;
const ast = @import("ast.zig");
const types = @import("types.zig");
const ObjectHeader = types.ObjectHeader;
const fmt = std.fmt;

// const OperationAndArgument = packed struct {
//     op: Opcode,
//     arg: u32,
// };

const Opcode = enum(u8) {
    no_op,
    add,
    subtract,
    multiply,
    divide,
    load_id,
    load_readonly,
    load_value,
    store_value,
    store_pointer,
    print_top_1,
    call_function,
    jump_relative,
    jump,

    // extended = 255,

    /// Returns the length of the argument of `opcode`; returns 0 if it does not take an argument.
    inline fn argLength(opcode: Opcode) u2 {
        return switch (opcode) {
            // zig fmt: off
            .add, .subtract, .multiply, .divide, => 0,
            .call_function, .jump_relative, => 1,
            .load_readonly, .load_id, .store_value, .store_pointer, .load_value, .jump, => 4, 
            // zig fmt: on
        };
    }
};

/// Used to build a `Module` out of the given source code
const Generator = struct {
    allocator: Allocator,
    small_ints: ArrayList(i32),
    // small_floats: ArrayList(f32),
    string_data: ArrayList(u8),
    strings: ArrayList([]u8), // indexes of strings
    objects: ArrayList(*ObjectHeader),
    code_data: ArrayList(u8),
    functions: ArrayList([]u8), // indexes of functions

    pub fn init(allocator: Allocator) Generator {
        return .{
            .allocator = allocator,
            .small_ints = ArrayList(i32).init(allocator),
            // .small_floats: ArrayList(f32).init(allocator),
            .string_data = ArrayList(u8).init(allocator),
            .strings = ArrayList([]u8).init(allocator),
            .objects = ArrayList(*ObjectHeader),
            .code_data = ArrayList(u8),
            .functions = ArrayList([]u8),
        };
    }
};

const Module = struct {
    allocator: Allocator,
    small_ints: []const i32,
    // small_floats: []const f32,
    string_data: []const u8,
    strings: []const []const u8,
    objects: []const *ObjectHeader,
    code_data: []const u8,
    code: []const []const u8,
};

fn parseInt(string: []const u8) i32 {
    const int = fmt.parseInt(i32, string, 0) catch |err| switch (err) {
        error.Overflow => {
            // parse big int here
            std.debug.panic("big ints not implemented", .{});
        },
        error.InvalidCharacter => {
            std.debug.panic("invalid character in int literal", .{});
        },
    };
    return int;
}

test "parse decimal integer" {
    const string =
        \\17_372_273
    ;
    try testing.expectEqual(17_372_273, parseInt(string));
}

test "parse hexadecimal integer" {
    const string =
        \\0x0dd_0b0e
    ;
    try testing.expectEqual(0x0dd_0b0e, parseInt(string));
}

test "parse octal integer" {
    const string =
        \\0o1234_1234
    ;
    try testing.expectEqual(0o12341234, parseInt(string));
}

test "parse binary integer" {
    const string =
        \\0b1111_0000
    ;
    try testing.expectEqual(0b1111_0000, parseInt(string));
}

fn parseString(string: []const u8) []const u8 {
    assert(string[0] == '"');
    assert(string[string.len - 1] == '"');
    return string[1 .. string.len - 1];
}

test "parse basic string" {
    const string =
        \\"hello 小熊貓"
    ;
    try testing.expectEqualStrings("hello 小熊貓", parseString(string));
}
