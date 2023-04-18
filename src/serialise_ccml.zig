//	SERIALISE_CCML.ZIG
//	------------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const Dictionary = @import("dictionary.zig").Dictionary;
const Doc = @import("dictionary.zig").Doc;
const Posting = @import("dictionary.zig").Posting;

const file_format = "cocomel v1\n";

fn writeDictionary(out: anytype, h: *Dictionary, bytes_written: *u32) !u32 {
    // Write contents
    for (h.store) |p, i| {
        if (p != null) {
            const posting = p.?;

            const term_offset = bytes_written.*;
            try out.writeIntNative(u16, @truncate(u16, posting.term.len));
            bytes_written.* += @sizeOf(u16);
            try out.writeAll(posting.term);
            bytes_written.* += @truncate(u32, posting.term.len);

            const ids_offset = bytes_written.*;
            try out.writeIntNative(u32, @truncate(u32, posting.ids.items.len));
            bytes_written.* += @sizeOf(u32);
            for (posting.ids.items) |id| {
                try out.writeIntNative(u32, id);
                bytes_written.* += @sizeOf(u32);
            }

            const freqs_offset = bytes_written.*;
            try out.writeIntNative(u32, @truncate(u32, posting.freqs.items.len));
            bytes_written.* += @sizeOf(u32);
            for (posting.freqs.items) |freq| {
                try out.writeIntNative(u8, freq);
                bytes_written.* += @sizeOf(u8);
            }

            try out.writeIntNative(u32, term_offset);
            try out.writeIntNative(u32, ids_offset);
            try out.writeIntNative(u32, freqs_offset);
            h.store[i] = @intToPtr(*Posting, bytes_written.*);
            bytes_written.* += @sizeOf(u32) * 3;
        }
    }

    // Write table
    const table_offset = bytes_written.*;
    try out.writeIntNative(u32, h.cap);
    bytes_written.* += @sizeOf(u32);

    for (h.store) |p| {
        try out.writeIntNative(u32, @truncate(u32, @ptrToInt(p.?)));
        bytes_written.* += @sizeOf(u32);
    }

    std.debug.print("Terms count {d}\n", .{h.len});

    return table_offset;
}

pub fn write(out: anytype, docs: *std.ArrayList(Doc), dictionary: *Dictionary, snippets_indices: *std.ArrayList(u32)) !u32 {
    // Header
    try out.writeAll(file_format);
    var bytes_written: u32 = file_format.len;

    // Document ID strings
    for (docs.items) |d, i| {
        try out.writeIntNative(u32, d.len);
        try out.writeIntNative(u16, @truncate(u16, d.name.len));
        try out.writeAll(d.name);
        docs.items[i].name.ptr = @intToPtr([*]u8, bytes_written);
        bytes_written += @sizeOf(u32) + @sizeOf(u16);
        bytes_written += @truncate(u32, d.name.len);
    }

    // Document IDs array
    const docs_offset = bytes_written;
    try out.writeIntNative(u32, @truncate(u32, docs.items.len));
    bytes_written += @sizeOf(u32);
    for (docs.items) |d| {
        try out.writeIntNative(u32, @truncate(u32, @ptrToInt(d.name.ptr)));
        bytes_written += @sizeOf(u32);
    }

    // Dictionary
    const dictionary_offset = try writeDictionary(out, dictionary, &bytes_written);

    // Snippets
    const snippets_offset = bytes_written;
    try out.writeIntNative(u32, @truncate(u32, snippets_indices.items.len));
    for (snippets_indices.items) |s| {
        try out.writeIntNative(u32, s);
        bytes_written += @sizeOf(u32);
    }

    // Metadata
    try out.writeIntNative(u32, snippets_offset);
    try out.writeIntNative(u32, docs_offset);
    try out.writeIntNative(u32, dictionary_offset);
    bytes_written += 3 * @sizeOf(u32);

    return bytes_written;
}
