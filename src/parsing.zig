const Node = union(enum) {
    // Items with start and end are slicing over Ast.nodes unless otherwise specified.  Doc comments
    // with just an identifier show the type that an index points to.

    /// A start and end, restricted to unsigned 32-bit integers.  Note that this is start and end,
    /// not start and length.
    slicer: struct {
        start: u32,
        end: u32,
    },
    module: struct {
        /// `slicer`
        name: u32,
        /// `module_functions`
        functions: u32,
    },
    // and so on
    module_functions: struct {
        functions: u32,
        enums: u32,
    },
    module_enums: struct {
        enums: u32,
        interfaces: u32,
    },
    module_interfaces: struct {
        interfaces: u32,
        structs: u32,
    },
    module_structs: struct {
        structs: u32,
        vars: u32,
    },
    module_vars: struct {
        vars: u32,
        modules: u32,
    },
    module_modules_errors: struct {
        modules: u32,
        errors: u32,
    },
    function_decl: struct {
        signature: u32,
        /// `block`
        body: u32,
    },
    function_signature: struct {
        identifiers: u32,
        /// `slicer` of `decl_param`
        arguments: u32,
    },
    function_identifiers: struct {
        /// `slicer` over source file
        name: u32,
        /// `slicer` over source file
        generic: u32,
    },
    decl_param: struct {
        /// `slicer` over source file
        name: u32,
        /// `type`
        type: u32,
    },
    /// If `qualifier == .none`, underlying indexes an `identifier`, otherwise it indexes
    /// another `type`
    type: struct {
        underlying: u32,
        qualifier: TypeQualifier,
    },
    enum_decl: struct {
        /// `slicer` over source file
        name: u32,
        /// `slicer` of `slicer`s over source file
        enum_members: u32,
    },
    interface_decl: struct {
        /// `slicer` of `function`
        functions: u32,
        /// `slicer` of `signature`
        signatures: u32,
    },
    // struct_decl,
    // var_decl,
    // module_decl,
    // error_decl,
};

const TypeQualifier = enum {
    none,
    list,
    map,
    reference,
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
