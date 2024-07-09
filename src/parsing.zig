const Node = union(enum) {
    // Items with start and end are slicing over Ast.nodes unless otherwise specified
    module: struct {
        start: u32,
        end: u32,
    },
    function_decl: struct {
        /// `function_head`
        head: u32,
        /// `function_arguments`
        arguments: u32,
    },
    /// Slice of text location in source file
    identifier: struct {
        start: u32,
        end: u32,
    },
    function_arguments: struct {
        start: u32,
        end: u32,
    },
    function_head: struct {
        name: u32,
        generic_identifier: u32,
    },
};

pub const Ast = struct {
    nodes: []Node,

    pub fn deinit() void {}
};

pub fn parse() !Ast {
    return error.lmao;
}

const std = @import("std");

const tokenization = @import("tokenization.zig");
