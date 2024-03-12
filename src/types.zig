const std = @import("std");
const Value = std.atomic.Value;
const AutoHashMap = std.AutoHashMap;

const ObjectHeader = struct {
    // refs: usize,
};

const String = struct {
    header: ObjectHeader,
    slice: []u8,
};

const Object = struct {
    data: union {
        header: *ObjectHeader,
        small_int: i32,
        // small_float: f32,
        bool: bool,
    },
};
