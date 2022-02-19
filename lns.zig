const std = @import("std");
const testing = std.testing;
const expectEqual = testing.expectEqual;
const expect = testing.expect;

fn pow(base: anytype, exp: anytype) @TypeOf(base, exp) {
    return @exp(@log(base)*exp);
}

fn clamp(comptime T: type, x: anytype) @TypeOf(x) {
    const m = @intToFloat(@TypeOf(x), std.math.minInt(T));
    const M = @intToFloat(@TypeOf(x), std.math.maxInt(T));
    if (x < m) {
        return m;
    } else if (x > M) {
        return M;
    } else {
        return x;
    }
}

pub fn l16(comptime fractional_bits: u4) type {
    const C = @exp2(@intToFloat(f64, fractional_bits));

    const l1p_table = blk: {
        const N = 1+@intCast(usize, -@intCast(i16, std.math.minInt(i15)));
        @setEvalBranchQuota(N*20);
        comptime var table: [N]i15 = undefined;
        const base = @exp2(1/C);
        comptime for (table) |*x,i| {
            const exp = @intToFloat(f64, @intCast(i15, -@intCast(i16, i)));
            const result = @log2(1+pow(base, exp)) * C;
            x.* = @floatToInt(i15, std.math.round(clamp(i15, result)));
        };
        break :blk table;
    };

    const l1m_table = blk: {
        const N = 1+@intCast(usize, -@intCast(i16, std.math.minInt(i15)));
        @setEvalBranchQuota(N*20);
        comptime var table: [N]i15 = undefined;
        const base = @exp2(1/C);
        comptime for (table) |*x,i| {
            if (i == 0) {
                x.* = std.math.minInt(i15);
            } else {
                const exp = @intToFloat(f64, @intCast(i15, -@intCast(i16, i)));
                const result = @log2(1-pow(base, exp)) * C;
                x.* = @floatToInt(i15, std.math.round(clamp(i15, result)));
            }
        };
        break :blk table;
    };

    return packed struct {
        sign: u1,
        log: i15,

        pub fn add(self: @This(), other: @This()) @This() {
            const sign = if (self.log > other.log) self.sign else other.sign;
            const left = if (self.log > other.log) self.log else other.log;
            const diff = if (self.log > other.log) other.log -| self.log else self.log -| other.log;
            const idx = @intCast(usize, -@intCast(i16, diff));
            const right = if (sign == 1) l1m_table[idx] else l1p_table[idx];
            return .{
                .sign = sign,
                .log = left +| right,
            };
        }

        pub fn neg(self: @This()) @This() {
            return .{
                .sign = 1-self.sign,
                .log = self.log,
            };
        }

        pub fn sub(self: @This(), other: @This()) @This() {
            return self.add(other.neg());
        }

        pub fn inv(self: @This()) @This() {
            return .{
                .sign = self.sign,
                .log = -self.log,
            };
        }

        pub fn mul(self: @This(), other: @This()) @This() {
            return .{
                .sign = self.sign ^ other.sign,
                .log = self.log +| other.log,
            };
        }

        pub fn div(self: @This(), other: @This()) @This() {
            return self.mul(other.inv());
        }

        pub fn from(x: anytype) @This() {
            if (x == 0) {
                return .{
                    .sign = 0,
                    .log = std.math.minInt(i15),
                };
            }
            const F = switch(@typeInfo(@TypeOf(x))) {
                .Float => x,
                .Int => @intToFloat(f64, x),
                .ComptimeFloat => @floatCast(f64, x),
                .ComptimeInt => @intToFloat(f64, x),
                else => @compileError("Only numeric types supported"),
            };
            const L = @log2(@fabs(F)) * C;
            return .{
                .sign = if (F < 0) 1 else 0,
                .log = @floatToInt(i15, std.math.round(clamp(i15, L))),
            };
        }

        pub fn to(self: @This(), comptime T: type) T {
            if (self.log == std.math.minInt(i15))
                return @as(T, 0);
            const L = @intToFloat(f64, self.log) / C;
            const sign = 1-2*@intToFloat(f64, self.sign);
            const full = @exp2(L) * sign;
            return switch(@typeInfo(T)) {
                .Float => @floatCast(T, full),
                .Int => @floatToInt(T, std.math.round(full)),
                .ComptimeFloat => @floatCast(comptime_float, full),
                .ComptimeInt => @floatToInt(T, std.math.round(full)),
                else => @compileError("Only numeric types supported"),
            };
        }

        pub fn eql(self: @This(), other: @This()) bool {
            return (self.log == other.log and self.log == std.math.minInt(i15))
            or (self.sign == other.sign and self.log == other.log);
        }
    };
}


test "no fractional bits" {
    const N = l16(0);

    var tests: [5]N = .{
        N.from(0),
        N.from(-1),
        N.from(1),
        N.from(3.8),
        N.from(@as(f32, 134.897)),
    };

    for (tests) |x|
        try expectEqual(x.to(f32), N.from(x.to(f32)).to(f32));
}

test "all fractional bits" {
    const N = l16(14);

    var tests: [5]N = .{
        N.from(0),
        N.from(-1),
        N.from(1),
        N.from(3.8),
        N.from(@as(f32, 134.897)),
    };

    for (tests) |x|
        try expectEqual(x.to(f32), N.from(x.to(f32)).to(f32));
    try expectEqual(N.from(3.14).to(f32), N.from(3).add(N.from(0.14)).to(f32));
    try expect(N.from(7.8).eql(N.from(1).add(N.from(6.8))));
}

test "moderately sized" {
    const N = l16(7);

    var tests: [5]N = .{
        N.from(0),
        N.from(-1),
        N.from(1),
        N.from(3.8),
        N.from(@as(f32, 134.897)),
    };

    for (tests) |x|
        try expectEqual(x.to(f32), N.from(x.to(f32)).to(f32));
    try expectEqual(N.from(3.14).to(f32), N.from(3).add(N.from(0.14)).to(f32));
    try expect(N.from(7.8).eql(N.from(1).add(N.from(6.8))));
}
