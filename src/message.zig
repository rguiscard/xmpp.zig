const std = @import("std");
const st = @import("strophe");
const util = @import("util.zig");

const Client = @import("client.zig");
const Message = Client.Message;
const MessageType = Client.MessageType;

pub fn register(client: *Client) void {
    st.xmpp_handler_add(client.conn, handle_message, null, "message", null, client);
}

pub fn sendMessage(client: *Client, to: [:0]const u8, body: [:0]const u8) !void {
    const ctx = client.ctx;
    const conn = client.conn;

    const id = st.xmpp_uuid_gen(ctx);
    defer st.xmpp_free(ctx, id);

    const msg = st.xmpp_message_new(ctx, "chat", to.ptr, id);
    defer _ = st.xmpp_stanza_release(msg);

    _ = st.xmpp_message_set_body(msg, body.ptr);
    _ = st.xmpp_send(conn, msg);
    if (client.program) |program| {
        program.model.log.appendFmt(program.context.io, .info, "{s}: {s}", .{ "me", body }) catch {};
    }
}

fn handle_message(conn: ?*st.xmpp_conn_t, stanza: ?*st.xmpp_stanza_t, userdata: ?*anyopaque) callconv(.c) c_int {
    const client: *Client = @ptrCast(@alignCast(userdata));
    const ctx = client.ctx;

    _ = conn;

    const from = util.stanzaGetFrom(stanza);
    var sender: ?[:0]const u8 = null;
    if (from) |jid| {
        sender = std.mem.span(st.xmpp_jid_bare(ctx, jid.ptr));
    }
    const body: ?[:0]const u8 = util.stanzaGetChildByNameAlloc(client.allocator, stanza, "body") catch null;

    //const to = util.stanzaGetTo(stanza);
    //const message_type = parseMessageType(
    //    st.xmpp_stanza_get_type(stanza),
    //);

    if (client.program) |program| {
        if (sender) |s| {
            program.model.log.appendFmt(program.context.io, .info, "{s}: {s}", .{ s, body orelse "" }) catch {};
        }
    }

    return 1;
}

fn parseMessageType(cstr: [*c]const u8) MessageType {
    if (cstr == null)
        return .normal;

    const value = std.mem.span(cstr);

    if (std.mem.eql(u8, value, "chat"))
        return .chat;

    if (std.mem.eql(u8, value, "groupchat"))
        return .groupchat;

    if (std.mem.eql(u8, value, "headline"))
        return .headline;

    if (std.mem.eql(u8, value, "error"))
        return .err;

    return .normal;
}
