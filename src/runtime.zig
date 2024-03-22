const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const AutoHashMapUnmanaged = std.AutoHashMapUnmanaged;
const AutoHashMap = std.AutoHashMap;
const assert = std.debug.assert;

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
    _,
};

pub const ContainerType = enum {
    @"struct",
    @"enum",
    // @"union",
    interface,
};

pub const ObjectHeader = struct {
    type: FullType,
    /// This is only defined for `_` values of `type`, otherwise it's undefined.
    container: ContainerType,
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

pub const String = struct {
    header: ObjectHeader,
    value: ArrayListUnmanaged(u8),
};

pub const Array = struct {
    header: ObjectHeader,
    value: ArrayListUnmanaged(InPlaceObject),
};

pub const Map = struct {
    header: ObjectHeader,
    value: AutoHashMapUnmanaged(InPlaceObject, InPlaceObject),
};

const InPlaceObject = packed struct {
    comptime {
        assert(@bitSizeOf(InPlaceObject) == 64);
    }

    value: union {
        bool: bool,
        float: f32,
        int: i32,
        ref: u32,
    },
    @"error": Error,
    optional: bool,
    is_null: bool,
    _padding0: u6,
    type: ShortType,
    _padding1: u5,
};

const Runtime = struct {
    allocator: Allocator,
    bytecode: []u8,
    function_table: AutoHashMapUnmanaged(u32, []u32) = .{},
    // readonly_objects: []u32,
    readonly_object_table: AutoHashMapUnmanaged(u32, []u32) = .{},
    // names: []u8,
    name_table: AutoHashMapUnmanaged(u32, []u8) = .{},
    // type_data: []u8,
    type_table: AutoHashMapUnmanaged(u32, []u32) = .{},
    threads: AutoHashMapUnmanaged(u32, *Thread) = .{},

    pub fn init(allocator: Allocator) !Runtime {
        return .{
            .allocator = allocator,
        };
    }

    // pub fn loadModuleFromMemory(self: *Runtime, module: *Module) !void {
    //     const unsafe_module_ptr: [*]u8 = @ptrCast(module);

    //     // Load bytecode.
    //     const old_bytecode_len = self.bytecode.items.len;
    //     self.bytecode.appendSlice(
    //         self.allocator,
    //         unsafe_module_ptr[module.bytecode .. module.bytecode + module.bytecode_len],
    //     );
    //     const new_bytecode_slice = unsafe_module_ptr[old_bytecode_len..self.bytecode.items.len];
    //     _ = new_bytecode_slice; // autofix

    //     const old_objects_len = self.readonly_objects.items.len;
    //     self.readonly_objects = self.readonly_objects.appendSlice(
    //         self.allocator,
    //         unsafe_module_ptr[module.object_table .. module.object_table + module.object_table_len],
    //     );
    //     const new_objects_slice =
    //         unsafe_module_ptr[old_objects_len..self.readonly_objects.items.len];
    //     _ = new_objects_slice; // autofix

    //     var new_names = AutoHashMap(u32, []const u8).init(module.allocator);
    //     // Read name table.
    //     {
    //         const name_table_start = @sizeOf(Module);
    //         const name_table_slice =
    //             unsafe_module_ptr[name_table_start .. name_table_start + module.name_table_len];
    //         var index = 0;
    //         while (true) {
    //             const id = mem.readInt(u32, name_table_slice[index .. index + 4], .little);
    //             index += 4;
    //             const name = mem.sliceTo(name_table_slice[index..], '\x00');
    //             // We assume the module is valid here.
    //             new_names.put(name, id);
    //             if (index == 0) break;
    //         }

    //         // temporary: just put the names in without processing
    //         var iter = new_names.iterator();
    //         while (iter.next()) |name| {
    //             const value = try self.allocator.dupe(u8, name.value_ptr.*);
    //             self.name_table.putNoClobber(self.allocator, name.key_ptr.*, value);
    //         }

    //         // // Match names with existing nametables.
    //         // var name_remaps = AutoHashMap(u32, []const u8).init(module.allocator);
    //         // _ = name_remaps; // autofix
    //         // {
    //         //     var new_names_iter = new_names.iterator();
    //         //     var name_table_iter = self.name_table.iterator();
    //         //     while (new_names_iter.next()) |new_name| {
    //         //         _ = new_name; // autofix
    //         //         while (name_table_iter.next()) |existing_name| {
    //         //             _ = existing_name; // autofix
    //         //         }
    //         //     }
    //         // }

    //         // // Resolve identifiers.
    //     }

    //     var index: usize = 0;
    //     _ = index; // autofix
    //     {
    //         while (true) {}
    //     }
    // }

    // fn loadModuleFromFile() !void {}
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

    fn pushFrame(pc: u32) !void {
        _ = pc; // autofix
    }

    pub fn run(entry_point: u32) void {
        _ = entry_point; // autofix
    }

    pub fn init(allocator: Allocator, options: Options) !Thread {
        if (options.stack_size % 4 != 0) return error.InvalidStackSize;

        return .{
            .call_stack = try allocator.alloc(u32, options.stack_size / 4),
        };
    }

    pub fn deinit(self: Thread, allocator: Allocator) void {
        allocator.free(self.call_stack);
    }

    const Options = struct {
        /// Stack size in bytes.  Default 1MB.
        .stack_size = 1024 * 1024,
    };
};
