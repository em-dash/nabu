const stderr = std.io.getStdErr().writer();

pub fn print(err: Error, source: *Source) !void {
    try stderr.print("compile error: ", .{});
    switch (err) {
        .invalid_character => |index| {
            const location = try source.getLocation(index);
            try stderr.print("invalid character on line {}, column {}\n", .{
                location.line,
                location.column,
            });
            const slice = source.getLineSlice(location.line);
            try stderr.print("{s}", .{slice});
        },
        .mismatched_quotes => |index| {
            const location = try source.getLocation(index);
            try stderr.print("mismatched quotes; opened on line {}, column {}\n", .{
                location.line,
                location.column,
            });
            const slice = source.getLineSlice(location.line);
            try stderr.print("{s}", .{slice});
        },
    }
}

const Error = union(Code) {
    /// Index of invalid character
    invalid_character: u32,
    /// Index of opening quote
    mismatched_quotes: u32,
};

/// Error codes.  Numbers are subject to change until the compiler is more complete.
const Code = enum(u32) {
    // 1xx source file errors
    invalid_character = 100,
    mismatched_quotes = 101,
};

const std = @import("std");

const Source = @import("Source.zig");
