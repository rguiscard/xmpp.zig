const std = @import("std");
const Io = std.Io;

const xmpp = @import("xmpp");
const st = xmpp.strophe;

pub fn main(init: std.process.Init) !void {
    // This is appropriate for anything that lives as long as the process.
    const arena: std.mem.Allocator = init.arena.allocator();

    // Accessing command line arguments:
    const args = try init.minimal.args.toSlice(arena);

    // In order to do I/O operations need an `Io` instance.
    const io = init.io;

    if (args.len > 1) {
        const command = args[1];

        if (std.mem.eql(u8, command, "connect") and (args.len > 3)) {
            const jid = args[2];
            const passwd = args[3];
            std.debug.print("connect {s} {s}\n", .{ jid, passwd });
            if (args.len > 4) {
                const host = args[4];
                std.debug.print("host {s}\n", .{host});
            }
            if (args.len > 5) {
                const port = args[5];
                std.debug.print("port {s}\n", .{port});
            }
            return;
        }
    }

    printUsage(io, args[0]) catch {};

    // init library
    st.xmpp_initialize();

    // final shutdown of the library
    st.xmpp_shutdown();
}

fn printUsage(io: std.Io, prog_name: []const u8) !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const writer = &stdout_file_writer.interface;

    try writer.print("Usage: {s} <command> [args]\n", .{prog_name});
    try writer.print("\n", .{});
    try writer.print("Commands:\n", .{});
    try writer.print("  connect <jabber_id> <password> <server> <optional:port>\n", .{});

    try writer.flush();
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    try std.testing.fuzz({}, testOne, .{});
}

fn testOne(context: void, smith: *std.testing.Smith) !void {
    _ = context;
    // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!

    const gpa = std.testing.allocator;
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(gpa);
    while (!smith.eos()) switch (smith.value(enum { add_data, dup_data })) {
        .add_data => {
            const slice = try list.addManyAsSlice(gpa, smith.value(u4));
            smith.bytes(slice);
        },
        .dup_data => {
            if (list.items.len == 0) continue;
            if (list.items.len > std.math.maxInt(u32)) return error.SkipZigTest;
            const len = smith.valueRangeAtMost(u32, 1, @min(32, list.items.len));
            const off = smith.valueRangeAtMost(u32, 0, @intCast(list.items.len - len));
            try list.appendSlice(gpa, list.items[off..][0..len]);
            try std.testing.expectEqualSlices(
                u8,
                list.items[off..][0..len],
                list.items[list.items.len - len ..],
            );
        },
    };
}
