const std = @import("std");
const Io = std.Io;

const xmpp = @import("xmpp");
const st = xmpp.st;
const zz = xmpp.zz;
const ui = xmpp.ui;
const Client = xmpp.Client;
const Roster = xmpp.Roster;
const Presence = xmpp.Presence;

// define a handler for connection events
fn conn_handler(conn: ?*st.xmpp_conn_t, status: st.xmpp_conn_event_t, error_no: c_int, stream_error: ?*st.xmpp_stream_error_t, userdata: ?*anyopaque) callconv(.c) void {
    const client: *Client = @ptrCast(@alignCast(userdata));
    const ctx = client.ctx;
    _ = conn;
    _ = error_no;
    _ = stream_error;

    if (status == st.XMPP_CONN_CONNECT) {
        client.register(); // register later, otherwise, messagne_handler seems to have issue.
        try Roster.request(client);
        try Presence.sendAvailable(client, null, null);
    } else if (status == st.XMPP_CONN_RAW_CONNECT) {
        std.debug.print("DEBUG: raw connected\n", .{});
    } else if (status == st.XMPP_CONN_DISCONNECT) {
        std.debug.print("DEBUG: disconnected\n", .{});
        st.xmpp_stop(ctx);
        if (client.program) |program| {
            program.quit();
        }
    } else if (status == st.XMPP_CONN_FAIL) {
        std.debug.print("DEBUG: failed\n", .{});
    } else {
        std.debug.print("DEBUG: unknown connection\n", .{});
    }
}

pub fn main(init: std.process.Init) !void {
    // This is appropriate for anything that lives as long as the process.
    const arena: std.mem.Allocator = init.arena.allocator();

    // Accessing command line arguments:
    const args = try init.minimal.args.toSlice(arena);

    // In order to do I/O operations need an `Io` instance.
    const io = init.io;

    var jid: [:0]const u8 = undefined;
    var passwd: [:0]const u8 = undefined;
    var host: [:0]const u8 = undefined;
    const port: c_int = 0;

    if (args.len > 1) {
        const command = args[1];

        if (std.mem.eql(u8, command, "connect") and (args.len > 3)) {
            jid = args[2];
            passwd = args[3];
            //            std.debug.print("connect {s} {s}\n", .{ jid, passwd });
            if (args.len > 4) {
                host = args[4];
                //                std.debug.print("host {s}\n", .{host});
            }
            if (args.len > 5) {
                //                port = args[5];
                //                std.debug.print("port {d}\n", .{port});
            }
        } else {
            printUsage(io, args[0]) catch {};
            return;
        }
    } else {
        printUsage(io, args[0]) catch {};
        return;
    }

    var ctx: ?*st.xmpp_ctx_t = undefined;
    var conn: ?*st.xmpp_conn_t = undefined;
    var log: *st.xmpp_log_t = undefined;
    var flags: c_int = 0;

    // disable TLS for now
    flags = st.XMPP_CONN_FLAG_DISABLE_TLS;

    // init library
    st.xmpp_initialize();

    // pass NULL instead to silence output
    log = st.xmpp_get_default_logger(st.XMPP_LEVEL_ERROR);
    //    log = st.xmpp_get_default_logger(st.XMPP_LEVEL_DEBUG);
    // create a context
    ctx = st.xmpp_ctx_new(null, log);

    // create a connection
    conn = st.xmpp_conn_new(ctx);

    // register modules
    if (conn) |_| {
        // configure connection properties (optional)
        _ = st.xmpp_conn_set_flags(conn, flags);

        // For some reaon, must be in main()
        var program = zz.Program(ui).init(arena, io, init.environ_map);
        defer program.deinit();

        var client = try Client.init(arena, conn, ctx, &program);

        // setup authentication information
        st.xmpp_conn_set_jid(conn, jid);
        st.xmpp_conn_set_pass(conn, passwd);

        // initiate connection
        if (st.xmpp_connect_client(conn, host, port, &conn_handler, &client) == st.XMPP_EOK) {
            if (ctx) |c| {
                const context: *st.ctx_t = @ptrCast(@alignCast(c));
                if (context.loop_status == st.XMPP_LOOP_NOTSTARTED) {
                    context.loop_status = st.XMPP_LOOP_RUNNING;

                    if (client.program) |prog| {
                        try prog.start();
                        prog.model.setXMPPClient(&client);

                        context.timeout = 100;
                        while (prog.isRunning() and (context.loop_status == st.XMPP_LOOP_RUNNING)) {
                            try prog.tick();
                            st.xmpp_run_once(ctx, context.timeout);
                        }
                    }
                    context.loop_status = st.XMPP_LOOP_NOTSTARTED;
                }
            }
        } else {
            //        std.debug.print("DEBUG: Error on connect", .{});
        }

        // release our connection and context
        _ = st.xmpp_conn_release(conn);
        st.xmpp_ctx_free(ctx);

        // final shutdown of the library
        st.xmpp_shutdown();
    }
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
