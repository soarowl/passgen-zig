const std = @import("std");
const cli = @import("zig-cli");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var config = struct {
    length: u8 = 16,
    digits: u8 = 1,
    lowers: u8 = 1,
    punctuations: u8 = 1,
    uppers: u8 = 1,
    allDigits: bool = false,
    unique: bool = true,
}{};

var length = cli.Option{
    .long_name = "length",
    .help = "Maximum password length, default 16",
    .short_alias = 'l',
    .value_ref = cli.mkRef(&config.length),
};
var digits = cli.Option{
    .long_name = "digits",
    .help = "Minimum digits, default 1",
    .short_alias = 'd',
    .value_ref = cli.mkRef(&config.digits),
};
var lowers = cli.Option{
    .long_name = "lowers",
    .help = "Minimun lower case letters, default 1",
    .short_alias = 'w',
    .value_ref = cli.mkRef(&config.lowers),
};
var punctuations = cli.Option{
    .long_name = "punctuations",
    .help = "Minimun punctuations, default 1",
    .short_alias = 'p',
    .value_ref = cli.mkRef(&config.punctuations),
};
var uppers = cli.Option{
    .long_name = "uppers",
    .help = "Minimum upper case letters, default 1",
    .short_alias = 'u',
    .value_ref = cli.mkRef(&config.uppers),
};
var allDigits = cli.Option{
    .long_name = "DIGITS",
    .help = "Generate digital password, default false",
    .short_alias = 'D',
    .value_ref = cli.mkRef(&config.allDigits),
};
var unique = cli.Option{
    .long_name = "unique",
    .help = "Generate password with unique chars, default true",
    .short_alias = 'q',
    .value_ref = cli.mkRef(&config.unique),
};
var app = &cli.App{
    .author = "Zhuo Nengwen",
    .command = cli.Command{
        .name = "passgen",
        .options = &.{ &length, &digits, &lowers, &punctuations, &uppers, &allDigits, &unique },
        .target = cli.CommandTarget{
            .action = cli.CommandAction{ .exec = run_generate },
        },
    },
    .version = "0.0.1",
};

pub fn main() !void {
    defer std.debug.assert(gpa.deinit() == .ok);
    return cli.run(app, allocator);
}

fn run_generate() !void {
    if (config.allDigits) {
        config.digits = config.length;
        config.lowers = 0;
        config.punctuations = 0;
        config.uppers = 0;
    }

    if (config.digits > config.length) {
        std.debug.print("Minimun digits: {} greate than length: {}", .{ config.digits, config.length });
        return;
    }
    if (config.lowers > config.length) {
        std.debug.print("Minimun lower case letters: {} greate than length: {}", .{ config.lowers, config.length });
        return;
    }
    if (config.punctuations > config.length) {
        std.debug.print("Minimun punctuations: {} greate than length: {}", .{ config.punctuations, config.length });
        return;
    }
    if (config.uppers > config.length) {
        std.debug.print("Minimun upper case letters: {} greate than length: {}", .{ config.uppers, config.length });
        return;
    }
    if (config.unique) {
        if (config.digits > 10) {
            std.debug.print("Minimun digits: {} greate than 10", .{config.digits});
            return;
        }
        if (config.lowers > 26) {
            std.debug.print("Minimun lower case letters: {} greate than 26", .{config.lowers});
            return;
        }
        if (config.uppers > 26) {
            std.debug.print("Minimun upper case letters: {} greate than 26", .{config.uppers});
            return;
        }
    }

    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();

    while (true) {
        var buffer = try allocator.alloc(u8, config.length);
        defer allocator.free(buffer);
        var d: u8 = 0;
        var l: u8 = 0;
        var p: u8 = 0;
        var u: u8 = 0;
        var map = std.AutoHashMap(u8, bool).init(
            allocator,
        );
        defer map.deinit();

        for (0..config.length) |i| {
            while (true) {
                const b = rand.intRangeLessThan(u8, 33, 127);
                if (config.unique and map.contains(b)) continue;

                switch (b) {
                    '0'...'9' => {
                        if (config.digits == 0) continue;
                        d += 1;
                    },
                    'a'...'z' => {
                        if (config.lowers == 0) continue;
                        l += 1;
                    },
                    'A'...'Z' => {
                        if (config.uppers == 0) continue;
                        u += 1;
                    },
                    else => {
                        if (config.punctuations == 0) continue;
                        p += 1;
                    },
                }

                buffer[i] = b;
                if (config.unique) try map.put(b, true);
                break;
            }
        }

        if (config.digits == 0 and d > 0) continue;
        if (config.digits > 0 and d < config.digits) continue;
        if (config.lowers == 0 and l > 0) continue;
        if (config.lowers > 0 and l < config.lowers) continue;
        if (config.punctuations == 0 and p > 0) continue;
        if (config.punctuations > 0 and p < config.punctuations) continue;
        if (config.uppers == 0 and u > 0) continue;
        if (config.uppers > 0 and u < config.uppers) continue;

        std.debug.print("{s}\n", .{buffer});
        break;
    }
}
