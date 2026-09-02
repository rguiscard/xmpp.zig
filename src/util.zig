const std = @import("std");
const st = @import("strophe");

pub fn stanzaGetFrom(stanza: ?*st.xmpp_stanza_t) ?[]const u8 {
    const cstr = st.xmpp_stanza_get_from(stanza);

    if (cstr != null) {
        return std.mem.span(cstr);
    }
    return null;
}

pub fn stanzaGetFromAlloc(allocator: std.mem.Allocator, stanza: ?*st.xmpp_stanza_t) ?[]const u8 {
    if (stanzaGetFrom(stanza)) |stz| {
        return allocator.dupe(stz);
    }
    return null;
}

pub fn stanzaGetChildByName(stanza: ?*st.xmpp_stanza_t, name: [:0]const u8) ?[]const u8 {
    const cstr = st.xmpp_stanza_get_child_by_name(stanza, name.ptr);

    if (cstr != null) {
        const ctext = st.xmpp_stanza_get_text(cstr);
        if (ctext != null) {
            return std.mem.span(ctext);
        }
    }
    return null;
}

pub fn stanzaGetChildByNameAlloc(allocator: std.mem.Allocator, stanza: ?*st.xmpp_stanza_t, name: [:0]const u8) ?[]const u8 {
    if (stanzaGetChildByName(stanza, name)) |stz| {
        return allocator.dupe(stz);
    }
    return null;
}
