const w4 = @import("wasm4.zig");
const map = @import("map.zig");
const std = @import("std");

const smiley = [8]u8{
    0b11000011,
    0b10000001,
    0b00100100,
    0b00100100,
    0b00000000,
    0b00100100,
    0b10011001,
    0b11000011,
};

var offsetY: i32 = 0;
var positionX: i32 = 80;
var positionY: i32 = 80;

var targetX: i32 = undefined;
var targetY: i32 = undefined;
var targetOffsetY: i32 = undefined;

const City = struct {
    name: []const u8,
    x: i32,
    y: i32,
};

const cities = [_]City{
    City{ .name = "Ha Noi", .x = 93, .y = 51 },
    City{ .name = "Saigon", .x = 101, .y = 281 },
    City{ .name = "Haiphong", .x = 99, .y = 55 },
    City{ .name = "Nam Dinh", .x = 88, .y = 65 },
    City{ .name = "Thanh Hoa", .x = 81, .y = 80 },
    City{ .name = "Vinh", .x = 76, .y = 109 },
    City{ .name = "Hue", .x = 110, .y = 151 },
    City{ .name = "Da Nang", .x = 127, .y = 166 },
    City{ .name = "Quy Nhon", .x = 152, .y = 218 },
    City{ .name = "Tuy Hoa", .x = 154, .y = 234 },
    City{ .name = "Nha Trang", .x = 153, .y = 252 },
    City{ .name = "Da Lat", .x = 137, .y = 257 },
};

const Mode = enum {
    start,
    select,
    selected,
    end,
};

var mode = Mode.start;
var previous_gamepad: u8 = 0;
var score: f32 = 0;
const isDebug = false;
const RndGen = std.rand.DefaultPrng;
var rnd: std.rand.Xoshiro256 = undefined;
var city: City = cities[0];
var count: u8 = 1;
const maxRounds: u8 = 3;
var frameCount: u64 = 0;

export fn start() void {
    city = cities[@mod(rnd.random().int(usize), cities.len)];
}

export fn update() void {
    var buffer: [1000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    w4.DRAW_COLORS.* = 2;
    const gamepad = w4.GAMEPAD1.*;

    if (mode == Mode.select) {
        if ((gamepad & w4.BUTTON_DOWN != 0) and positionY == 160) {
            offsetY = @min(map.vn_new_height - 160, offsetY + 1);
        }

        if (gamepad & w4.BUTTON_UP != 0 and positionY == 0) {
            offsetY = @max(0, offsetY - 1);
        }

        if (gamepad & w4.BUTTON_DOWN != 0) {
            positionY = @min(160, positionY + 1);
        }

        if (gamepad & w4.BUTTON_UP != 0) {
            positionY = @max(0, positionY - 1);
        }

        if (gamepad & w4.BUTTON_LEFT != 0) {
            positionX = @max(0, positionX - 1);
        }

        if (gamepad & w4.BUTTON_RIGHT != 0) {
            positionX = @min(160, positionX + 1);
        }
    } else if (mode == Mode.selected) {
        if (gamepad & w4.BUTTON_DOWN != 0) {
            offsetY = @min(map.vn_new_height - 160, offsetY + 1);
        }

        if (gamepad & w4.BUTTON_UP != 0) {
            offsetY = @max(0, offsetY - 1);
        }
    }

    const pressed_this_frame = gamepad & (gamepad ^ previous_gamepad);
    previous_gamepad = gamepad;

    const distance = std.math.sqrt(@intToFloat(f32, std.math.pow(i32, targetX - city.x, 2) + std.math.pow(i32, targetY + targetOffsetY - city.y, 2))) * (1800 / map.vn_new_height);
    if (pressed_this_frame & w4.BUTTON_1 != 0) {
        if (mode == Mode.select) {
            mode = Mode.selected;
            score += distance;
            targetX = positionX;
            targetY = positionY;
            targetOffsetY = offsetY;
        } else if (mode == Mode.selected) {
            mode = Mode.select;
            count += 1;
            city = cities[@mod(rnd.random().int(usize), cities.len)];
            if (count > maxRounds) {
                mode = Mode.end;
            }
        } else if (mode == Mode.end) {
            mode = Mode.select;
            city = cities[@mod(rnd.random().int(usize), cities.len)];
            count = 1;
            score = 0;
        } else if (mode == Mode.start) {
            mode = Mode.select;
            rnd = RndGen.init(frameCount);
            city = cities[@mod(rnd.random().int(usize), cities.len)];
        }
    }

    w4.blitSub(&map.vn_new, 0, 0, map.vn_new_width, 160, 0, @intCast(u32, offsetY), map.vn_new_width, w4.BLIT_1BPP);
    w4.DRAW_COLORS.* = 0x30;

    if (mode == Mode.select) {
        w4.oval(positionX - 4, positionY - 4, 8, 8);
    }

    w4.DRAW_COLORS.* = 0x04;

    if (mode == Mode.start) {
        w4.text("Vietnam", 55, 30);
        w4.text("Geo Guesser", 40, 40);
        w4.text("Press \x80 to Start", 20, 70);
        frameCount += 1;
    }

    if (isDebug) {
        const debug = std.fmt.allocPrint(
            allocator,
            "({d}, {d})",
            .{ positionX, positionY + offsetY },
        ) catch return;
        defer allocator.free(debug);
        w4.text(debug, 60, 140);
    }

    if (mode == Mode.selected) {
        w4.line(city.x, city.y - offsetY, targetX, targetY - (offsetY - targetOffsetY));
        const distanceString = std.fmt.allocPrint(
            allocator,
            "{d:.2} km",
            .{distance},
        ) catch return;
        defer allocator.free(distanceString);
        w4.text(distanceString, 60, 25);
    }

    if (mode == Mode.end) {
        const scoreString = std.fmt.allocPrint(
            allocator,
            "Score: {d:.2} km",
            .{score},
        ) catch return;
        defer allocator.free(scoreString);
        w4.text(scoreString, 15, 70);
        w4.text("Press \x80 to Restart", 10, 90);
    }

    if (mode == Mode.select or mode == Mode.selected) {
        const cityString = std.fmt.allocPrint(
            allocator,
            "{s} ({d}/{d}) ",
            .{ city.name, count, maxRounds },
        ) catch return;
        defer allocator.free(cityString);
        w4.text(cityString, 30, 10);
    }
}
