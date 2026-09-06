const std = @import("std");
const st = @import("strophe");
const util = @import("util.zig");

const Client = @import("client.zig");

pub fn register(client: *Client) void {
    _ = client;
    // do nothing for now.
}

pub fn sendMood(client: *Client, state: [:0]const u8, text: [:0]const u8) void {
    const ctx = client.ctx;

    const iq_id = st.xmpp_uuid_gen(ctx);
    defer st.xmpp_free(ctx, iq_id);

    const iq = st.xmpp_iq_new(ctx, "set", iq_id);
    defer _ = st.xmpp_stanza_release(iq);

    const pubsub = st.xmpp_stanza_new(ctx);
    defer _ = st.xmpp_stanza_release(pubsub);
    _ = st.xmpp_stanza_set_name(pubsub, "pubsub");
    _ = st.xmpp_stanza_set_ns(pubsub, "http://jabber.org/protocol/pubsub");
    _ = st.xmpp_stanza_add_child(iq, pubsub);

    const publish = st.xmpp_stanza_new(ctx);
    defer _ = st.xmpp_stanza_release(publish);
    _ = st.xmpp_stanza_set_name(publish, "publish");
    _ = st.xmpp_stanza_set_attribute( publish, "node", "http://jabber.org/protocol/mood");
    _ = st.xmpp_stanza_add_child(pubsub, publish);

    const item = st.xmpp_stanza_new(ctx);
    defer _ = st.xmpp_stanza_release(item);
    _ = st.xmpp_stanza_set_name(item, "item");
    _ = st.xmpp_stanza_add_child(publish, item);

    const mood = st.xmpp_stanza_new(ctx);
    defer _ = st.xmpp_stanza_release(mood);
    _ = st.xmpp_stanza_set_name(mood, "mood");
    _ = st.xmpp_stanza_set_ns( mood, "http://jabber.org/protocol/mood");
    _ = st.xmpp_stanza_add_child(item, mood);

    const status = st.xmpp_stanza_new(ctx);
    defer _ = st.xmpp_stanza_release(status);
    _ = st.xmpp_stanza_set_name(status, state);
    _ = st.xmpp_stanza_add_child(mood, status);

    const txt = st.xmpp_stanza_new(ctx);
    defer _ = st.xmpp_stanza_release(txt);
    _ = st.xmpp_stanza_set_name(txt, "text");
    _ = st.xmpp_stanza_add_child(mood, txt);

    const value = st.xmpp_stanza_new(ctx);
    defer _ = st.xmpp_stanza_release(value);
    _ = st.xmpp_stanza_set_text(value, text);
    _ = st.xmpp_stanza_add_child(txt, value);

    _ = st.xmpp_id_handler_add(client.conn, handle_mood_reply, iq_id, client);

    _ = st.xmpp_send(client.conn, iq);
}

fn handle_mood_reply(conn: ?*st.xmpp_conn_t, stanza: ?*st.xmpp_stanza_t, userdata: ?*anyopaque) callconv(.c) c_int {
    //const client: *Client = @ptrCast(@alignCast(userdata));
    //    client.print(stanza);
    _ = userdata;
    _ = conn;

    const result_type = st.xmpp_stanza_get_type(stanza);
    if (result_type == null) {
        return 1; // keep waiting
    } else {
        const result:[:0]const u8 = std.mem.span(result_type);
        if (std.mem.eql(u8, "result", result)) {
            std.debug.print("publish mood successfully.\n", .{});
        } else {
            std.debug.print("publish mood failed.\n", .{});
        }
        return 0;
    }
}

// This is the child stanza after get_child_by_ns
pub fn handle_event_message(client: *Client, stanza: ?*st.xmpp_stanza_t) void {
    client.print(stanza);

    const items = st.xmpp_stanza_get_child_by_name(stanza, "items");

    if (items == null)
        return;

    const node = st.xmpp_stanza_get_attribute(items, "node");

    if ((node != null) and std.mem.eql(u8, std.mem.span(node), "http://jabber.org/protocol/mood")) {
        const item = st.xmpp_stanza_get_child_by_name(items, "item");

        if (item == null) {
            return;
        }

        const mood = st.xmpp_stanza_get_child_by_ns( item, "http://jabber.org/protocol/mood");

        if (mood == null) {
            return;
        }

        // The first child is the mood value, e.g. <happy/>
        var child = st.xmpp_stanza_get_children(mood);
        var mood_val:?[:0]const u8 = null;
        var text:?[:0]const u8 = null;

        while (child != null) {
            const name = st.xmpp_stanza_get_name(child);

            if ((name != null) and (text == null) and std.mem.eql(u8, "text", std.mem.span(name))) {
                const txt = st.xmpp_stanza_get_text(child);
                text = std.mem.span(txt);
            } else if ((name != null) and (mood_val == null)) {
                mood_val = std.mem.span(name);
            }

            child = st.xmpp_stanza_get_next(child);
        }

        std.debug.print("\n({s}) {s}\n", .{mood_val orelse "", text orelse ""});
    }
}
