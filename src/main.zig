const CliArgs = struct {
    filename: []const u8 = &[_]u8{},
    tokenize_only: bool = false,
    parse_only: bool = false,
};

fn processArgs(allocator: std.mem.Allocator) !CliArgs {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    var seen_filename = false;
    var result: CliArgs = .{};
    while (args.next()) |arg| {
        if (arg[0] == '-') {
            if (arg[1] == '-') { // Long arguments
                if (std.mem.eql(u8, arg[2..], "tokenize-only"))
                    result.tokenize_only = true
                else if (std.mem.eql(u8, arg[2..], "parse-only"))
                    result.parse_only = true;
            } else { // Short arguments

            }
        } else { // This should be the filename.
            if (seen_filename) return error.InvalidArgument;

            result.filename = try allocator.dupe(u8, arg);
            errdefer allocator.free(result.filename);
            seen_filename = true;
        }
    }

    return result;
}

fn compileAndRun(options: helpers.CompileOptions) !void {
    _ = options;
}

pub fn main() !void {
    std.log.debug("version: TODO get the version from the build system somehow", .{});
    std.log.debug("zig version: {s}", .{builtin.zig_version_string});

    var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = gpa_instance.allocator();

    const args = try processArgs(gpa);
    defer gpa.free(args.filename);

    const compile_options = blk: {
        var result: helpers.CompileOptions;
        result.filename = args.filename;
        if (args.tokenize_only) result.target_stage = .tokenization;
        if (args.parse_only) result.target_stage = .ast;

        break :blk result;
    };
    try compileAndRun(compile_options);
}

test {
    _ = @import("Source.zig");
    // _ = @import("Tokenizer.zig");
    // _ = @import("ast.zig");
    _ = @import("types.zig");
    _ = @import("bytecode.zig");
    _ = @import("runtime.zig");
}

const std = @import("std");
const builtin = @import("builtin");
const helpers = @import("helpers.zig");
