const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const AutoHashMapUnmanaged = std.AutoHashMapUnmanaged;
const AutoHashMap = std.AutoHashMap;
const assert = std.debug.assert;
const testing = std.testing;

const bytecode = @import("bytecode.zig");
const Module = bytecode.Module;
const Opcode = bytecode.Opcode;
const Argument = bytecode.Argument;

const types = @import("types.zig");
const IdSet = types.IdSet;

pub const Error = enum(u16) {
    ok = 0,
    _,
};

pub const ShortType = enum(u3) {
    bool,
    int,
    float,
    string,
    array,
    map,
    reference,
};

pub const FullType = enum(u32) {
    bool,
    int,
    float,
    string,
    array,
    map,
    reference,
    _,
};

pub const UserType = enum {
    @"struct",
    @"enum",
    @"union",
    interface,
};

pub const ObjectHeader = struct {
    type: FullType,
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

// pub const String = struct {
//     header: ObjectHeader,
//     value: ArrayListUnmanaged(u8),
// };

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
    // ref: u32,
};

const InPlaceObject = packed struct {
    comptime {
        assert(@bitSizeOf(InPlaceObject) == 64);
    }

    value: Value,
    @"error": Error,
    optional: bool,
    is_null: bool,
    _padding0: u6,
    type: ShortType,
    _padding1: u5,
};

const Runtime = struct {
    allocator: Allocator = undefined,
    // bytecode: []u8 = &.{},
    bytecode: ArrayListUnmanaged(u8) = .{},
    /// Table of u32 locations of the start of functions.
    function_table: IdSet(u32) = IdSet(u32).init(),
    readonly_object_table: IdSet(ObjectHeader) = IdSet(ObjectHeader).init(),
    name_table: IdSet([]u8) = IdSet([]u8).init(),
    type_table: IdSet(FullType) = IdSet(FullType).init(),
    threads: IdSet(Thread) = IdSet(Thread).init(),
    main_thread: u32 = undefined,

    pub fn loadBytecode(self: *Runtime, code: []const u8) !void {
        try self.bytecode.appendSlice(self.allocator, code);
    }

    pub fn run(self: *Runtime) void {
        self.threads.getPtr(self.main_thread).?.run(0);
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
    register_stacks: []InPlaceObject,
    top_frame: u32,
    runtime: *const Runtime,
    pc: u32,

    inline fn getTopFrame(self: *Thread) *Frame {
        return @alignCast(mem.bytesAsValue(
            Frame,
            self.call_stack[self.top_frame .. self.top_frame + @sizeOf(Frame)],
        ));
    }

    pub fn run(self: *Thread, entry_point: u32) void {
        // Build the entry point stack frame.  Aah.
        self.top_frame = 0;
        self.getTopFrame().* = .{
            .reg_base = 0,
            .reg_len = 0,
        };

        self.pc = entry_point;
        main_loop: while (true) {
            const op: Opcode = @enumFromInt(self.runtime.bytecode.items[self.pc]);
            self.pc += 1;
            const argument_slice = self.runtime.bytecode.items[self.pc .. self.pc + op.argLength()];
            const argument: Argument = switch (op) {
                inline else => |o| @unionInit(
                    Argument,
                    @tagName(o),
                    mem.littleToNative(o.argType(), mem.bytesToValue(o.argType(), argument_slice)),
                ),
            };
            self.pc += @intCast(op.argLength());
            switch (op) {
                .no_op => {},
                .add => {},
                .call_function => {},
                .divide => {},
                .jump => {},
                .jump_relative => {},
                .load_bool => {},
                .load_float => {},
                .load_index => {},
                .load_int => {
                    const frame = self.getTopFrame();
                    self.register_stacks[frame.*.reg_base + frame.*.reg_len] = .{
                        .value = .{ .int = argument.load_int },
                        .@"error" = .ok,
                        .optional = false,
                        .is_null = undefined,
                        ._padding0 = undefined,
                        .type = .int,
                        ._padding1 = undefined,
                    };
                    frame.*.reg_len += 1;
                },
                .load_readonly => {},
                .multiply => {},
                .set_stack_size => {},
                .store => {},
                .subtract => {},
                .load_stack_local => {},
                .halt => {
                    break :main_loop;
                },
            }
        }
    }

    pub fn init(runtime: *const Runtime, options: Options) !Thread {
        var result: Thread = undefined;
        result.runtime = runtime;
        result.call_stack = try runtime.allocator.alloc(u8, options.frame_stack_size);
        result.register_stacks =
            try runtime.allocator.alloc(InPlaceObject, options.register_stack_size);

        return result;
    }

    pub fn deinit(self: Thread) void {
        self.runtime.allocator.free(self.call_stack);
        self.runtime.allocator.free(self.register_stacks);
    }

    const Options = struct {
        /// Stack size in bytes.  Default 1MB.
        frame_stack_size: usize = 1024 * 1024,
        /// Register stack size in number of 8-byte items.
        register_stack_size: usize = 4096,
    };
};

test "load constants" {
    const runtime = try Runtime.create(testing.allocator);
    defer runtime.destroy();
    const code = try bytecode.stringToBytecode(testing.allocator,
        \\set_stack_size 0
        \\load_int 666
        \\halt
    );
    defer testing.allocator.free(code);

    try runtime.loadBytecode(code);

    runtime.run();
    try testing.expectEqual(
        666,
        runtime.threads.getPtr(runtime.main_thread).?.register_stacks[0].value.int,
    );
}
