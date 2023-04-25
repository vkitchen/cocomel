//	SERIALISE_CCML.ZIG
//	------------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const Dictionary = @import("dictionary.zig").Dictionary;
const Doc = @import("Doc.zig");
const Posting = @import("dictionary.zig").Posting;

const file_format = "cocomel v1\n";

fn writeDictionary(out: std.io.BufferedWriter(4096, std.fs.File.Writer).Writer, h: *Dictionary, bytes_written: *u32) !u32 {
    // Write contents
    for (h.store) |p| {
        if (p != null) {
            const posting = p.?;
            try posting.flush();

            const term_offset = bytes_written.*;
            try out.writeIntNative(u16, @truncate(u16, posting.term.len));
            try out.writeAll(posting.term);
            bytes_written.* += @sizeOf(u16) + @truncate(u32, posting.term.len);

            // df_t
            const ids_offset = bytes_written.*;
            try out.writeIntNative(u32, @truncate(u32, posting.df_t));
            bytes_written.* += @sizeOf(u32);
            // postings chunks
            var i: u8 = 255;
            while (i > 0) : (i -= 1) {
                if (posting.ids[i - 1] == null)
                    continue;
                var postings_list = posting.ids[i - 1].?;
                try out.writeIntNative(u32, @truncate(u32, postings_list.items.len));
                try out.writeIntNative(u8, i);
                try out.writeAll(postings_list.items);
                bytes_written.* += @sizeOf(u32) + @sizeOf(u8) + @truncate(u32, postings_list.items.len);
            }
            // If there is no impact 1 write a dummy postings list
            if (posting.ids[0] == null) {
                try out.writeIntNative(u32, 0);
                bytes_written.* += @sizeOf(u32);
            }

            posting.term.ptr = @intToPtr([*]u8, term_offset);
            posting.ids[0] = @intToPtr(*std.ArrayList(u8), ids_offset);
        }
    }

    // Write table
    const table_offset = bytes_written.*;
    try out.writeIntNative(u32, h.cap);
    bytes_written.* += @sizeOf(u32);

    for (h.store) |p| {
        if (p != null) {
            try out.writeIntNative(u32, @truncate(u32, @ptrToInt(p.?.term.ptr)));
            try out.writeIntNative(u32, @truncate(u32, @ptrToInt(p.?.ids[0])));
        } else {
            try out.writeIntNative(u64, 0);
        }
        bytes_written.* += 2 * @sizeOf(u32);
    }

    std.debug.print("Terms count {d}\n", .{h.len});

    return table_offset;
}

pub fn write(out: std.io.BufferedWriter(4096, std.fs.File.Writer).Writer, docs: *std.ArrayList(Doc), dictionary: *Dictionary, snippets_indices: *std.ArrayList(u32)) !u32 {
    // Header
    try out.writeAll(file_format);
    var bytes_written: u32 = file_format.len;

    // Document ID strings
    for (docs.items) |d, i| {
        try out.writeIntNative(u32, d.len);
        try out.writeIntNative(u16, @truncate(u16, d.name.len));
        try out.writeAll(d.name);
        if (d.title) |title| {
            try out.writeIntNative(u16, @truncate(u16, title.len));
            try out.writeAll(title);
        } else {
            try out.writeIntNative(u16, 0);
        }
        docs.items[i].name.ptr = @intToPtr([*]u8, bytes_written);
        bytes_written += @sizeOf(u32) + @sizeOf(u16) + @truncate(u32, d.name.len) + @sizeOf(u16);
        if (d.title) |title|
            bytes_written += @truncate(u32, title.len);
    }

    // Document IDs array
    const docs_offset = bytes_written;
    for (docs.items) |d| {
        try out.writeIntNative(u32, @truncate(u32, @ptrToInt(d.name.ptr)));
        bytes_written += @sizeOf(u32);
    }

    // Dictionary
    const dictionary_offset = try writeDictionary(out, dictionary, &bytes_written);

    // Snippets
    const snippets_offset = bytes_written;
    for (snippets_indices.items) |s| {
        try out.writeIntNative(u32, s);
        bytes_written += @sizeOf(u32);
    }

    // Metadata
    try out.writeIntNative(u32, @truncate(u32, docs.items.len));
    try out.writeIntNative(u32, docs_offset);
    try out.writeIntNative(u32, dictionary_offset);
    try out.writeIntNative(u32, snippets_offset);
    bytes_written += 4 * @sizeOf(u32);

    return bytes_written;
}
