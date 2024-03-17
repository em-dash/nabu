const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const AutoHashMapUnmanaged = std.AutoHashMapUnmanaged;

const bytecode = @import("bytecode.zig");
const Module = bytecode.Module;

const types = @import("types.zig");
const Object = types.Object;

const Runtime = struct {
    allocator: Allocator,
    module_data: []const u8 = &[_]u8{},
    function_table: AutoHashMapUnmanaged(u32, []const u8) = .{},
    name_table: AutoHashMapUnmanaged(u32, []const u8) = .{},
    object_table: AutoHashMapUnmanaged(u32, *Object) = .{},
    threads: AutoHashMapUnmanaged(u32, *Thread) = .{},

    pub fn init(allocator: Allocator) !Runtime {
        return .{
            .allocator = allocator,
        };
    }

    // fn loadModuleSymbols(self: *Runtime, )

    pub fn loadModuleFromMemory(self: *Runtime, module: *Module) !void {
        const module_len = module.getBytecodeSlice().len;
        const unsafe_module_ptr: [*]Module = @ptrCast(module);
        var list = ArrayList(u8).fromOwnedSlice(self.allocator, self.module_data);
        try list.appendSlice(unsafe_module_ptr[0..module_len]);
        self.module_data = try list.toOwnedSlice();
    }

    // fn loadModuleFromFile() !void {}
};

/// Stack frame.
const Frame = packed struct {
    /// Program counter.
    pc: u32,
    /// Index of the start of the previous stack frame (within this call stack).
    prev: u32,
    /// Register stack.
    regs: []types.Object,
};

const Thread = struct {
    // call_stack: []u8,

    // pub fn execute() !void {}

    // const Options = struct {
    //     /// Stack size in bytes.  Default 1MB.
    //     .size = 1024 * 1024,
    // };
};
