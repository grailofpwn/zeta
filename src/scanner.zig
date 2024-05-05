//
pub const Token = struct {
    tag: Tag,
    loc: Loc,
    line: u32,

    const Loc = struct {
        start: u32,
        end: u32,
    };

    pub const keywords = std.ComptimeStringMap(Tag, .{
        .{ "and", .keyword_and },
        .{ "else", .keyword_else },
        .{ "false", .keyword_false },
        .{ "fn", .keyword_fn },
        .{ "for", .keyword_for },
        .{ "if", .keyword_if },
        .{ "null", .keywork_null },
        .{ "or", .keyword_or },
        .{ "print", .keyword_print },
        .{ "return", .keyword_return },
        .{ "true", .keyword_true },
        .{ "let", .keyword_let },
        .{ "while", .keyword_while },
    });

    pub const Tag = enum {
        l_paren,
        r_paren,
        l_brace,
        r_brace,
        comma,
        dot,
        minus,
        plus,
        semicolon,
        slash,
        asterisk,
        pipe,

        bang,
        bang_equal,
        equal,
        equal_equal,
        angle_bracket_left,
        angle_bracket_left_equal,
        angle_bracket_right,
        angle_bracket_right_equal,

        identifier,
        string_literal,
        number_literal,

        keyword_and,
        keyword_else,
        keyword_false,
        keyword_fn,
        keyword_for,
        keyword_if,
        keywork_null,
        keyword_or,
        keyword_print,
        keyword_return,
        keyword_true,
        keyword_let,
        keyword_while,

        eof,
        invalid,
    };

    pub fn fmtError(token: Token, src: []const u8) FmtError {
        return FmtError{
            .token = token,
            .src = src,
        };
    }

    pub const FmtError = struct {
        token: Token,
        src: []const u8,

        pub fn format(fmt_error: FmtError, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = fmt;
            _ = options;

            try writer.print("[line {d}] Error, ", .{fmt_error.token.line});
            if (fmt_error.token.tag == .eof) {
                try writer.print("at end", .{});
            } else {
                try writer.print("at '{s}'", .{
                    fmt_error.src[fmt_error.token.loc.start..fmt_error.token.loc.end],
                });
            }
        }
    };
};

pub const Scanner = struct {
    src: [:0]const u8,
    index: u32,
    line: u32,

    pub fn init(src: [:0]const u8) Scanner {
        // Skip the UTF-8 BOM if present
        const src_start: u32 = if (std.mem.startsWith(u8, src, "\xEF\xBB\xBF")) 3 else 0;
        return Scanner{
            .src = src,
            .index = src_start,
            .line = 1,
        };
    }

    pub fn dump(scanner: Scanner, token: Token) void {
        std.log.debug("{s} \"{s}\"", .{ @tagName(token.tag), scanner.src[token.loc.start..token.loc.end] });
    }

    const State = enum {
        start,
        bang,
        equal,
        angle_bracket_left,
        angle_bracket_right,
        slash,
        line_comment,
        identifier,
        string_literal,
        number_literal,
        number_literal_dot,
    };

    // TODO: implement properly - this is a mvp
    pub fn next(scanner: *Scanner) Token {
        var state: State = .start;

        var result = Token{
            .tag = .eof,
            .loc = .{
                .start = scanner.index,
                .end = undefined,
            },
            .line = scanner.line,
        };

        while (true) : (scanner.index += 1) {
            const c = scanner.src[scanner.index];
            switch (state) {
                .start => switch (c) {
                    0 => {
                        if (scanner.index != scanner.src.len) {
                            result.tag = .invalid;
                            result.loc.start = scanner.index;
                            scanner.index += 1;
                            result.loc.end = scanner.index;
                            return result;
                        }
                        break;
                    },
                    ' ', '\t', '\r' => result.loc.start = scanner.index + 1,
                    '\n' => {
                        scanner.line += 1;
                        result.loc.start = scanner.index + 1;
                    },
                    '!' => state = .bang,
                    '=' => state = .equal,
                    '<' => state = .angle_bracket_left,
                    '>' => state = .angle_bracket_right,
                    '/' => state = .slash,
                    'a'...'z', 'A'...'Z', '_' => state = .identifier,
                    '"' => state = .string_literal,
                    '0'...'9' => state = .number_literal,
                    '(' => {
                        result.tag = .l_paren;
                        scanner.index += 1;
                        break;
                    },
                    ')' => {
                        result.tag = .r_paren;
                        scanner.index += 1;
                        break;
                    },
                    '{' => {
                        result.tag = .l_brace;
                        scanner.index += 1;
                        break;
                    },
                    '}' => {
                        result.tag = .r_brace;
                        scanner.index += 1;
                        break;
                    },
                    ',' => {
                        result.tag = .comma;
                        scanner.index += 1;
                        break;
                    },
                    '.' => {
                        result.tag = .dot;
                        scanner.index += 1;
                        break;
                    },
                    '-' => {
                        result.tag = .minus;
                        scanner.index += 1;
                        break;
                    },
                    '+' => {
                        result.tag = .plus;
                        scanner.index += 1;
                        break;
                    },
                    ';' => {
                        result.tag = .semicolon;
                        scanner.index += 1;
                        break;
                    },
                    '*' => {
                        result.tag = .asterisk;
                        scanner.index += 1;
                        break;
                    },
                    '|' => {
                        result.tag = .pipe;
                        scanner.index += 1;
                        break;
                    },
                    else => {
                        result.tag = .invalid;
                        result.loc.end = scanner.index;
                        scanner.index += 1;
                        return result;
                    },
                },
                .bang => switch (c) {
                    '=' => {
                        result.tag = .bang_equal;
                        scanner.index += 1;
                        break;
                    },
                    else => {
                        result.tag = .bang;
                        break;
                    },
                },
                .equal => switch (c) {
                    '=' => {
                        result.tag = .equal_equal;
                        scanner.index += 1;
                        break;
                    },
                    else => {
                        result.tag = .equal;
                        break;
                    },
                },
                .angle_bracket_left => switch (c) {
                    '=' => {
                        result.tag = .angle_bracket_left_equal;
                        scanner.index += 1;
                        break;
                    },
                    else => {
                        result.tag = .angle_bracket_left;
                        break;
                    },
                },
                .angle_bracket_right => switch (c) {
                    '=' => {
                        result.tag = .angle_bracket_right_equal;
                        scanner.index += 1;
                        break;
                    },
                    else => {
                        result.tag = .angle_bracket_right;
                        break;
                    },
                },
                .slash => switch (c) {
                    '/' => state = .line_comment,
                    else => {
                        result.tag = .slash;
                        break;
                    },
                },
                .line_comment => switch (c) {
                    0 => {
                        if (scanner.index != scanner.src.len) {
                            result.tag = .invalid;
                            scanner.index += 1;
                        }
                        break;
                    },
                    '\n' => {
                        state = .start;
                        scanner.line += 1;
                    },
                    else => {},
                },
                .identifier => switch (c) {
                    'a'...'z', 'A'...'Z', '0'...'9', '_' => {},
                    else => {
                        const lexeme = scanner.src[result.loc.start..scanner.index];
                        result.tag = Token.keywords.get(lexeme) orelse .identifier;
                        break;
                    },
                },
                .string_literal => switch (c) {
                    0,
                    => {
                        result.tag = .invalid;
                        break;
                    },
                    '\n' => {
                        result.tag = .invalid;
                        scanner.line += 1;
                        break;
                    },
                    '"' => {
                        result.tag = .string_literal;
                        result.loc.start += 1;
                        result.loc.end = scanner.index;
                        scanner.index += 1;
                        return result;
                    },
                    else => {},
                },
                .number_literal => switch (c) {
                    '0'...'9' => {},
                    '.' => state = .number_literal_dot,
                    else => {
                        result.tag = .number_literal;
                        break;
                    },
                },
                .number_literal_dot => switch (c) {
                    '0'...'9' => {},
                    else => {
                        result.tag = .number_literal;
                        break;
                    },
                },
            }
        }

        if (result.tag == .eof) {
            result.loc.start = scanner.index;
        }

        result.loc.end = scanner.index;
        return result;
    }
};

const std = @import("std");
