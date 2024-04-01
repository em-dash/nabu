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

pub const Error = enum(u16) {
    ok = 0,
    _,
};

pub const ShortType = enum(u3) {
    bool,
    int,
    float,
    // string,
    // array,
    // map,
    // reference,
};

pub const FullType = enum(u32) {
    bool,
    int,
    float,
    // string,
    // array,
    // map,
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

pub const Bool = struct {
    header: ObjectHeader,
    value: bool,
};

pub const Int = struct {
    header: ObjectHeader,
    value: i32,
};

pub const Float = struct {
    header: ObjectHeader,
    value: f32,
};

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

const Value = union {
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
    allocator: Allocator,
    // bytecode: []u8 = &.{},
    // function_table: AutoHashMapUnmanaged(u32, []u32) = .{},
    // readonly_objects: []u32,
    // readonly_object_table: AutoHashMapUnmanaged(u32, []u32) = .{},
    // names: []u8,
    // name_table: AutoHashMapUnmanaged(u32, []u8) = .{},
    // type_data: []u8,
    // type_table: AutoHashMapUnmanaged(u32, []u32) = .{},
    /// Main thread has id `0`.
    // threads: AutoHashMapUnmanaged(u32, Thread) = .{},
    main_thread: Thread,

    pub fn loadBytecode(self: Runtime, code: []const u8) !void {
        try self.bytecode.appendSlice(self.allocator, code);
    }

    fn run(self: *Runtime) void {
        self.threads.getPtr(0).?.run(0);
    }

    pub fn init(allocator: Allocator) !Runtime {
        var result: Runtime = .{
            .allocator = allocator,
            .main_thread = undefined,
        };
        // const main_thread = try Thread.init(&result, .{});
        result.main_thread = try Thread.init(&result, .{});
        // try result.threads.put(allocator, 69, main_thread);
        return result;
    }

    pub fn deinit(self: *Runtime) void {
        // var threads_iter = self.threads.iterator();
        // while (threads_iter.next()) |entry| {
        //     entry.value_ptr.deinit();
        // }
        // self.threads.deinit(self.allocator);
        self.main_thread.deinit();
    }
};

/// Stack frame.
const Frame = packed struct {
    /// Program counter.
    pc: u32,
    /// Index of the start of the previous stack frame; `std.math.maxInt(u32)` represents null.
    prev: u32,
    /// Offset to top of stack from the start of this object.
    tos: InPlaceObject,
};

const Thread = struct {
    call_stack: []u32,
    top_frame: u32,
    runtime: *const Runtime,

    fn pushFrame(pc: u32) !void {
        _ = pc; // autofix
    }

    fn popFrame() void {}

    pub fn run(self: *Thread, entry_point: u32) void {
        _ = self; // autofix
        _ = entry_point; // autofix
    }

    pub fn init(runtime: *const Runtime, options: Options) !Thread {
        if (options.stack_size % 4 != 0) return error.InvalidStackSize;

        var result: Thread = undefined;
        result.runtime = runtime;
        result.call_stack = try runtime.allocator.alloc(u32, options.stack_size / 4);
        std.log.debug("just allocated: addr = {x}, size = {d}", .{ @intFromPtr(result.call_stack.ptr), result.call_stack.len });

        return result;
    }

    pub fn deinit(self: Thread) void {
        std.log.debug("deallocating:   addr = {x}, size = {d}", .{ @intFromPtr(self.call_stack.ptr), self.call_stack.len });
        self.runtime.allocator.free(self.call_stack);
    }

    const Options = struct {
        /// Stack size in bytes.  Default 1MB.
        // stack_size: usize = 1024 * 1024,
        stack_size: usize = 1024,
    };
};

test "load constants" {
    testing.log_level = .debug;

    var runtime = try Runtime.init(testing.allocator);
    defer runtime.deinit();
    // const code = try bytecode.stringToBytecode(testing.allocator, "load_int 666");
    // defer testing.allocator.free(code);

    // runtime.run();
}
