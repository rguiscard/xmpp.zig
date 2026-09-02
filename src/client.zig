const std = @import("std");
pub const st = @import("strophe");
pub const zz = @import("zigzag");
pub const ui = @import("ui.zig");
const Roster = @import("roster.zig");
const Presence = @import("presence.zig");
const Chat = @import("message.zig");

const modules = .{
    Roster,
    Presence,
    Chat,
};

pub const Buddy = struct {
    name: ?[]const u8,
    jid: []const u8,
    presense: bool,
};

pub const Available = struct {
    jid: []const u8,
    show: ?[]const u8 = null,
    status: ?[]const u8 = null,
    priority: i32 = 0,
};

pub const MessageType = enum {
    chat,
    normal,
    groupchat,
    headline,
    err,
};

pub const Message = struct {
    from: []const u8,
    to: ?[]const u8,
    body: []const u8,
    message_type: MessageType,
};

allocator: std.mem.Allocator,
conn: ?*st.xmpp_conn_t,
ctx: ?*st.xmpp_ctx_t,
program: ?*zz.Program(ui),
buddies: std.ArrayList(Buddy) = .empty,
// presences may not sync with buddies, thus, in its own list
presences: std.ArrayList(Available) = .empty,

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
    _ = self;
    //    const ctx = self.ctx;
    var text: [*c]u8 = null;
    var text_len: usize = 0;

    const rc = st.xmpp_stanza_to_text(stanza, &text, &text_len);
    if (rc != 0) {
        std.debug.print("xmpp_stanza_to_text failed\n", .{});
        return;
    }
    if (text != 0) {
        std.debug.print("stanza: {s}\n", .{text[0..text_len]});
        st.xmpp_free(st.xmpp_stanza_get_context(stanza), text);
        //st.xmpp_free(ctx, text);
    }
}

pub fn deinit(self: *Self) void {
    self.buddies.deinit(self.allocator);
}
