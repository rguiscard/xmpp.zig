const std = @import("std");
const st = @import("strophe");

const Client = @import("client.zig");

const NS = "jabber:iq:roster";

pub fn register(client: *Client) void {
    st.xmpp_handler_add(client.conn, handle_push, NS, "iq", "set", client);
}

pub fn request(client: *Client) !void {
    const ctx = client.ctx;
    const conn = client.conn;

    const roster_id = st.xmpp_uuid_gen(ctx);
    defer st.xmpp_free(ctx, roster_id);

    const query = st.xmpp_stanza_new(ctx);
    defer _ = st.xmpp_stanza_release(query);
    _ = st.xmpp_stanza_set_name(query, "query");
    _ = st.xmpp_stanza_set_ns(query, NS);

    const iq = st.xmpp_iq_new(ctx, "get", roster_id);
    defer _ = st.xmpp_stanza_release(iq);
    _ = st.xmpp_stanza_add_child(iq, query);
    st.xmpp_id_handler_add(conn, handle_reply, roster_id, client);
    st.xmpp_send(conn, iq);
}

fn handle_reply(conn: ?*st.xmpp_conn_t, stanza: ?*st.xmpp_stanza_t, userdata: ?*anyopaque) callconv(.c) c_int {
    const client: *Client = @ptrCast(@alignCast(userdata));
    client.print(stanza);
    _ = conn;
    return 0;
}

fn handle_push(conn: ?*st.xmpp_conn_t, stanza: ?*st.xmpp_stanza_t, userdata: ?*anyopaque) callconv(.c) c_int {
    _ = conn;
    _ = stanza;
    _ = userdata;
    return 1;
}
