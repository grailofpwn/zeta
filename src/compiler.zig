pub fn compile(src: [:0]const u8) !void {
    var scanner = Scanner.init(src);

    while (true) {
        const token = scanner.next();
        scanner.dump(token);

        if (token.tag == .eof) break;
    }
}

const Scanner = @import("scanner.zig").Scanner;
const Token = @import("scanner.zig").Token;
