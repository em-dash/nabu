const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const AutoHashMapUnmanaged = std.AutoHashMapUnmanaged;
const AutoHashMap = std.AutoHashMap;

const bytecode = @import("bytecode.zig");
const Module = bytecode.Module;

const types = @import("types.zig");
const Object = types.Object;

const Runtime = struct {
    allocator: Allocator,
    bytecode: ArrayListUnmanaged(u8),
    readonly_objects: ArrayListUnmanaged(u8),
    function_table: AutoHashMapUnmanaged(u32, []const u8) = .{},
    name_table: AutoHashMapUnmanaged(u32, []const u8) = .{},
    object_table: AutoHashMapUnmanaged(u32, *Object) = .{},
    threads: AutoHashMapUnmanaged(u32, *Thread) = .{},

    pub fn init(allocator: Allocator) !Runtime {
        return .{
            .allocator = allocator,
        };
    }

    pub fn loadModuleFromMemory(self: *Runtime, module: *Module) !void {
        const unsafe_module_ptr: [*]u8 = @ptrCast(module);

        // Load bytecode.
        const old_bytecode_len = self.bytecode.items.len;
        self.bytecode.appendSlice(
            self.allocator,
            unsafe_module_ptr[module.bytecode .. module.bytecode + module.bytecode_len],
        );
        const new_bytecode_slice = unsafe_module_ptr[old_bytecode_len..self.bytecode.items.len];
        _ = new_bytecode_slice; // autofix

        const old_objects_len = self.readonly_objects.items.len;
        self.readonly_objects = self.readonly_objects.appendSlice(
            self.allocator,
            unsafe_module_ptr[module.object_table .. module.object_table + module.object_table_len],
        );
        const new_objects_slice =
            unsafe_module_ptr[old_objects_len..self.readonly_objects.items.len];
        _ = new_objects_slice; // autofix

        var new_names = AutoHashMap(u32, []const u8).init(module.gpa);
        // Read name table.
        {
            const name_table_start = @sizeOf(Module);
            const name_table_slice =
                unsafe_module_ptr[name_table_start .. name_table_start + module.name_table_len];
            var index = 0;
            while (true) {
                const id = mem.readInt(u32, name_table_slice[index .. index + 4], .little);
                index += 4;
                const name = mem.sliceTo(name_table_slice[index..], '\x00');
                // We assume the module is valid here.
                new_names.put(name, id);
                if (index == 0) break;
            }

            // Match names with existing nametables.
            var name_remaps = AutoHashMap(u32, []const u8).init(module.gpa);
            _ = name_remaps; // autofix
            {
                var new_names_iter = new_names.iterator();
                var name_table_iter = self.name_table.iterator();
                while (new_names_iter.next()) |new_name| {
                    _ = new_name; // autofix
                    while (name_table_iter.next()) |existing_name| {
                        _ = existing_name; // autofix
                    }
                }
            }

            // Resolve identifiers.
        }
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
