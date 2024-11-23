const null_index = @as(u32, std.math.maxInt(u32));

// With notes on the `parse_payload` in `Ast`
const GrammarError = error{
    UnexpectedEof,
    UnexpectedToken,
};
const ParseError = GrammarError || std.mem.Allocator.Error;

const Node = union(enum(u8)) {
    /// A start and end, restricted to unsigned 32-bit integers.  Note that this is not a slice
    /// hence the name differentiates it.
    span: struct {
        start: u32,
        end: u32,
    },
    module_decl: struct {
        /// Token index
        identifier: u32,
        members: u32,
    },
    module_member: struct {
        member: u32,
        next: u32,
    },
    fn_decl: struct {
        fn_id_params: u32,
        fn_rtype_block: u32,
    },
    fn_id_params: struct {
        /// Token index
        token: u32,
        params: u32,
    },
    fn_param: struct {
        // `decl_param`
        param: u32,
        next: u32,
    },
    decl_param: struct {
        /// Token index
        identifier: u32,
        type: u32,
    },
    fn_rtype_block: struct {
        error_union: u32,
        block: u32,
    },
    block: struct {},
    // type: struct {
    //     type: u32,
    //     qualifier: enum(u32) { none, list, map, reference },
    // },
    type: union(enum(u32)) {
        none: u32,
        list: u32,
        map: u32,
        reference: u32,
    },
    scoped_identifier: struct {
        identifier: u32,
        next: u32,
    },
    error_union: struct {
        @"error": u32,
        type: u32,
    },
    @"error": union(enum(u32)) {
        none,
        name: u32,
        anon: u32,
    },
    // @"error": struct {
    //     // name: u32,
    //     // members: u32,

    // },
    error_member: struct {
        identifier: u32,
        next: u32,
    },

    // enum_decl: struct {
    //     /// Token index
    //     identifier: u32,
    //     /// `span` of `identifier`
    //     enum_members: u32,
    // },
    // interface_decl: struct {},
    // struct_decl: struct {
    //     /// Token index
    //     identifier: u32,
    //     struct_body: u32,
    // },
    // struct_body: struct {},
    // var_decl: struct {},
    // error_decl: struct {},
};

pub const Ast = struct {
    nodes: std.ArrayListUnmanaged(Node),
    allocator: std.mem.Allocator,
    i: u32,
    // Externally owned
    tokens: []const tokenization.Token,
    error_payload: ?*const tokenization.Token = null,

    inline fn peek(self: *Ast) u32 {
        if (self.i < self.tokens.len) return self.i else return null_index;
    }

    inline fn pop(self: *Ast) u32 {
        const result = self.i;
        self.i += 1;
        if (result < self.tokens.len) return result else return null_index;
    }

    fn addNode(self: *Ast) !u32 {
        try self.nodes.append(self.allocator, undefined);
        return @as(u32, @truncate(self.nodes.items.len)) - 1;
    }

    fn create(allocator: std.mem.Allocator, tokens: []const tokenization.Token) !*Ast {
        const result = try allocator.create(Ast);
        result.* = .{
            .nodes = .{},
            .allocator = allocator,
            .i = 0,
            .tokens = tokens,
        };

        return result;
    }

    pub fn destroy(self: *Ast) void {
        self.nodes.deinit(self.allocator);
    }
};

fn expectToken(ast: *Ast, expect: tokenization.Tag) ParseError!void {
    const token = ast.pop();
    if (ast.tokens[token].tag != expect) {
        ast.error_payload = &ast.tokens[token];
        return error.UnexpectedToken;
    }
}

fn parseScopedIdentifier(ast: *Ast) ParseError!u32 {
    const root = try ast.addNode();
    ast.nodes.items[root] = .{ .scoped_identifier = .{
        .identifier = ast.pop(),
        .next = null_index,
    } };

    var current = root;

    while (ast.tokens[ast.peek()].tag == .dot) {
        _ = ast.pop();
        ast.nodes.items[current].scoped_identifier.next = try ast.addNode();
        current = ast.nodes.items[current].scoped_identifier.next;
        const token = ast.pop();
        if (ast.tokens[token].tag != .identifier) {
            ast.error_payload = &ast.tokens[token];
            return error.UnexpectedToken;
        }
        ast.nodes.items[current].scoped_identifier.identifier = token;
        ast.nodes.items[current].scoped_identifier.next = null_index;
    }

    return root;
}

fn parseType(ast: *Ast) ParseError!u32 {
    const node = try ast.addNode();

    const first_token = ast.pop();
    switch (ast.tokens[first_token].tag) {
        .l_bracket => {
            ast.nodes.items[node] = .{ .type = .{
                .list = try parseType(ast),
            } };

            try expectToken(ast, .l_bracket);
        },
        .l_brace => {
            std.debug.panic("not implemented", .{});
        },
        .asterisk => {
            ast.nodes.items[node] = .{ .type = .{
                .reference = try parseType(ast),
            } };
        },
        .identifier => {
            ast.nodes.items[node] = .{ .type = .{
                .none = try parseType(ast),
            } };
        },
        else => {
            ast.error_payload = &ast.tokens[first_token];
            return error.UnexpectedToken;
        },
    }

    return node;
}

fn parseFnArgs(ast: *Ast) ParseError!u32 {
    var root_node = null_index;
    var current_node = null_index;

    while (ast.tokens[ast.peek()].tag != .r_paren) {
        const node = try ast.addNode();
        ast.nodes.items[node] = .{ .decl_param = .{
            .identifier = ast.pop(),
            .type = undefined,
        } };
        if (ast.tokens[ast.nodes.items[node].decl_param.identifier].tag != .identifier) {
            ast.error_payload = &ast.tokens[ast.nodes.items[node].decl_param.identifier];
            return error.UnexpectedToken;
        }

        try expectToken(ast, .colon);

        ast.nodes.items[node].decl_param.type = try parseType(ast);

        if (current_node == null_index) {
            root_node = try ast.addNode();
            current_node = root_node;
            ast.nodes.items[current_node] = .{ .fn_param = .{
                .param = node,
                .next = null_index,
            } };
        } else {
            ast.nodes.items[current_node].fn_param.next = try ast.addNode();
            current_node = ast.nodes.items[current_node].fn_param.next;
            ast.nodes.items[current_node] = .{ .fn_param = .{
                .param = node,
                .next = null_index,
            } };
        }
    }

    // Consume ending `r_paren`
    _ = ast.pop();
    return root_node;
}

fn parseErrorUnion(ast: *Ast) ParseError!u32 {
    // error_union: struct {
    //     @"error": u32,
    //     type: u32,
    // },
    // @"error": union(enum(u32)) {
    //     none,
    //     name: u32,
    //     anon: u32,
    // },
    // error_member: struct {
    //     identifier: u32,
    //     next: u32,
    // },

    const error_union = try ast.addNode();

    switch (ast.tokens[ast.peek()].tag) {
        .asterisk, .l_bracket, .l_brace => {
            ast.nodes.items[error_union] = .{ .error_union = .{
                .@"error" = try parseType(ast),
                .type = null_index,
            } };
        },
        .octothorpe => {
            _ = ast.pop();
            ast.nodes.items[error_union] = .{ .error_union = .{
                .@"error" = null_index,
                .type = try parseType(ast),
            } };
        },
        .identifier => {
            const first = try parseScopedIdentifier(ast);
            _ = first; // autofix
            if (ast.tokens[ast.peek()].tag == .octothorpe) {
                _ = ast.pop();
                const second = try parseScopedIdentifier(ast);
                _ = second; // autofix
            }
        },
        else => {
            ast.error_payload = &ast.tokens[ast.peek()];
            return error.UnexpectedToken;
        },
    }

    return error_union;
}

fn parseFn(ast: *Ast) ParseError!u32 {
    // Construct things
    const root = try ast.addNode();
    const fn_id_params = try ast.addNode();
    const fn_rtype_block = try ast.addNode();
    ast.nodes.items[root] = .{ .fn_decl = .{
        .fn_id_params = fn_id_params,
        .fn_rtype_block = fn_rtype_block,
    } };
    ast.nodes.items[fn_id_params] = .{ .fn_id_params = .{
        .token = undefined,
        .params = null_index,
    } };
    ast.nodes.items[fn_rtype_block] = .{ .fn_rtype_block = .{
        .error_union = undefined,
        .block = undefined,
    } };

    const name = ast.pop();
    ast.nodes.items[fn_id_params].fn_id_params.token = name;
    if (ast.tokens[name].tag != .identifier) {
        ast.error_payload = &ast.tokens[name];
        return error.UnexpectedToken;
    }

    try expectToken(ast, .l_paren);
    ast.nodes.items[fn_id_params].fn_id_params.params = try parseFnArgs(ast);

    ast.nodes.items[fn_rtype_block].fn_rtype_block.error_union = try parseErrorUnion(ast);

    // fn_decl: struct {
    //     fn_id_params: u32,
    //     fn_rtype_block: u32,
    // },
    // fn_id_params: struct {
    //     /// Token index
    //     token: u32,
    //     params: u32,
    // },
    // fn_param: struct {
    //     // `decl_param`
    //     param: u32,
    //     next: u32,
    // },
    // decl_param: struct {
    //     /// Token index
    //     identifier: u32,
    //     type: u32,
    // },
    // fn_rtype_block: struct {
    //     type: u32,
    //     block: u32,
    // },
    // block: struct {},
    // /// If `qualifier == .none`, `underlying` indexes an `identifier`, otherwise it indexes
    // /// another `type`
    // type: struct {
    //     // `scoped_identifier`
    //     underlying: u32,
    //     qualifier: enum(u32) { none, list, map, reference },
    // },

    return 0xAAAAAAAA;
}

// ModuleMembers <- (FunctionDecl / EnumDecl / InterfaceDecl / StructDecl / VarDecl
//     / ModuleDecl / ErrorDecl)*
fn parseModuleMembers(
    ast: *Ast,
    mode: enum { module, file },
) ParseError!u32 {
    // Checking for an empty container makes the rest easier.
    if (mode == .module and ast.tokens[ast.peek()].tag == .r_brace) {
        _ = ast.pop();
        return null_index;
    }

    if (mode == .file and ast.peek() == null_index) {
        return null_index;
    }

    // module_member: struct {
    //     member: u32,
    //     next: u32,
    // },

    var root_index = null_index;

    while (true) switch (ast.tokens[ast.pop()].tag) {
        .r_brace => {
            return root_index;
        },
        .keyword_fn => {
            const function = try parseFn(ast);
            root_index = try ast.addNode();
            ast.nodes.items[root_index] = .{ .module_member = .{
                .member = function,
                .next = null_index,
            } };
        },
        else => std.debug.panic("bad input and/or thing not implemented", .{}),
    };
}

pub fn parse(allocator: std.mem.Allocator, tokens: []const tokenization.Token) ParseError!*Ast {
    const ast = try Ast.create(allocator, tokens);

    const idk = try parseModuleMembers(ast, .file);
    _ = idk; // autofix

    return ast;
}

const std = @import("std");

const tokenization = @import("tokenization.zig");
