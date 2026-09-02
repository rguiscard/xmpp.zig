const std = @import("std");
const st = @import("strophe");
const util = @import("util.zig");

const Client = @import("client.zig");

const Available = Client.Available;

pub fn register(client: *Client) void {
    st.xmpp_handler_add(client.conn, handle_presence, null, "presence", null, client);
}

pub fn request(client: *Client) !void {
    _ = client;
    //    const ctx = client.ctx;
    //    const conn = client.conn;
    //
    //    const roster_id = st.xmpp_uuid_gen(ctx);
    //    defer st.xmpp_free(ctx, roster_id);
    //
    //    const query = st.xmpp_stanza_new(ctx);
    //    defer _ = st.xmpp_stanza_release(query);
    //    _ = st.xmpp_stanza_set_name(query, "query");
    //    _ = st.xmpp_stanza_set_ns(query, NS);
    //
    //    const iq = st.xmpp_iq_new(ctx, "get", roster_id);
    //    defer _ = st.xmpp_stanza_release(iq);
    //    _ = st.xmpp_stanza_add_child(iq, query);
    //    st.xmpp_id_handler_add(conn, handle_reply, roster_id, client);
    //    st.xmpp_send(conn, iq);
}

fn handle_presence(conn: ?*st.xmpp_conn_t, stanza: ?*st.xmpp_stanza_t, userdata: ?*anyopaque) callconv(.c) c_int {
    const client: *Client = @ptrCast(@alignCast(userdata));
    client.print(stanza);
    _ = conn;

    if (stanza) |stz| {
        const presence_type = st.xmpp_stanza_get_type(stz);

        if (presence_type == null) {
            _ = handleAvailable(stz);
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

fn handleAvailable(stanza: *st.xmpp_stanza_t) ?Available {
    const from = util.stanzaGetFrom(stanza);
    if (from) |jid| {
        const priority_str = util.stanzaGetChildByName(stanza, "priority");
        const available: Available = .{
            .jid = jid,
            .show = util.stanzaGetChildByName(stanza, "show"),
            .status = util.stanzaGetChildByName(stanza, "status"),
            .priority = std.fmt.parseInt(i32, priority_str orelse "0", 10) catch 0,
        };
        return available;
    }

    return null;
}
