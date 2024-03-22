const std = @import("std");
const assert = std.debug.assert;
const Value = std.atomic.Value;
const AutoHashMap = std.AutoHashMap;

const Function = struct {};

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
