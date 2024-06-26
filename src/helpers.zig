const CompilationStage = enum {
    tokenization,
    ast,
    ast_check,
    cfir,
    oir,
    code_gen,
    full,
};

const CompileOptions = struct {
    target_stage: CompilationStage = .full,
    filename: []const u8 = &[_]u8{},
};
