//	INDEX.ZIG
//	---------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const file = @import("file.zig");
const tokenizer = @import("tokenizer.zig");
const hashtable = @import("hash_table.zig");

const usage = \\
\\Usage: index [file ...]
\\
;

pub fn main() !void {
	var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
	defer arena.deinit();

	const allocator = arena.allocator();

	var args = try std.process.argsAlloc(allocator);
	defer std.process.argsFree(allocator, args);

	if (args.len < 2)
		{
		std.debug.print("{s}", .{usage});
		return;
		}


	std.debug.print("{s} {s}\n", .{args[0], args[1]});
	
	const doc = try file.slurp(allocator, args[1]);

	const tok = try allocator.create(tokenizer.Tokenizer);
	tokenizer.init(tok, doc);

	const dictionary = try allocator.create(hashtable.HashTable);
	hashtable.init(dictionary);

	while (true) {
		const t = tokenizer.next(tok);
		if (t.type == tokenizer.TokenType.eof) break;
		try hashtable.insert(dictionary, allocator, t.token);
		std.debug.print("Token: {s}\n", .{t.token});
	}
}
