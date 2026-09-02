const std = @import("std");
const st = @import("strophe");
const util = @import("util.zig");

const Client = @import("client.zig");
const Message = Client.Message;
const MessageType = Client.MessageType;

pub fn register(client: *Client) void {
    st.xmpp_handler_add(client.conn, handle_message, null, "message", null, client);
}

pub fn request(client: *Client) !void {
    _ = client;
}

fn handle_message(conn: ?*st.xmpp_conn_t, stanza: ?*st.xmpp_stanza_t, userdata: ?*anyopaque) callconv(.c) c_int {
    _ = userdata;
    //    const client: *Client = @ptrCast(@alignCast(userdata));
    //    client.print(stanza);
    _ = conn;

    const from = util.stanzaGetFrom(stanza);
    const body = util.stanzaGetChildByName(stanza, "body");
    const to = util.stanzaGetTo(stanza);
    const message_type = parseMessageType(
        st.xmpp_stanza_get_type(stanza),
    );

    std.debug.print("Message {s} {s} {s} {any}\n", .{ from orelse "", to orelse "", body orelse "", message_type });

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
