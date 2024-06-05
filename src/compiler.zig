pub fn compile(vm: *Vm, src: [:0]const u8, chunk: *Chunk) !u8 {
    var compiler = Compiler.init(vm, chunk);
    var parser = Parser.init(vm, &compiler, src);

    parser.advance();

    while (!parser.match(.eof)) {
        parser.declaration();
    }

    try parser.endCompiler();

    if (parser.had_error) return error.CompileError;

    return 0; // TODO: implement when functions work
}

const Compiler = struct {
    vm: *Vm,
    chunk: *Chunk,

    first_free_register: u8 = 0,

    fn init(vm: *Vm, chunk: *Chunk) Compiler {
        return Compiler{
            .vm = vm,
            .chunk = chunk,
        };
    }
};

const Precedence = enum {
    none,
    assignment, // =
    @"or", // or
    @"and", // and
    equality, // == !=
    comparison, // < > <= >=
    term, // + -
    factor, // * /
    unary, // ! -
    call, // . () []
    primary,

    fn next(precedence: Precedence) Precedence {
        return @enumFromInt(@intFromEnum(precedence) + 1);
    }
};

fn getPrecedence(tag: Token.Tag) Precedence {
    return switch (tag) {
        .l_paren, .r_paren, .l_brace, .r_brace, .comma, .dot => .none,
        .minus, .plus => .term,
        .semicolon => .none,
        .slash, .asterisk => .factor,
        .pipe => .none,

        .bang, .bang_equal, .equal => .none,
        .equal_equal => .equality,
        .angle_bracket_left, .angle_bracket_left_equal, .angle_bracket_right, .angle_bracket_right_equal => .comparison,

        .identifier,
        .string_literal,
        .number_literal,

        .keyword_and,
        .keyword_else,
        .keyword_false,
        .keyword_fn,
        .keyword_for,
        .keyword_if,
        .keyword_null,
        .keyword_or,
        .keyword_print,
        .keyword_return,
        .keyword_true,
        .keyword_let,
        .keyword_while,

        .eof,
        .invalid,
        => .none,
    };
}

const Parser = struct {
    vm: *Vm,
    compiler: *Compiler,

    scanner: Scanner,

    current: Token = undefined,
    previous: Token = undefined,

    had_error: bool = false,
    panic_mode: bool = false,

    pub fn init(vm: *Vm, compiler: *Compiler, src: [:0]const u8) Parser {
        return .{
            .vm = vm,
            .scanner = Scanner.init(src),
            .compiler = compiler,

            .current = undefined,
            .previous = undefined,

            .had_error = false,
            .panic_mode = false,
        };
    }

    pub fn advance(parser: *Parser) void {
        parser.previous = parser.current;

        while (true) {
            parser.current = parser.scanner.next();
            if (parser.current.tag != .invalid) break;
            parser.errAtCurrent(parser.current.value(parser.scanner.src));
        }
    }

    pub fn expression(parser: *Parser) anyerror!u8 {
        return try parser.parsePrecedence(.assignment);
    }

    fn expressionStatement(parser: *Parser) !void {
        _ = try parser.expression(); // TODO: return when functions work
        parser.consume(.semicolon, "Expect ';' after expression.");
    }

    fn printStatement(parser: *Parser) !void {
        const register = try parser.expression();
        parser.consume(.semicolon, "Expect ';' after value.");
        try parser.compiler.chunk.appendInstruction(
            parser.vm.gpa,
            .{ .print = register },
            parser.previous.line,
        );
    }

    fn synchronize(parser: *Parser) void {
        parser.panic_mode = false;

        while (parser.current.tag != .eof) {
            if (parser.previous.tag == .semicolon) return;
            switch (parser.current.tag) {
                .keyword_fn, .keyword_let, .keyword_if, .keyword_while, .keyword_print, .keyword_return => return,
                else => {},
            }

            parser.advance();
        }
    }

    pub fn declaration(parser: *Parser) !void {
        try parser.statement();

        if (parser.panic_mode) parser.synchronize();
    }

    pub fn statement(parser: *Parser) !void {
        if (parser.match(.keyword_print)) {
            try parser.printStatement();
        } else {
            try parser.expressionStatement();
        }
    }

    pub fn consume(parser: *Parser, tag: Token.Tag, msg: []const u8) void {
        if (parser.current.tag == tag) {
            parser.advance();
            return;
        }

        parser.errAtCurrent(msg);
    }

    pub fn match(parser: *Parser, tag: Token.Tag) bool {
        if (parser.current.tag != tag) return false;
        parser.advance();
        return true;
    }

    pub fn endCompiler(parser: *Parser) !void {
        try parser.compiler.chunk.appendInstruction(
            parser.vm.gpa,
            Instruction.ret,
            parser.previous.line,
        );
    }

    fn prefix(parser: *Parser, tag: Token.Tag, can_assign: bool) !u8 {
        _ = can_assign;
        return switch (tag) {
            .minus, .bang => try parser.unary(),
            .string_literal => try parser.string(),
            .number_literal => try parser.number(),
            .keyword_null => try parser.literal(),
            .l_paren => try parser.grouping(),
            else => unreachable,
        };
    }

    fn infix(parser: *Parser, tag: Token.Tag, can_assign: bool, lhs: u8) !u8 {
        _ = can_assign;
        return switch (tag) {
            .equal_equal,
            .angle_bracket_left,
            .angle_bracket_right,
            .angle_bracket_left_equal,
            .angle_bracket_right_equal,
            .plus,
            .minus,
            .slash,
            .asterisk,
            => parser.binary(lhs),

            else => unreachable,
        };
    }

    fn binary(parser: *Parser, lhs: u8) !u8 {
        const operator = parser.previous;
        const rhs = try parser.parsePrecedence(getPrecedence(operator.tag).next());

        var final_lhs = lhs;
        var final_rhs = rhs;

        if (operator.tag == .angle_bracket_right or operator.tag == .angle_bracket_right_equal) {
            final_lhs = rhs;
            final_rhs = lhs;
        }

        switch (operator.tag) {
            inline .plus,
            .minus,
            .slash,
            .asterisk,
            .equal_equal,
            .angle_bracket_left,
            .angle_bracket_left_equal,
            .angle_bracket_right,
            .angle_bracket_right_equal,
            => |tag| {
                const opcode = switch (tag) {
                    .plus => .add,
                    .minus => .sub,
                    .slash => .div,
                    .asterisk => .mul,
                    .equal_equal => .eq,
                    .angle_bracket_left, .angle_bracket_right => .lt,
                    .angle_bracket_left_equal, .angle_bracket_right_equal => .le,

                    else => unreachable,
                };

                try parser.compiler.chunk.appendInstruction(
                    parser.vm.gpa,
                    @unionInit(Instruction, @tagName(opcode), .{
                        .dest = parser.compiler.first_free_register,
                        .lhs = final_lhs,
                        .rhs = final_rhs,
                    }),
                    operator.line,
                );
            },
            else => unreachable,
        }

        parser.compiler.first_free_register += 1;
        return parser.compiler.first_free_register - 1;
    }

    fn literal(parser: *Parser) !u8 {
        const value = switch (parser.previous.tag) {
            .keyword_true, .keyword_false => try parser.compiler.chunk.addConstant(
                parser.vm.gpa,
                .{ .boolean = parser.previous.tag == .keyword_true },
            ),
            .keyword_null => try parser.compiler.chunk.addConstant(parser.vm.gpa, .{ .null = {} }),
            else => unreachable,
        };

        try parser.compiler.chunk.appendInstruction(
            parser.vm.gpa,
            .{
                .load = .{
                    .dest = parser.compiler.first_free_register,
                    .src = value,
                },
            },

            parser.previous.line,
        );

        parser.compiler.first_free_register += 1;
        return parser.compiler.first_free_register - 1;
    }

    fn grouping(parser: *Parser) !u8 {
        const result_register = try parser.expression();
        parser.consume(.r_paren, "Expect ')' after expression.");

        return result_register;
    }

    fn number(parser: *Parser) !u8 {
        const value = std.fmt.parseFloat(f64, parser.previous.value(parser.scanner.src)) catch unreachable;
        try parser.compiler.chunk.appendInstruction(
            parser.vm.gpa,
            .{
                .load = .{
                    .dest = parser.compiler.first_free_register,
                    .src = try parser.compiler.chunk.addConstant(parser.vm.gpa, .{ .float = value }),
                },
            },
            parser.previous.line,
        );
        parser.compiler.first_free_register += 1;
        return parser.compiler.first_free_register - 1;
    }

    fn string(parser: *Parser) !u8 {
        const value = Object.String.copy(parser.previous.value(parser.scanner.src));

        try parser.compiler.chunk.appendInstruction(
            parser.vm.gpa,
            .{
                .load = .{
                    .dest = parser.compiler.first_free_register,
                    .src = try parser.compiler.chunk.addConstant(value),
                },
            },
        );
        parser.compiler.first_free_register += 1;
        return parser.compiler.first_free_register - 1;
    }

    fn unary(parser: *Parser) !u8 {
        const token_tag = parser.previous.tag;

        const rhs = try parser.parsePrecedence(.unary);

        switch (token_tag) {
            .minus, .bang => try parser.compiler.chunk.appendInstruction(
                parser.vm.gpa,
                .{ .negate = .{
                    .dest = parser.compiler.first_free_register,
                    .src = rhs,
                } },
                parser.previous.line,
            ),
            else => unreachable,
        }

        parser.compiler.first_free_register += 1;
        return parser.compiler.first_free_register - 1;
    }

    fn parsePrecedence(parser: *Parser, precedence: Precedence) anyerror!u8 {
        parser.advance();
        const can_assign = false;

        var result = try parser.prefix(parser.previous.tag, can_assign);

        while (@intFromEnum(precedence) <= @intFromEnum(getPrecedence(parser.current.tag))) {
            parser.advance();
            result = try parser.infix(parser.previous.tag, can_assign, result);
        }

        return result;
    }

    fn errAtCurrent(parser: *Parser, msg: []const u8) void {
        parser.errAt(parser.current, msg);
    }

    fn err(parser: *Parser, msg: []const u8) void {
        parser.errAt(parser.previous, msg);
    }

    fn errAt(parser: *Parser, token: Token, msg: []const u8) void {
        if (parser.panic_mode) return;
        parser.panic_mode = true;

        std.log.err("{}: {s}", .{ token.fmtError(parser.scanner.src), msg });

        parser.had_error = true;
    }
};

const Object = @import("Object.zig");

const Scanner = @import("scanner.zig").Scanner;
const Token = @import("scanner.zig").Token;

const Instruction = @import("instruction.zig").Instruction;
const Chunk = @import("Chunk.zig");
const Vm = @import("Vm.zig");

const Flags = @import("main.zig").Flags;
const std = @import("std");
