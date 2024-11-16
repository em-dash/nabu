const Node = union(enum(u8)) {
    const null_index = std.math.maxInt(u32);

    /// A start and end, restricted to unsigned 32-bit integers.  Note that this is not a slice
    /// hence the name differentiates it.
    slicer: struct {
        start: u32,
        end: u32,
    },
    module_decl: struct {
        /// `slicer`
        name: u32,
        /// `module_functions`
        functions: u32,
    },
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
        modules_errors: u32,
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
    /// If `qualifier == .none`, `underlying` indexes an `identifier`, otherwise it indexes
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
    struct_decl: struct {
        name: u32,
        struct_body: u32,
    },
    struct_body: struct {
        /// `slicer` of `var_decl`
        struct_fields: u32,
        /// `slicer` of `function_decl`
        struct_functions: u32,
    },
    var_decl: struct {
        name: u32,
        type: u32,
    },
    error_decl: struct {
        name: u32,
        /// `slicer` over `slicer`s over source file
        members: u32,
    },
};

const TypeQualifier = enum {
    none,
    list,
    map,
    reference,
};

pub const Ast = struct {
    nodes: std.ArrayListUnmanaged(Node),

    fn addNode(self: *Ast, allocator: std.mem.Allocator) !u32 {
        try self.nodes.append(allocator, undefined);
        return @as(u32, @truncate(self.nodes.items.len)) - 1;
    }

    fn create(allocator: std.mem.Allocator) !*Ast {
        const result = try allocator.create(Ast);
        result.nodes = .{};

        return result;
    }

    pub fn destroy(self: *Ast, allocator: std.mem.Allocator) void {
        self.nodes.deinit(allocator);
    }
};

fn parseFn(
    allocator: std.mem.Allocator,
    tokens: []const tokenization.Token,
    i: *u32,
    ast: *Ast,
) !void {
    _ = i; // autofix
    _ = ast; // autofix
    _ = allocator; // autofix
    _ = tokens; // autofix
}

fn parseEnum(
    allocator: std.mem.Allocator,
    tokens: []const tokenization.Token,
    i: *u32,
    ast: *Ast,
) !void {
    _ = i; // autofix
    _ = ast; // autofix
    _ = allocator; // autofix
    _ = tokens; // autofix
}

fn parseInterface(
    allocator: std.mem.Allocator,
    tokens: []const tokenization.Token,
    i: *u32,
    ast: *Ast,
) !void {
    _ = i; // autofix
    _ = ast; // autofix
    _ = allocator; // autofix
    _ = tokens; // autofix
}

fn parseStruct(
    allocator: std.mem.Allocator,
    tokens: []const tokenization.Token,
    i: *u32,
    ast: *Ast,
) !void {
    _ = i; // autofix
    _ = ast; // autofix
    _ = allocator; // autofix
    _ = tokens; // autofix
}

fn parseVar(
    allocator: std.mem.Allocator,
    tokens: []const tokenization.Token,
    i: *u32,
    ast: *Ast,
) !void {
    _ = i; // autofix
    _ = ast; // autofix
    _ = allocator; // autofix
    _ = tokens; // autofix
}

fn parseModule(
    allocator: std.mem.Allocator,
    tokens: []const tokenization.Token,
    i: *u32,
    ast: *Ast,
) !void {
    _ = allocator; // autofix
    _ = tokens; // autofix
    _ = i; // autofix
    _ = ast; // autofix
    // while (true) {
    //     switch (tokens[i.*].tag) {
    //         .keyword_fn => try parseFn(allocator, tokens, i, ast),
    //         .keyword_enum => try parseEnum(allocator, tokens, i, ast),
    //         .keyword_interface => try parseInterface(allocator, tokens, i, ast),
    //         .keyword_struct => try parseStruct(allocator, tokens, i, ast),
    //         .keyword_module => try parseModule(allocator, tokens, i, ast),
    //         .keyword_error => try parseError(allocator, tokens, i, ast),
    //         .identifier => try parseVar(allocator, tokens, i, ast),
    //         else => return error.ExpectedDecl,
    //     }
    // }
}

fn parseError(
    allocator: std.mem.Allocator,
    tokens: []const tokenization.Token,
    i: *u32,
    ast: *Ast,
) !void {
    _ = i; // autofix
    _ = ast; // autofix
    _ = allocator; // autofix
    _ = tokens; // autofix
}

/// Helper function to dedupe code between `parse()` and `parseModule()`.  The name `slicer`, as
/// well as the content-holding `functions`, `enums`, etc are left undefined.
fn constructModuleTree(allocator: std.mem.Allocator, ast: *Ast) !u32 {
    const decl = try ast.addNode(allocator);
    const functions = try ast.addNode(allocator);
    ast.nodes.items[decl] = .{ .module_decl = .{
        .slicer = undefined,
        .functions = functions,
    } };
    const enums = try ast.addNode(allocator);
    ast.nodes.items[functions] = .{ .module_functions = .{
        .functions = undefined,
        .enums = enums,
    } };
    const interfaces = try ast.addNode(allocator);
    ast.nodes.items[enums] = .{ .module_enums = .{
        .enums = undefined,
        .interfaces = interfaces,
    } };
    const structs = try ast.addNode(allocator);
    ast.nodes.items[interfaces] = .{ .module_interfaces = .{
        .interfaces = undefined,
        .structs = structs,
    } };
    const vars = try ast.addNode(allocator);
    ast.nodes.items[structs] = .{ .module_structs = .{
        .structs = undefined,
        .vars = vars,
    } };
    const modules_errors = try ast.addNode(allocator);
    ast.nodes.items[vars] = .{ .module_vars = .{
        .vars = undefined,
        .modules_errors = modules_errors,
    } };
    ast.nodes.items[modules_errors] = .{ .module_modules_errors = .{
        .modules = undefined,
        .errors = undefined,
    } };

    return decl;
}

// ModuleMembers <- (FunctionDecl / EnumDecl / InterfaceDecl / StructDecl / VarDecl
//     / ModuleDecl / ErrorDecl)*
//
// The file is treated as a module.  We just make its name length zero.
pub fn parse(allocator: std.mem.Allocator, tokens: []const tokenization.Token) !*Ast {
    var i: u32 = 0;
    const ast = try allocator.create(Ast);

    const root = try constructModuleTree(allocator, ast);
    _ = root; // autofix

    // functions
    const functions = std.ArrayListUnmanaged(u32);
    _ = functions; // autofix
    // enums
    const enums = std.ArrayListUnmanaged(u32);
    _ = enums; // autofix
    // interfaces
    const interfaces = std.ArrayListUnmanaged(u32);
    _ = interfaces; // autofix
    // structs
    const structs = std.ArrayListUnmanaged(u32);
    _ = structs; // autofix
    // vars
    const vars = std.ArrayListUnmanaged(u32);
    _ = vars; // autofix
    // modules
    const modules = std.ArrayListUnmanaged(u32);
    _ = modules; // autofix
    // errors
    const errors = std.ArrayListUnmanaged(u32);
    _ = errors; // autofix

    while (true) {
        switch (tokens[i].tag) {}
    }

    // while (true) {
    //     switch (tokens[i].tag) {
    //         .keyword_fn => try parseFn(allocator, tokens, &i, ast),
    //         .keyword_enum => try parseEnum(allocator, tokens, &i, ast),
    //         .keyword_interface => try parseInterface(allocator, tokens, &i, ast),
    //         .keyword_struct => try parseStruct(allocator, tokens, &i, ast),
    //         .keyword_module => try parseModule(allocator, tokens, &i, ast),
    //         .keyword_error => try parseError(allocator, tokens, &i, ast),
    //         .identifier => try parseVar(allocator, tokens, &i, ast),
    //         else => return error.ExpectedDecl,
    //     }
    // }

    return parseModule(allocator, tokens, &i, ast);
}

const std = @import("std");

const tokenization = @import("tokenization.zig");
