const std = @import("std");
pub const st = @import("strophe");
pub const zz = @import("zigzag");
pub const ui = @import("ui.zig");
const Roster = @import("roster.zig");
const Presence = @import("presence.zig");
const Chat = @import("message.zig");
const Disco = @import("disco.zig");
const Pool = @import("pool.zig");

const modules = .{
    Roster,
    Presence,
    Chat,
    Disco,
};

pub const Buddy = struct {
    name: ?[:0]const u8,
    jid: [:0]const u8,
    presense: bool,
    subscription: [:0]const u8,
};

pub const Available = struct {
    jid: [:0]const u8,
    show: ?[:0]const u8 = null,
    status: ?[:0]const u8 = null,
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
    from: [:0]const u8,
    to: [:0]const u8,
    body: ?[:0]const u8,
    type: MessageType,
};

allocator: std.mem.Allocator,
conn: ?*st.xmpp_conn_t,
ctx: ?*st.xmpp_ctx_t,
program: *zz.Program(ui),
buddies: std.ArrayList(Buddy) = .empty,
// presences may not sync with buddies, thus, in its own list
presences: std.ArrayList(Available) = .empty,
messages: std.ArrayList(Message) = .empty,

jids: Pool.StringPool([:0]const u8) = undefined,

to_jid: ?[:0]const u8 = null,
me: [:0]const u8,

const Self = @This();

pub fn init(
    allocator: std.mem.Allocator,
    conn: ?*st.xmpp_conn_t,
    ctx: ?*st.xmpp_ctx_t,
    program: *zz.Program(ui),
    me: [:0]const u8,
) !Self {
    var client: Self = .{
        .allocator = allocator,
        .conn = conn,
        .ctx = ctx,
        .program = program,
        .me = me,
    };

    client.buddies = try std.ArrayList(Buddy).initCapacity(allocator, 10);
    client.jids = Pool.StringPool([:0]const u8).init(allocator);

    // client.register(); // register after connection, not here

    return client;
}

fn equalString(lhs: [:0]const u8, rhs: [:0]const u8) bool {
    return std.mem.eql(u8, lhs, rhs);
}

// Return bare jid or original jid
// Probably should raise error if it cannot get bare jid ?
pub fn bareJID(self: *Self, jid: [:0]const u8) [:0]const u8 {
    const ctx = self.ctx;

    const id = self.jids.fetch(jid);
    if (id) |jid_bare| {
        return jid_bare;
    } else {
        const jid_bare = st.xmpp_jid_bare(ctx, jid.ptr);
        defer st.xmpp_free(ctx, jid_bare);
        if (jid_bare != null) {
            const jid_str = std.mem.span(jid_bare);
            // jids pool will own both jid and jid_bare
            if (self.jids.add(jid, jid_str, equalString)) |pos| {
                return self.jids.get_str(pos) orelse jid;
            } else |_| {
                return jid;
            }
        }
    }
    return jid;
}

pub fn register(self: *Self) void {
    inline for (modules) |m| {
        m.register(self);
    }
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
        std.debug.print("\nstanza: {s}\n", .{text[0..text_len]});
        st.xmpp_free(st.xmpp_stanza_get_context(stanza), text);
        //st.xmpp_free(ctx, text);
    }
}

pub fn deinit(self: *Self) void {
    self.buddies.deinit(self.allocator);
}
