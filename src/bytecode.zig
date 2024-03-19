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
const ObjectIndex = types.ObjectIndex;
const InstructionIndex = types.InstructionIndex;
const ObjectHeader = types.ObjectHeader;
const fmt = std.fmt;

const Opcode = enum(u8) {
    add,
    call_function,
    divide,
    jump,
    jump_relative,
    load_bool,
    load_float,
    load_index,
    load_int,
    load_readonly,
    multiply,
    no_op,
    store,
    subtract,

    // extended = 255,

    inline fn argType(self: Opcode) type {
        return arg_types.get(self);
    }

    const arg_types = std.EnumArray(Opcode, type).init(.{
        .add = void,
        .call_function = void,
        .divide = void,
        .jump_relative = i8,
        .jump = u32,
        .load_bool = bool,
        .load_float = f32,
        .load_index = u32,
        .load_int = i32,
        .load_readonly = u32,
        .multiply = void,
        .no_op = void,
        .store = u32,
        .subtract = void,
    });

    inline fn argLength(self: Opcode) usize {
        return arg_lens.get(self);
    }

    const arg_lens = arg_lens_block: {
        var result = std.EnumArray(Opcode, usize).initUndefined();
        var iter = result.iterator();
        while (iter.next()) |opcode| {
            result.set(opcode.key, @sizeOf(arg_types.get(opcode.key)));
        }
        break :arg_lens_block result;
    };
};

// pub fn stringToBytecode(allocator: Allocator, string: []const u8) ![]const u8 {}

/// Caller owns returned slice. Asserts that `code` is valid bytecode.
pub fn bytecodeToString(allocator: Allocator, code: []const u8) ![]const u8 {
    var string = ArrayList(u8).init(allocator);

    var i: usize = 0;
    while (i < code.len) : (i += 1) {
        const opcode: Opcode = @enumFromInt(code[i]);
        try string.appendSlice(@tagName(opcode));
        const arg_len = opcode.argLength();
        if (arg_len > 0) {
            const arg = mem.bytesAsValue(u32, code[i .. i + arg_len]);
            for (0..30 - @tagName(opcode).len) |_| try string.append(' ');
            try string.writer().print("{x.8}", .{arg});
        }
        try string.append('\n');
    }

    return try string.toOwnedSlice();
}

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

/// Compiled module header.  Modules have the same memory representation in memory and in cache on
/// disk.  Data is little-endian.
///
/// Layout:
/// - (magic number included in file, truncated here)
/// - (version number included in file, truncated here)
/// - header
/// - name table (list of u32 byte offsets to names)
///   - the first name in the name table is the name of the module
///   - format is: u32 identifier followed by a null-terminated utf-8 name
/// - object table (list of u32 byte offsets to objects)
/// - code
///
/// Within a module, identifier numbers have consistent meaning, and the name table links these to a
/// human readable and module-independant name.  When the module is loaded, these identifier numbers
/// are modified to resolve names accross all loaded modules.
const Module = packed struct {
    /// Length of the name table in bytes.
    name_table_len: u32,
    /// Offset to object table in bytes.
    object_table: u32,
    /// Length of the object table in 32-bit words.
    object_table_len: u32,
    /// Offset to function table in bytes.
    function_table: u32,
    /// Length of the function table in bytes; `function_table_len / 2` is the number of table
    /// entries.
    function_table_len: u32,
    /// Offset to the code in 32-bit words;
    bytecode: u32,
    /// Length of the bytecode in bytes.
    bytecode_len: u32,

    pub fn getLen(self: *Module) usize {
        return self.bytecode + self.bytecode_len;
    }

    pub fn getBytecodeSlice(self: *Module) []const u8 {
        const ptr: [*]const u8 = @ptrCast(self);
        return ptr[self.code .. self.code + self.code_len];
    }
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
