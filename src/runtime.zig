const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const AutoHashMapUnmanaged = std.AutoHashMapUnmanaged;
const AutoHashMap = std.AutoHashMap;
const assert = std.debug.assert;
const testing = std.testing;
const log = std.log;

const bytecode = @import("bytecode.zig");
const Module = bytecode.Module;
const Opcode = bytecode.Opcode;
const Argument = bytecode.Argument;
const Builtin = bytecode.Builtin;

const types = @import("types.zig");
const IdSet = types.IdSet;

pub const Error = enum(u16) {
    ok = 0,
    _,
};

pub const Type = enum(u32) {
    bool,
    int,
    float,
    string,
    array,
    map,
    reference,
    _,
};

pub const CompoundType = enum {
    @"struct",
    @"enum",
    @"union",
    interface,
};

pub const ObjectHeader = struct {
    type: Type,
};

// pub const Bool = struct {
//     header: ObjectHeader,
//     value: bool,
// };

// pub const Int = struct {
//     header: ObjectHeader,
//     value: i32,
// };

// pub const Float = struct {
//     header: ObjectHeader,
//     value: f32,
// };

pub const String = struct {
    header: ObjectHeader = .{ .type = .string },
    items: []u8 = &[_]u8{},
    capacity: usize = 0,
    location: enum { string_table, heap } = .string_table,
};

// pub const Array = struct {
//     header: ObjectHeader,
//     value: ArrayListUnmanaged(InPlaceObject),
// };

// pub const Map = struct {
//     header: ObjectHeader,
//     value: AutoHashMapUnmanaged(InPlaceObject, InPlaceObject),
// };

const Value = packed union {
    bool: bool,
    float: f32,
    int: i32,
    ref: u32,
};

const Runtime = struct {
    allocator: Allocator = undefined,
    // bytecode: []u8 = &.{},
    bytecode: ArrayListUnmanaged(u8) = .{},
    /// Table of u32 locations of the start of functions.
    function_table: IdSet(u32) = IdSet(u32).init(),
    object_table: IdSet(*ObjectHeader) = IdSet(*ObjectHeader).init(),
    name_table: IdSet([]u8) = IdSet([]u8).init(),
    type_table: IdSet(Type) = IdSet(Type).init(),
    threads: IdSet(Thread) = IdSet(Thread).init(),
    main_thread: u32 = undefined,

    pub fn loadBytecode(self: *Runtime, code: []const u8) !void {
        log.debug("runtime: loading {} bytes of bytecode", .{code.len});
        try self.bytecode.appendSlice(self.allocator, code);
    }

    pub fn run(self: *Runtime) !void {
        try self.threads.getPtr(self.main_thread).?.run(0);
    }

    pub fn create(allocator: Allocator) !*Runtime {
        const result = try allocator.create(Runtime);
        result.* = .{};
        result.allocator = allocator;
        result.threads = IdSet(Thread).init();
        result.main_thread = try result.threads.put(allocator, try Thread.init(result, .{}));
        return result;
    }

    pub fn destroy(self: *Runtime) void {
        var threads_iter = self.threads.map.iterator();
        while (threads_iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.threads.deinit(self.allocator);
        self.bytecode.deinit(self.allocator);
        self.object_table.deinit(self.allocator);
        self.allocator.destroy(self);
    }
};

/// Stack frame.
const Frame = packed struct {
    /// Index of the start of the previous stack frame; `std.math.maxInt(u32)` represents null.
    prev: u32 = std.math.maxInt(u32),
    /// Size of this stack frame; the next stack frame needs to leave this much space.
    len: u32 = 0,
    /// Register stack offset
    reg_base: u32,
    reg_len: u32,
};

const Thread = struct {
    call_stack: []u8,
    reg: []Value,
    top_frame: u32,
    runtime: *const Runtime,
    pc: u32,

    inline fn getTopFrame(self: *Thread) *Frame {
        return @alignCast(mem.bytesAsValue(
            Frame,
            self.call_stack[self.top_frame .. self.top_frame + @sizeOf(Frame)],
        ));
    }

    inline fn getArg(self: *Thread, comptime op: Opcode) op.argType() {
        const argument_slice = self.runtime.bytecode.items[self.pc .. self.pc + op.argLength()];
        const argument: op.argType() =
            mem.littleToNative(op.argType(), mem.bytesToValue(op.argType(), argument_slice));
        self.pc += @intCast(op.argLength());
        log.debug("argument: {}, type: {}", .{ argument, @TypeOf(argument) });
        return argument;
    }

    inline fn pushToStack(self: *Thread, value: Value) void {
        const frame = self.getTopFrame();
        self.reg[frame.reg_base + frame.reg_len] = value;
        frame.reg_len += 1;
    }

    inline fn popFromStack(self: *Thread) Value {
        const frame = self.getTopFrame();
        const result = self.reg[frame.reg_base + frame.reg_len - 1];
        frame.reg_len -= 1;
        return result;
    }

    inline fn getTosPointer(self: *Thread) *Value {
        const frame = self.getTopFrame();
        return &self.reg[frame.reg_base + frame.reg_len - 1];
    }

    pub fn run(self: *Thread, entry_point: u32) !void {
        // Build the first stack frame.
        self.top_frame = 0;
        self.getTopFrame().* = .{
            .reg_base = 0,
            .reg_len = 0,
        };

        self.pc = entry_point;
        main_loop: while (true) {
            const frame = self.getTopFrame();
            log.debug("pc = {}", .{self.pc});
            const op: Opcode = @enumFromInt(self.runtime.bytecode.items[self.pc]);
            log.debug("operation: {s}", .{@tagName(op)});
            self.pc += 1;
            switch (op) {
                .no_op => {},
                .int_add => {
                    assert(frame.reg_len >= 2);
                    const int = self.popFromStack().int;
                    self.getTosPointer().int += int;
                },
                .call_function => {},
                .int_divide => {},
                .jump => {
                    const arg = self.getArg(.jump);
                    _ = arg; // autofix
                },
                .jump_relative => {
                    const arg = self.getArg(.jump_relative);
                    _ = arg; // autofix
                },
                .load_bool => {},
                .load_float => {},
                .load_int => {
                    const arg = self.getArg(.load_int);
                    self.reg[frame.reg_base + frame.reg_len].int = arg;
                    frame.reg_len += 1;
                },
                .load_ref => {
                    const arg = self.getArg(.load_ref);
                    self.pushToStack(.{ .ref = arg });
                },
                .int_multiply => {},
                .set_stack_size => {
                    const arg = self.getArg(.set_stack_size);
                    _ = arg; // autofix
                },
                .store_local => {},
                .int_subtract => {},
                .load_local => {},
                .halt => {
                    break :main_loop;
                },
                .call_builtin => {
                    // std.debug.print("pog\n", .{});
                    const arg = self.getArg(.call_builtin);
                    switch (arg.id) {
                        .string_puts => {
                            assert(arg.count == 1);

                            const ref = self.popFromStack().ref;
                            const header = self.runtime.object_table.getPtr(ref).?.*;
                            const string: *String = @alignCast(@fieldParentPtr("header", header));

                            try std.io.getStdOut().writer().print("{s}\n", .{string.items});
                        },
                    }
                },
            }
        }
    }

    pub fn init(runtime: *const Runtime, options: Options) !Thread {
        var result: Thread = undefined;
        result.runtime = runtime;
        result.call_stack = try runtime.allocator.alloc(u8, options.frame_stack_size);
        result.reg =
            try runtime.allocator.alloc(Value, options.register_stack_size);

        return result;
    }

    pub fn deinit(self: Thread) void {
        self.runtime.allocator.free(self.call_stack);
        self.runtime.allocator.free(self.reg);
    }

    const Options = struct {
        /// Stack size in bytes.  Default 1MB.
        frame_stack_size: usize = 1024 * 1024,
        /// Register stack size in number of 4-byte items.
        register_stack_size: usize = 4096,
    };
};

test "load constants" {
    const runtime = try Runtime.create(testing.allocator);
    defer runtime.destroy();
    const code = try bytecode.assembleBytecode(testing.allocator,
        \\set_stack_size 0
        \\load_int 666
        \\halt
    );
    defer testing.allocator.free(code);

    try runtime.loadBytecode(code);

    try runtime.run();
    try testing.expectEqual(
        666,
        runtime.threads.getPtr(runtime.main_thread).?.reg[0].int,
    );
}

test "add" {
    const runtime = try Runtime.create(testing.allocator);
    defer runtime.destroy();
    const code = try bytecode.assembleBytecode(testing.allocator,
        \\set_stack_size 0
        \\load_int 5
        \\load_int 10
        \\int_add
        \\halt
    );
    defer testing.allocator.free(code);

    try runtime.loadBytecode(code);

    try runtime.run();
    try testing.expectEqual(
        15,
        runtime.threads.getPtr(runtime.main_thread).?.reg[0].int,
    );
}

// test "puts" {
//     const runtime = try Runtime.create(testing.allocator);
//     defer runtime.destroy();
//     const message = "小熊貓";
//     var string: String = .{ .value = try testing.allocator.alloc(u8, message.len) };
//     defer testing.allocator.free(string.value);
//     mem.copyForwards(u8, string.value, message);
//     // HACK THIS just assumes the id will be 0, which it will, but it's still bad.  assert to catch
//     // if it isn't.
//     assert(try runtime.object_table.put(runtime.allocator, &string.header) == 0);
//     const code = try bytecode.assembleBytecode(testing.allocator,
//         \\set_stack_size 0
//         \\load_ref 0
//         \\call_builtin string_puts 1
//         \\halt
//     );
//     defer testing.allocator.free(code);
//     // const bork = try bytecode.disassembleBytecode(testing.allocator, code);
//     // defer testing.allocator.free(bork);
//     // std.debug.print("{s}\n", .{bork});

//     try runtime.loadBytecode(code);
//     try runtime.run();
// }
