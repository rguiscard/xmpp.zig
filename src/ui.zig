const std = @import("std");
const st = @import("strophe");
const zz = @import("zigzag");

selected_panel: u8,
conn: ?*st.xmpp_conn_t,

list: zz.List(Buddy),
input_mode: bool,
input: zz.TextInput,

const Self = @This();

const Buddy = struct {
    jid: []const u8,
    presense: []const u8,
};

pub const Msg = union(enum) {
    key: zz.KeyEvent,
};

pub fn init(self: *Self, ctx: *zz.Context) !zz.Cmd(Msg) {
    self.selected_panel = 0;

    self.list = zz.List(Buddy).init(ctx.persistent_allocator);
    self.list.multi_select = false;
    self.list.height = 10;
    const Item = zz.List(Buddy).Item;
    try self.list.addItem(Item.init(.{ .jid = "dummy@localhost", .presense = "offline" }, "Dummy"));

    self.input_mode = false;
    self.input = zz.TextInput.init(ctx.persistent_allocator);
    self.input.setPlaceholder("Enter new todo...");
    self.input.setPrompt("> ");
    return .none;
}

pub fn deinit(self: *Self) void {
    self.list.deinit();
    self.input.deinit();
}

pub fn update(self: *Self, msg: Msg, _: *zz.Context) zz.Cmd(Msg) {
    switch (msg) {
        .key => |k| {
            if (self.input_mode) {
                switch (k.key) {
                    .escape => {
                        self.input_mode = false;
                        self.input.setValue("") catch {};
                    },
                    .enter => {
                        if (self.input.getValue().len > 0) {
                            //                                const new_id: u32 = @intCast(self.list.items.items.len + 1);
                            //                               const title = ctx.persistent_allocator.dupe(u8, self.input.getValue()) catch return .none;
                            //                              const Item = zz.List(Todo).Item;
                            //                             self.list.addItem(Item.init(.{ .id = new_id, .done = false }, title)) catch {
                            //                                ctx.persistent_allocator.free(title);
                            //                               return .none;
                            //                          };
                            //                         self.owned_titles.append(title) catch {
                            //                            _ = self.list.items.pop();
                            //                           self.list.updateFilter() catch {};
                            //                          ctx.persistent_allocator.free(title);
                            //                         return .none;
                            //                    };
                            //                   self.input.setValue("") catch {};
                        }
                        self.input_mode = false;
                    },
                    else => self.input.handleKey(k),
                }
            } else {
                switch (k.key) {
                    .char => |c| switch (c) {
                        'q' => {
                            st.xmpp_disconnect(self.conn);
                            //                    return .quit;
                            return .none;
                        },
                        '/' => self.input_mode = true,
                        '1' => self.selected_panel = 0,
                        '2' => self.selected_panel = 1,
                        '3' => self.selected_panel = 2,
                        else => {},
                    },
                    .tab => {
                        self.selected_panel = (self.selected_panel + 1) % 3;
                    },
                    .escape => return .quit,
                    else => {},
                }
            }
        },
    }
    return .none;
}

pub fn view(self: *const Self, ctx: *const zz.Context) ![]const u8 {
    const alloc = ctx.allocator;
    const w: u16 = @intCast(@min(ctx.width, std.math.maxInt(u16)));
    const h: u16 = @intCast(@min(ctx.height, std.math.maxInt(u16)));

    // Outer vertical layout: header(3) | body(fill) | input(3) | footer(3)
    const rows = zz.flex.layout(alloc, w, h, &.{
        .{ .constraint = .{ .fixed = 3 } },
        .{ .constraint = .fill },
        .{ .constraint = .{ .fixed = 3 } },
        .{ .constraint = .{ .fixed = 3 } },
    }, .{ .direction = .column }) catch return "layout error";

    // Body horizontal layout: sidebar(20%) | main(fill)
    const cols = zz.flex.layout(alloc, rows[1].width, rows[1].height, &.{
        .{ .constraint = .{ .percentage = 20 } },
        .{ .constraint = .fill },
    }, .{ .direction = .row, .gap = 1 }) catch return "layout error";

    // -- Render each panel into styled boxes --

    // Header
    const header = renderPanel(alloc, "Dashboard", rows[0].width, rows[0].height, zz.Color.cyan, true);

    // Sidebar
    const sidebar_items =
        "  [1] Overview\n" ++
        "  [2] Metrics\n" ++
        "  [3] Settings";
    const sidebar = renderPanel(alloc, sidebar_items, cols[0].width, cols[0].height, zz.Color.magenta, self.selected_panel == 0);

    // Main content area
    const main_text = switch (self.selected_panel) {
        0 => "Welcome to the ZigZag dashboard.\n\nThis layout is built with the\nflexbox constraint engine.\n\nPress 1/2/3 or Tab to navigate.",
        1 => "CPU: 42%\nMemory: 1.2 GB / 8 GB\nDisk: 120 GB / 500 GB\nUptime: 3d 14h 22m",
        2 => "Theme: Dark\nRefresh: 5s\nNotifications: On",
        else => "",
    };
    const main_panel = renderPanel(alloc, main_text, cols[1].width, cols[1].height, zz.Color.green, self.selected_panel == 1);

    // Input
    const input_line = if (self.input_mode)
        try self.input.view(ctx.allocator)
    else
        "";
    const input = renderPanel(alloc, input_line, rows[1].width, rows[1].height, zz.Color.cyan, true);

    // Footer
    var help_style = zz.Style{};
    help_style = help_style.fg(zz.Color.gray(12));
    help_style = help_style.inline_style(true);
    const footer_text = try help_style.render(alloc, "Tab: cycle panels  1/2/3: select panel  q: quit");
    const footer = renderPanel(alloc, footer_text, rows[2].width, rows[2].height, zz.Color.gray(8), false);

    // Compose the body row: sidebar | main
    const body = try zz.join.horizontal(alloc, .top, &.{ sidebar, main_panel });

    // Stack vertically
    return zz.join.vertical(alloc, .left, &.{ header, body, input, footer });
}

fn renderPanel(alloc: std.mem.Allocator, content: []const u8, w: u16, h: u16, border_color: zz.Color, highlight: bool) []const u8 {
    var s = zz.Style{};
    s = s.borderAll(zz.Border.rounded);
    if (highlight) {
        s = s.borderForeground(border_color);
    } else {
        s = s.borderForeground(zz.Color.gray(6));
    }
    // Account for border (2 cells each side)
    const inner_w: u16 = if (w > 4) w - 4 else 1;
    const inner_h: u16 = if (h > 2) h - 2 else 1;
    s = s.width(inner_w);
    s = s.height(inner_h);
    return s.render(alloc, content) catch content;
}
