const std = @import("std");
const st = @import("strophe");
const Client = @import("client.zig");

// caller need to make copy to retain returned string
pub fn stanzaGetFrom(stanza: ?*st.xmpp_stanza_t) ?[:0]const u8 {
    const cstr = st.xmpp_stanza_get_from(stanza);

    if (cstr != null) {
        return std.mem.span(cstr);
    }
    return null;
}

pub fn stanzaGetFromAlloc(allocator: std.mem.Allocator, stanza: ?*st.xmpp_stanza_t) !?[:0]const u8 {
    if (stanzaGetFrom(stanza)) |stz| {
        return try allocator.dupeZ(stz);
    }
    return null;
}

// caller need to make copy to retain returned string
pub fn stanzaGetTo(stanza: ?*st.xmpp_stanza_t) ?[:0]const u8 {
    const cstr = st.xmpp_stanza_get_to(stanza);

    if (cstr != null) {
        return std.mem.span(cstr);
    }
    return null;
}

pub fn stanzaGetToAlloc(allocator: std.mem.Allocator, stanza: ?*st.xmpp_stanza_t) !?[:0]const u8 {
    if (stanzaGetTo(stanza)) |stz| {
        return try allocator.dupeZ(stz);
    }
    return null;
}

pub fn stanzaSetChildByName(parent: ?*st.xmpp_stanza_t, name: [:0]const u8, value: [:0]const u8) void {
    const ctx = st.xmpp_stanza_get_context(parent);
    const stanza = st.xmpp_stanza_new(ctx);
    defer _ = st.xmpp_stanza_release(stanza);

    _ = st.xmpp_stanza_set_name(stanza, name.ptr);

    const text = st.xmpp_stanza_new(ctx);
    defer _ = st.xmpp_stanza_release(text);

    _ = st.xmpp_stanza_set_text(text, value.ptr);
    _ = st.xmpp_stanza_add_child(stanza, text);
    _ = st.xmpp_stanza_add_child(parent, stanza);
}

// caller need to release stanza text
pub fn stanzaGetChildByName(stanza: ?*st.xmpp_stanza_t, name: [:0]const u8) ?[:0]const u8 {
    const cstr = st.xmpp_stanza_get_child_by_name(stanza, name.ptr);

    if (cstr != null) {
        const ctext = st.xmpp_stanza_get_text(cstr);
        if (ctext != null) {
            return std.mem.span(ctext);
        }
    }
    return null;
}

pub fn stanzaGetChildByNameAlloc(allocator: std.mem.Allocator, stanza: ?*st.xmpp_stanza_t, name: [:0]const u8) !?[:0]const u8 {
    if (stanzaGetChildByName(stanza, name)) |stz| {
        return try allocator.dupeZ(stz);
    }
    return null;
}
