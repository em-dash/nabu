const std = @import("std");
const assert = std.debug.assert;
const Value = std.atomic.Value;
const AutoHashMap = std.AutoHashMap;
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const AutoArrayHashMap = std.AutoArrayHashMap;

// const Set = struct {
//     allocator: Allocator,
//     ids: ArrayListUnmanaged,
//     data: ArrayListUnmanaged,
// };

pub fn IdSet(T: type) type {
    return struct {
        map: AutoArrayHashMap(u32, T),

        const Self = @This();

        pub fn init(allocator: Allocator) Self {
            return .{
                .map = AutoArrayHashMap.init(allocator),
            };
        }

        pub fn remove(self: *Self, id: u32) bool {
            return self.map.swapRemove(id);
        }

        pub fn get(self: Self, id: u32) ?T {
            return self.map.getPtr(id);
        }

        /// Inserts `item` into the set and returns its id.
        pub fn put(self: *Self, item: T) !u32 {
            const new_id = id_loop: for (0..std.math.maxInt(u32)) |n| {
                if (!self.map.contains(n)) break :id_loop n;
            } else {
                return error.SetFull;
            };

            try self.map.putNoClobber(new_id, item);
        }
    };
}

const Slice32 = struct {
    start: u32,
    len: u32,
};

/// Inbuilt types and space for user types.
const Type = enum(u16) {
    int,
    float,
    bool,
    string,
    array,
    map,
    _,
};

const TypeInfo = packed struct {
    type: Type,
};

/// Inbuilt types and `reference`.
const ShortType = enum(u3) {
    int,
    float,
    bool,
    string,
    array,
    map,
    reference,
};

const Error = enum(u16) {
    ok = 0,
    _,
};

const ObjectHeader = packed struct {
    // refs: usize,
    type: Type,
    optional: bool,
    _padding_0: u7,
    is_null: bool,
    _padding_1: u7,
    field_count: u32,
};

// const String = struct {
//     header: ObjectData,
//     slice: []u8,
// };

/// Either an in-place small value like a u32 or f32, or a reference to a full-size object.
const ShortObject = packed struct {
    comptime {
        assert(@bitSizeOf(ShortObject) == 64);
    }

    data: union { // 32
        id: u32,
        small_int: i32,
        small_float: f32,
        bool: bool,
    },
    type: ShortType, // 35
    optional: bool, // 36
    is_null: bool, // 37
    _padding_0: u11, // 48
    @"error": Error, // 64
};
