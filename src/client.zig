const std = @import("std");
pub const st = @import("strophe");
pub const zz = @import("zigzag");
pub const ui = @import("ui.zig");
const Roster = @import("roster.zig");

const modules = .{
    Roster,
};

conn: ?*st.xmpp_conn_t,
ctx: ?*st.xmpp_ctx_t,
program: ?*zz.Program(ui),

const Self = @This();

pub fn init(
    conn: ?*st.xmpp_conn_t,
    ctx: ?*st.xmpp_ctx_t,
    program: *zz.Program(ui),
) !Self {
    var client: Self = .{ .conn = conn, .ctx = ctx, .program = program };

    inline for (modules) |m| {
        m.register(&client);
    }

    return client;
}

pub fn deinit(_: *Self) void {}
