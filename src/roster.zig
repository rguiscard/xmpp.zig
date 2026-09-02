const std = @import("std");
const st = @import("strophe");

const Client = @import("client.zig");
const Buddy = Client.Buddy;
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
    //    client.print(stanza);
    _ = conn;

    const result = st.xmpp_stanza_get_type(stanza);
    if (std.mem.eql(u8, std.mem.span(result), "error")) {
        std.debug.print("ERROR: query failed\n", .{});
    } else {
        const query = st.xmpp_stanza_get_child_by_name(stanza, "query");
        var item = st.xmpp_stanza_get_children(query);
        client.buddies.clearRetainingCapacity();
        while (item != null) {
            const name = st.xmpp_stanza_get_attribute(item, "name");
            const jid = st.xmpp_stanza_get_attribute(item, "jid");
            //            const subscription = st.xmpp_stanza_get_attribute(item, "subscription");
            var buddy: Buddy = .{ .name = null, .jid = client.allocator.dupe(u8, std.mem.span(jid)) catch "", .presense = false };
            //            std.debug.print("\t {s} sub={s}\n", .{ std.mem.span(jid), std.mem.span(subscription) });
            if (name) |n| {
                buddy.name = client.allocator.dupe(u8, std.mem.span(n)) catch "";
            }
            client.buddies.append(client.allocator, buddy) catch {};
            item = st.xmpp_stanza_get_next(item);
        }
        if (client.buddies.items.len > 0) {
            //            std.debug.print("buddies {d}\n", .{client.buddies.items.len});
            if (client.program) |program| {
                program.model.setBuddies(client.buddies) catch {};
            }
        }
    }

    return 0;
}

fn handle_push(conn: ?*st.xmpp_conn_t, stanza: ?*st.xmpp_stanza_t, userdata: ?*anyopaque) callconv(.c) c_int {
    const client: *Client = @ptrCast(@alignCast(userdata));
    client.print(stanza);
    _ = conn;
    return 1;
}
