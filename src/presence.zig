const std = @import("std");
const st = @import("strophe");
const util = @import("util.zig");

const Client = @import("client.zig");

const Available = Client.Available;

const Self = @This();

pub fn register(client: *Client) void {
    st.xmpp_handler_add(client.conn, handle_presence, null, "presence", null, client);
}

pub fn sendAvailable(client: *Client, show: ?[:0]const u8, status: ?[:0]const u8) !void {
    const ctx = client.ctx;
    const conn = client.conn;

    const presence = st.xmpp_presence_new(ctx);
    defer _ = st.xmpp_stanza_release(presence);

    if (show) |value| {
        util.stanzaSetChildByName(presence, "show", value);
    }

    if (status) |value| {
        util.stanzaSetChildByName(presence, "status", value);
    }

    //    client.print(presence);

    st.xmpp_send(conn, presence);
}

fn handle_presence(conn: ?*st.xmpp_conn_t, stanza: ?*st.xmpp_stanza_t, userdata: ?*anyopaque) callconv(.c) c_int {
    const client: *Client = @ptrCast(@alignCast(userdata));
    //client.print(stanza);
    _ = conn;

    if (stanza) |stz| {
        const presence_type = st.xmpp_stanza_get_type(stz);

        if (presence_type == null) {
            _ = handleAvailable(client.allocator, stz);
        } else {
            const presence = std.mem.span(presence_type);
            if (std.mem.eql(u8, presence, "subscribe")) {
                //        handleSubscribe(s);
            } else if (std.mem.eql(u8, presence, "subscribed")) {
                //        handleSubscribed(s);
            } else if (std.mem.eql(u8, presence, "unsubscribe")) {
                //        handleUnsubscribe(s);
            } else if (std.mem.eql(u8, presence, "unsubscribed")) {
                //        handleUnsubscribed(s);
            } else if (std.mem.eql(u8, presence, "unavailable")) {
                //        handleUnavailable(s);
            }
        }
    }
    return 1;
}

fn handleAvailable(allocator: std.mem.Allocator, stanza: *st.xmpp_stanza_t) ?Available {
    const from = util.stanzaGetFrom(stanza);
    if (from) |jid| {
        const priority_str = util.stanzaGetChildByNameAlloc(allocator, stanza, "priority") catch "0";
        const available: Available = .{
            .jid = jid,
            .show = util.stanzaGetChildByNameAlloc(allocator, stanza, "show") catch null,
            .status = util.stanzaGetChildByNameAlloc(allocator, stanza, "status") catch null,
            .priority = std.fmt.parseInt(i32, priority_str orelse "0", 10) catch 0,
        };
        //        std.debug.print("presence {s} ({s})\n", .{ available.jid, available.show orelse "" });
        return available;
    }

    return null;
}
