const std = @import("std");
const st = @import("strophe");
const Client = @import("client.zig");

const NS_DISCO_INFO = "http://jabber.org/protocol/disco#info";
const NS_DISCO_ITEMS = "http://jabber.org/protocol/disco#items";

pub fn register(client: *Client) void {
    st.xmpp_handler_add(client.conn, handle_disco_info, NS_DISCO_INFO, "iq", "get", client);
    st.xmpp_handler_add(client.conn, handle_disco_items, NS_DISCO_ITEMS, "iq", "get", client);
}

fn handle_disco_info(conn: ?*st.xmpp_conn_t, stanza: ?*st.xmpp_stanza_t, userdata: ?*anyopaque) callconv(.c) c_int {
    const client: *Client = @ptrCast(@alignCast(userdata));
    _ = conn;

    client.print(stanza);

    const disco_id = st.xmpp_uuid_gen(client.ctx);
    defer st.xmpp_free(client.ctx, disco_id);

    const reply = st.xmpp_stanza_reply(stanza);
    _ = st.xmpp_stanza_set_attribute(reply, "type", "result");
    _ = st.xmpp_stanza_set_attribute(reply, "id", disco_id);
    defer _ = st.xmpp_stanza_release(reply);

    const query = st.xmpp_stanza_new(client.ctx);
    _ = st.xmpp_stanza_set_name(query, "query");
    _ = st.xmpp_stanza_set_ns(query, NS_DISCO_INFO);

    _ = st.xmpp_stanza_add_child(reply, query);

    const identity = st.xmpp_stanza_new(client.ctx);
    defer _ = st.xmpp_stanza_release(identity);

    _ = st.xmpp_stanza_set_name(identity, "identity");
    _ = st.xmpp_stanza_set_attribute(identity, "category", "client");
    _ = st.xmpp_stanza_set_attribute(identity, "type", "pc");
    _ = st.xmpp_stanza_set_attribute(identity, "name", "XMPP.zig");
    _ = st.xmpp_stanza_add_child(query, identity);

    const features = [_][:0]const u8{
        "http://jabber.org/protocol/disco#info",
        "http://jabber.org/protocol/disco#items",
        "http://jabber.org/protocol/mood",
        "http://jabber.org/protocol/mood+notify",
        "http://jabber.org/protocol/activity",
        "http://jabber.org/protocol/activity+notify",
    };

    for (features) |feature| {
        const stz = st.xmpp_stanza_new(client.ctx);
        defer _ = st.xmpp_stanza_release(stz);

        _ = st.xmpp_stanza_set_name(stz, "feature");
        _ = st.xmpp_stanza_set_attribute(stz, "var", feature);

        _ = st.xmpp_stanza_add_child(query, stz);
    }
 
    client.print(reply);

    _ = st.xmpp_send(client.conn, reply);

    return 1;
}

fn handle_disco_items(conn: ?*st.xmpp_conn_t, stanza: ?*st.xmpp_stanza_t, userdata: ?*anyopaque) callconv(.c) c_int {
    const client: *Client = @ptrCast(@alignCast(userdata));
    _ = conn;
    _ = client;
    _ = stanza;

    return 1;
}
