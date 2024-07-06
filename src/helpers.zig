pub const CompilationStage = enum {
    tokenization,
    ast,
    ast_check,
    cfir,
    oir,
    code_gen,
    full,
};

pub const CompileOptions = struct {
    target_stage: CompilationStage = .full,
    filename: []const u8 = &[_]u8{},
    debug_tokens: bool = false,
};
