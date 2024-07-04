pub fn print(allocator: std.mem.Allocator ) void {
    switch (self.error) {
        .invalid_character => {
        },
    }
}

/// Error codes
const Code = enum {
    // 1xx source file errors
    .invalid_character = 100,
};

const std = @import("std");

const Source = @import("Source.zig")
