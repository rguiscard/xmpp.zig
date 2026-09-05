const std = @import("std");
const crypto = std.crypto;
const base64_encoder = std.base64.standard.Encoder;

pub const Identity = struct {
    category: []const u8,
    type: []const u8,
    lang: []const u8 = "",
    name: []const u8 = "",
};

pub const FormField = struct {
    var_name: []const u8,
    values: []const []const u8,
};

pub const DataForm = struct {
    form_type: []const u8,
    fields: []const FormField,
};

pub const HashAlgo = enum {
    sha1,
    sha256,
};

// This calculates the same results of XEP-0115 simple and complex example

pub fn calculateVerificationString(
    allocator: std.mem.Allocator,
    identities: []const Identity,
    features: []const []const u8,
    data_forms: ?[]const DataForm,
    algo: HashAlgo,
) ![]u8 {
    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);

    var formatted_identities: std.ArrayList([]u8) = .empty;
    defer {
        for (formatted_identities.items) |id| allocator.free(id);
        formatted_identities.deinit(allocator);
    }

    for (identities) |idnt| {
        const formatted = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}/{s}/{s}",
            .{ idnt.category, idnt.type, idnt.lang, idnt.name },
        );
        try formatted_identities.append(allocator, formatted);
    }

    std.mem.sort([]u8, formatted_identities.items, {}, struct {
        fn lessThan(_: void, a: []u8, b: []u8) bool {
            return std.mem.order(u8, a, b) == .lt;
        }
    }.lessThan);

    for (formatted_identities.items) |fid| {
        try buffer.appendSlice(allocator, fid);
        try buffer.append(allocator, '<');
    }

    const sorted_features = try allocator.alloc([]const u8, features.len);
    defer allocator.free(sorted_features);
    @memcpy(sorted_features, features);

    std.mem.sort([]const u8, sorted_features, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.order(u8, a, b) == .lt;
        }
    }.lessThan);

    for (sorted_features) |feat| {
        try buffer.appendSlice(allocator, feat);
        try buffer.append(allocator, '<');
    }

    // XEP-0128 Data Forms
    if (data_forms) |forms| {
        const sorted_forms = try allocator.alloc(DataForm, forms.len);
        defer allocator.free(sorted_forms);
        @memcpy(sorted_forms, forms);

        std.mem.sort(DataForm, sorted_forms, {}, struct {
            fn lessThan(_: void, a: DataForm, b: DataForm) bool {
                return std.mem.order(u8, a.form_type, b.form_type) == .lt;
            }
        }.lessThan);

        for (sorted_forms) |form| {
            try buffer.appendSlice(allocator, form.form_type);
            try buffer.append(allocator, '<');

            var valid_fields: std.ArrayList(FormField) = .empty;
            defer valid_fields.deinit(allocator);

            for (form.fields) |field| {
                if (std.mem.eql(u8, field.var_name, "FORM_TYPE")) continue;
                try valid_fields.append(allocator, field);
            }

            std.mem.sort(FormField, valid_fields.items, {}, struct {
                fn lessThan(_: void, a: FormField, b: FormField) bool {
                    return std.mem.order(u8, a.var_name, b.var_name) == .lt;
                }
            }.lessThan);

            // Append value of "var" attribute, followed by the '<' character.
            // For each <value/> element, append the XML character data, followed by the '<' character.
            for (valid_fields.items) |field| {
                try buffer.appendSlice(allocator, field.var_name);
                try buffer.append(allocator, '<');

                const sorted_values = try allocator.alloc([]const u8, field.values.len);
                defer allocator.free(sorted_values);
                @memcpy(sorted_values, field.values);

                std.mem.sort([]const u8, sorted_values, {}, struct {
                    fn lessThan(_: void, a: []const u8, b: []const u8) bool {
                        return std.mem.order(u8, a, b) == .lt;
                    }
                }.lessThan);

                for (sorted_values) |val| {
                    try buffer.appendSlice(allocator, val);
                    try buffer.append(allocator, '<');
                }
            }
        }
    }

    var digest: [32]u8 = undefined;
    var digest_len: usize = 0;

    switch (algo) {
        .sha1 => {
            var hash = crypto.hash.Sha1.init(.{});
            hash.update(buffer.items);
            hash.final(digest[0..20]);
            digest_len = 20;
        },
        .sha256 => {
            var hash = crypto.hash.sha2.Sha256.init(.{});
            hash.update(buffer.items);
            hash.final(digest[0..32]);
            digest_len = 32;
        },
    }

    const encoded_len = base64_encoder.calcSize(digest_len);
    const result = try allocator.alloc(u8, encoded_len);
    _ = base64_encoder.encode(result, digest[0..digest_len]);

    return result;
}

test "Simple Example" {
    const allocator = std.testing.allocator;

    const identities = [_]Identity{
        .{ .category = "client", .type = "pc", .lang = "", .name = "Exodus 0.9.1" },
    };

    const features = [_][]const u8{
        "http://jabber.org/protocol/caps",
        "http://jabber.org/protocol/disco#info",
        "http://jabber.org/protocol/disco#items",
        "http://jabber.org/protocol/muc",
    };

    const ver = try calculateVerificationString(allocator, &identities, &features, null, .sha1);
    defer allocator.free(ver);

    try std.testing.expectEqualStrings("QgayPKawpkPSDYmwT/WM94uAlu0=", ver);
}

test "Complex Example" {
    const allocator = std.testing.allocator;

    const identities = [_]Identity{
        .{ .category = "client", .type = "pc", .lang = "en", .name = "Psi 0.11" },
        .{ .category = "client", .type = "pc", .lang = "el", .name = "Ψ 0.11" },
    };

    const features = [_][]const u8{
        "http://jabber.org/protocol/caps",
        "http://jabber.org/protocol/disco#info",
        "http://jabber.org/protocol/disco#items",
        "http://jabber.org/protocol/muc",
    };

    const form_type_vals = [_][]const u8{"urn:xmpp:dataforms:softwareinfo"};
    const ip_version_vals = [_][]const u8{ "ipv4", "ipv6" };
    const os_vals = [_][]const u8{"Mac"};
    const os_version_vals = [_][]const u8{"10.5.1"};
    const software_vals = [_][]const u8{"Psi"};
    const software_version_vals = [_][]const u8{"0.11"};

    const fields = [_]FormField{
        .{ .var_name = "FORM_TYPE", .values = &form_type_vals },
        .{ .var_name = "ip_version", .values = &ip_version_vals },
        .{ .var_name = "os", .values = &os_vals },
        .{ .var_name = "os_version", .values = &os_version_vals },
        .{ .var_name = "software", .values = &software_vals },
        .{ .var_name = "software_version", .values = &software_version_vals },
    };

    const forms = [_]DataForm{
        .{
            .form_type = "urn:xmpp:dataforms:softwareinfo",
            .fields = &fields,
        },
    };

    const ver_psi = try calculateVerificationString(allocator, &identities, &features, &forms, .sha1);
    defer allocator.free(ver_psi);

    try std.testing.expectEqualStrings("q07IKJEyjvHSyhy//CH0CxmKi8w=", ver_psi);
}

