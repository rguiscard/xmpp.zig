const std = @import("std");
pub const st = @import("strophe");
pub const zz = @import("zigzag");
pub const ui = @import("ui.zig");
const Roster = @import("roster.zig");

const modules = .{
    Roster,
};

pub const Buddy = struct {
    name: ?[]const u8,
    jid: []const u8,
    presense: bool,
};

allocator: std.mem.Allocator,
conn: ?*st.xmpp_conn_t,
ctx: ?*st.xmpp_ctx_t,
program: ?*zz.Program(ui),
buddies: std.ArrayList(Buddy) = .empty,

const Self = @This();

pub fn init(
    allocator: std.mem.Allocator,
    conn: ?*st.xmpp_conn_t,
    ctx: ?*st.xmpp_ctx_t,
    program: *zz.Program(ui),
) !Self {
    var client: Self = .{ .allocator = allocator, .conn = conn, .ctx = ctx, .program = program };

    client.buddies = try std.ArrayList(Buddy).initCapacity(allocator, 10);

    inline for (modules) |m| {
        m.register(&client);
    }

    return client;
}

pub fn print(self: *Self, stanza: ?*st.xmpp_stanza_t) void {
    const ctx = self.ctx;
    var text: [*c]u8 = null;
    var text_len: usize = 0;

    const rc = st.xmpp_stanza_to_text(stanza, &text, &text_len);
    if (rc != 0) {
        std.debug.print("xmpp_stanza_to_text failed\n", .{});
        return;
    }
    if (text) |t| {
        std.debug.print("stanza: {s}\n", .{t[0..text_len]});
        //        st.xmpp_free(st.xmpp_stanza_get_context(stanza), text);
        st.xmpp_free(ctx, text);
    }
}

pub fn deinit(self: *Self) void {
    self.buddies.deinit(self.allocator);
}
