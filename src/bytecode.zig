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
const fmt = std.fmt;

const runtime = @import("runtime.zig");
const ShortType = runtime.ShortType;

/// List of builtin functions
pub const Builtin = enum(u16) {
    // Builtin type operations
    string_puts,
};

pub const BuiltinArgument = extern struct {
    id: Builtin align(1),
    count: u8 align(1),
};

pub const Argument = union(Opcode) {
    halt: void,
    int_add: void,
    call_function: u8 align(1),
    set_stack_size: u16 align(1),
    int_divide: void,
    jump: u32 align(1),
    jump_relative: i8 align(1),
    load_bool: bool align(1),
    load_float: f32 align(1),
    load_int: i32 align(1),
    load_ref: u32 align(1),
    load_local: u16 align(1),
    int_multiply: void,
    no_op: void align(1),
    store_local: u32 align(1),
    int_subtract: void,
    call_builtin: BuiltinArgument align(1),
};

pub const Opcode = enum(u8) {
    halt,
    int_add,
    call_function,
    set_stack_size,
    int_divide,
    jump,
    jump_relative,
    load_bool,
    load_float,
    load_int,
    load_ref,
    load_local,
    int_multiply,
    no_op,
    store_local,
    int_subtract,
    call_builtin,

    pub fn argType(self: Opcode) type {
        return std.meta.TagPayload(Argument, self);
    }

    pub fn argLength(self: Opcode) usize {
        return switch (self) {
            inline else => |s| @bitSizeOf(std.meta.TagPayload(Argument, s)) / 8,
        };
    }
};

comptime {
    for (@typeInfo(Argument).Union.fields) |i| {
        if (@typeInfo(i.type) == .Struct) {
            var len = 0;
            for (@typeInfo(i.type).Struct.fields) |j| len += @bitSizeOf(j.type);
            len /= 8;

            if (len != @sizeOf(i.type)) @compileError("Argument of opcode " ++ i.name ++
                " has an inconsistent size.\nUse an extern struct with align(1) on every field.");
        }
    }
}

/// Caller owns returned memory.
pub fn assembleBytecode(allocator: Allocator, string: []const u8) ![]const u8 {
    var token_iter = mem.tokenizeAny(u8, string, " \n\r");
    var code = ArrayList(u8).init(allocator);
    errdefer code.deinit();

    while (true) {
        // find operation
        const op = if (token_iter.next()) |op_string|
            std.meta.stringToEnum(Opcode, op_string).?
        else
            break;
        try code.append(@intFromEnum(op));
        // add argument if needed
        if (op.argLength() > 0) {
            const arg = token_iter.next();
            if (arg == null) return error.InvalidBytecode;
            switch (op) {
                .load_int => {
                    const int = try std.fmt.parseInt(i32, arg.?, 0);
                    const little = mem.nativeToLittle(i32, int);
                    try code.appendSlice(mem.asBytes(&little));
                },
                .set_stack_size => {
                    const int = try std.fmt.parseInt(u16, arg.?, 0);
                    const little = mem.nativeToLittle(u16, int);
                    try code.appendSlice(mem.asBytes(&little));
                },
                .call_function,
                .jump,
                .load_ref,
                .load_local,
                .store_local,
                => {
                    const int = try std.fmt.parseInt(u32, arg.?, 0);
                    const little = mem.nativeToLittle(u32, int);
                    try code.appendSlice(mem.asBytes(&little));
                },
                .jump_relative => {
                    const int = try std.fmt.parseInt(i8, arg.?, 0);
                    const little = mem.nativeToLittle(i8, int);
                    try code.appendSlice(mem.asBytes(&little));
                },
                .load_bool, .load_float => {
                    std.debug.panic("not implemented", .{});
                },
                .call_builtin => {
                    // builtin name
                    const builtin_int = @intFromEnum(std.meta.stringToEnum(Builtin, arg.?).?);
                    const builtin_little = mem.nativeToLittle(u16, builtin_int);
                    try code.appendSlice(mem.asBytes(&builtin_little));
                    // number of args
                    const arg2 = token_iter.next();
                    if (arg2 == null) return error.InvalidBytecode;
                    const args_int = try std.fmt.parseInt(u8, arg2.?, 0);
                    const args_little = mem.nativeToLittle(u8, args_int);
                    try code.appendSlice(mem.asBytes(&args_little));
                },
                .int_add,
                .int_divide,
                .int_multiply,
                .halt,
                .no_op,
                .int_subtract,
                => unreachable,
            }
        }
    }

    return try code.toOwnedSlice();
}

test "assemble bytecode" {
    const string = "no_op load_int 0x1234 no_op call_builtin string_puts 1 halt";
    const actual = try assembleBytecode(testing.allocator, string);
    defer testing.allocator.free(actual);
    const expected = [_]u8{
        @intFromEnum(Opcode.no_op),
        @intFromEnum(Opcode.load_int),
        0x34,
        0x12,
        0x00,
        0x00,
        @intFromEnum(Opcode.no_op),
        @intFromEnum(Opcode.call_builtin),
        0x00,
        0x00,
        0x01,
        @intFromEnum(Opcode.halt),
    };
    try testing.expectEqualSlices(u8, &expected, actual);
}

/// Caller owns returned slice.
pub fn disassembleBytecode(allocator: Allocator, code: []const u8) ![]const u8 {
    var string = ArrayList(u8).init(allocator);

    var i: usize = 0;
    while (i < code.len) {
        try string.writer().print("{}\t", .{i});
        const opcode: Opcode = @enumFromInt(code[i]);
        try string.appendSlice(@tagName(opcode));
        try string.appendSlice("\t\t");
        i += 1;

        if (opcode.argLength() > 0) {
            switch (opcode) {
                inline else => |o| {
                    const arg = mem.bytesAsValue(o.argType(), code[i .. i + o.argLength()]);
                    try string.writer().print("{}", .{arg.*});
                    i += o.argLength();
                },
            }
        }
        try string.append('\n');
    }

    return try string.toOwnedSlice();
}

/// Used to build a `Module` out of the given source code
// const Generator = struct {
//     allocator: Allocator,
//     small_ints: ArrayList(i32),
//     // small_floats: ArrayList(f32),
//     string_data: ArrayList(u8),
//     strings: ArrayList([]u8), // indexes of strings
//     objects: ArrayList(*ObjectHeader),
//     code_data: ArrayList(u8),
//     functions: ArrayList([]u8), // indexes of functions

//     pub fn init(allocator: Allocator) Generator {
//         return .{
//             .allocator = allocator,
//             .small_ints = ArrayList(i32).init(allocator),
//             // .small_floats: ArrayList(f32).init(allocator),
//             .string_data = ArrayList(u8).init(allocator),
//             .strings = ArrayList([]u8).init(allocator),
//             .objects = ArrayList(*ObjectHeader),
//             .code_data = ArrayList(u8),
//             .functions = ArrayList([]u8),
//         };
//     }
// };

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

// fn createInt(string: []const u8) runtime.Int {
//     const int = fmt.parseInt(i32, string, 0) catch |err| switch (err) {
//         error.Overflow => {
//             // parse big int here
//             std.debug.panic("big ints not implemented", .{});
//         },
//         error.InvalidCharacter => {
//             std.debug.panic("invalid character in int literal", .{});
//         },
//     };
//     return .{
//         .header = .{
//             .type = .int,
//         },
//         .value = int,
//     };
// }

// test "parse decimal integer" {
//     const decimal =
//         \\17_372_273
//     ;
//     try testing.expectEqual(
//         runtime.Int{ .header = .{ .type = .int }, .value = 17_372_273 },
//         createInt(decimal),
//     );
// }

// test "parse hexadecimal integer" {
//     const string =
//         \\0x0dd_0b0e
//     ;
//     try testing.expectEqual(0x0dd_0b0e, createInt(string));
// }

// test "parse octal integer" {
//     const string =
//         \\0o1234_1234
//     ;
//     try testing.expectEqual(0o12341234, createInt(string));
// }

// test "parse binary integer" {
//     const string =
//         \\0b1111_0000
//     ;
//     try testing.expectEqual(0b1111_0000, createInt(string));
// }

// fn parseString(string: []const u8) []const u8 {
//     assert(string[0] == '"');
//     assert(string[string.len - 1] == '"');
//     return string[1 .. string.len - 1];
// }

// test "parse basic string" {
//     const string =
//         \\"hello 小熊貓"
//     ;
//     try testing.expectEqualStrings("hello 小熊貓", parseString(string));
// }
