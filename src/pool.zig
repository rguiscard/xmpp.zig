const std = @import("std");
const testing = std.testing;

// Data structure to keep objects in memory.
// The main purpose is that others do not need to own these objects
// All objects will stay in pool until the end of program
// To manage memory, see test "clonable struct" (pointer and plain version).
// Use struct and pass *Struct (or Struct) to StringPool(T).
// Implement clone() and clear() to copy and free fields of struct.
pub fn StringPool(comptime T: type) type {

    return struct {
        pub const StringId = usize; // size of pointer
        const Self = @This();

        allocator: std.mem.Allocator,
        list: std.ArrayList(T),
        hash: std.StringHashMap(StringId),

        pub fn init(allocator: std.mem.Allocator) Self {
            const self: Self = .{
                .allocator = allocator,
                .list = .empty,
                .hash = std.StringHashMap(StringId).init(allocator),
            };
            return self;
        }

        pub fn deinit(self: *Self) void {
            self.clear();
            self.hash.deinit();
            self.list.deinit(self.allocator);
        }

        pub fn clear(self: *Self) void {
            if ((T == [:0]const u8) or (T == []const u8)) {
                for (self.list.items) |item| {
                    self.allocator.free(item);
                }
            } else {
                switch (@typeInfo(T)) {
                    .pointer => |ptr| {
                        if (@typeInfo(ptr.child) == .@"struct") {
                            if (@hasDecl(ptr.child, "clear")) {
                                for (self.list.items) |item| {
                                    item.clear(self.allocator);
                                }
                            }
                        }
                    },
                    .@"struct" => {
                        if (@hasDecl(T, "clear")) {
                            for (self.list.items) |item| {
                                item.clear(self.allocator);
                            }
                        }
                    },
                    else => {},
                }
            }

            self.list.clearRetainingCapacity();

            var it = self.hash.iterator();
            while (it.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
            self.hash.clearRetainingCapacity();
        }

        pub fn contains(self: *Self, key: [:0]const u8) bool {
            return self.hash.contains(key);
        }

        // clone value to keep in array list
        fn clone(allocator: std.mem.Allocator, value: T) !T {
            if (T == [:0]const u8) {
                return try allocator.dupeZ(u8, value);
            }

            if (T == []const u8) {
                return try allocator.dupe(u8, value);
            }

            switch (@typeInfo(T)) {
                .pointer => |ptr| {
                    if (@typeInfo(ptr.child) == .@"struct") {
                        if (@hasDecl(ptr.child, "clone")) {
                            return try value.clone(allocator);
                        }
                    }
                },
                .@"struct" => {
                    if (@hasDecl(T, "clone")) {
                        return value.clone(allocator);
                    }
                },
                else => {},
            }

            return value;
        }

        // Make a copy of str. Owner can free his own str.
        pub fn add(self: *Self, key: []const u8, value: T) !StringId {
            const entry = self.hash.getEntry(key);
            if (entry) |e| {
                return e.value_ptr.*;
            }
            const pos = self.list.items.len;
            const kcopy = self.allocator.dupe(u8, key) catch unreachable;
            const vcopy = clone(self.allocator, value) catch unreachable;
            try self.list.append(self.allocator, vcopy);
            _ = try self.hash.put(kcopy, pos);
            return pos;
        }

        pub fn fetch(self: *Self, key: [:0]const u8) ?T {
            if (self.get_pos(key)) |pos| {
                return self.get_str(pos);
            }
            return null;
        }

        pub fn get_pos(self: Self, key: [:0]const u8) ?StringId {
            const entry = self.hash.getEntry(key);
            if (entry) |e| {
                return e.value_ptr.*;
            }
            return null;
        }

        pub fn get_str(self: Self, pos: StringId) ?T {
            if (pos >= self.list.items.len) return null;
            return self.list.items[pos];
        }

        pub fn size(self: Self) usize {
            return self.list.items.len;
        }
    };
}

test "basic" {
    var pool = StringPool([:0]const u8).init(std.testing.allocator);
    defer pool.deinit();

    const key = "key";
    const value = "value";
    const pos: usize = 0;

    _ = try pool.add(key, value);
    try testing.expect(pool.get_pos(key).? == pos);
    try testing.expect(std.mem.eql(u8, pool.get_str(pos).?, value));
    try testing.expect(pool.size() == 1);
}

test "no overwrites" {
    var pool = StringPool([:0]const u8).init(std.testing.allocator);
    defer pool.deinit();

    const key = "This is key #";
    const value = "This is value #";
    const klen = key.len;
    const vlen = value.len;
    var c: u8 = 0;
    var kbuf: [100]u8 = undefined;
    var vbuf: [100]u8 = undefined;
    while (c < 10) : (c += 1) {
        var len: usize = 0;
        // value
        @memcpy(vbuf[len .. len + vlen], value);
        len += value.len;
        vbuf[len] = c + '0';
        len += 1;
        vbuf[len] = 0;
        const vstr: [:0]const u8 = vbuf[0..len :0];
        // key
        len = 0;
        @memcpy(kbuf[len .. len + klen], key);
        len += key.len;
        kbuf[len] = c + '0';
        len += 1;
        const kstr = kbuf[0..len];
        // std.debug.warn("ADD [{}]\n", .{str});
        _ = try pool.add(kstr, vstr);
    }

    const size = pool.size();
    try testing.expect(size == 10);

    while (c < 10) : (c += 1) {
        var len: usize = 0;
        // key
        @memcpy(kbuf[len .. len + klen], key);
        len += key.len;
        kbuf[len] = c + '0';
        len += 1;
        kbuf[len] = 0;
        const kstr = kbuf[0..len :0];

        // value
        len = 0;
        @memcpy(vbuf[len .. len + vlen], value);
        len += value.len;
        vbuf[len] = c + '0';
        len += 1;
        const vstr = vbuf[0..len];

        const got = pool.get_str(c).?;

        // std.debug.warn("GOT [{}] EXPECT [{}]\n", .{ got, str });
        try testing.expect(std.mem.eql(u8, got, vstr));

        if (pool.fetch(kstr)) |v| {
            try testing.expect(std.mem.eql(u8, v, vstr));
        }
    }
}

test "struct" {
    const Contact = struct {
        name: []const u8,
        age: usize,
    };

    var pool = StringPool(Contact).init(std.testing.allocator);
    defer pool.deinit();

    const key = "Bob";
    const value: Contact = .{
        .name = "Bob",
        .age = 28,
    };
    const pos: usize = 0;

    _ = try pool.add(key, value);
    try testing.expect(pool.get_pos(key).? == pos);
    try testing.expect(pool.size() == 1);
    const got = pool.fetch(key);
    try testing.expect(std.mem.eql(u8, got.?.name, "Bob"));
}

test "clonable struct (pointer)" {
    const Contact = struct {
        name: []const u8,
        age: usize,

        const Self = @This();

        fn clone(self: *Self, allocator: std.mem.Allocator) !*Self {
            const copy = try allocator.create(Self);
            copy.* = .{ .name = try allocator.dupe(u8, self.name), .age = self.age };
            return copy;
        }

        fn clear(self: *Self, allocator: std.mem.Allocator) void {
            allocator.free(self.name);
            allocator.destroy(self);
        }
    };

    var pool = StringPool(*Contact).init(std.testing.allocator);
    defer pool.deinit();

    const key = "Bob";
    const value: Contact = .{
        .name = "Bob",
        .age = 28,
    };
    const pos: usize = 0;

    _ = try pool.add(key, @constCast(&value));
    try testing.expect(pool.get_pos(key).? == pos);
    try testing.expect(pool.size() == 1);
    const got = pool.fetch(key);
    try testing.expect(std.mem.eql(u8, got.?.name, "Bob"));
}

test "clonable struct (plain)" {
    const Contact = struct {
        name: []const u8,
        age: usize,

        const Self = @This();

        fn clone(self: Self, allocator: std.mem.Allocator) !Self {
            const copy:Self = .{ .name = try allocator.dupe(u8, self.name), .age = self.age };
            return copy;
        }

        fn clear(self: Self, allocator: std.mem.Allocator) void {
            allocator.free(self.name);
        }
    };

    var pool = StringPool(Contact).init(std.testing.allocator);
    defer pool.deinit();

    const key = "Bob";
    const value: Contact = .{
        .name = "Bob",
        .age = 28,
    };
    const pos: usize = 0;

    _ = try pool.add(key, value);
    try testing.expect(pool.get_pos(key).? == pos);
    try testing.expect(pool.size() == 1);
    const got = pool.fetch(key);
    try testing.expect(std.mem.eql(u8, got.?.name, "Bob"));
}
