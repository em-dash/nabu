const stderr = std.io.getStdErr().writer();

pub fn print(err: Error, source: Source) void {
    stderr.print("compile error: ", .{});
    switch (err) {
        .invalid_character => |index| {
            const location = source.getLocation(index);
            try stderr.print("invalid character on line {}, column {}\n", .{});
            const slice = source.getLineSlice(location.line);
            try stderr.print("{s}", .{slice});
        },
    }
}

const Error = union(Code) {
    invalid_character: u32,
};

/// Error codes
const Code = enum(u32) {
    // 1xx source file errors
    invalid_character = 100,
};

const std = @import("std");

const Source = @import("Source.zig");
