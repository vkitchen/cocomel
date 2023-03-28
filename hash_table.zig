//	HASH_TABLE.ZIG
//	--------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");

const BST = struct
	{
	key: []const u8,
	left: ?*BST,
	right: ?*BST,
	};

fn bst_init(b: *BST, key: []const u8) void
	{
	b.left = null;
	b.right = null;
	b.key = key;
	}

fn bst_insert(root: *BST, allocator: std.mem.Allocator, key: []const u8) !void
	{
	var b = root;
	while (true)
		{
		const cmp = std.mem.order(u8, key, b.key);

		if (cmp == .lt)
			{
			if (b.left == null)
				{
				b.left = try allocator.create(BST);
				bst_init(b.left.?, key);
				return;
				}
			b = b.left.?;
			}
		else if (cmp == .gt)
			{
			if (b.right == null)
				{
				b.right = try allocator.create(BST);
				bst_init(b.right.?, key);
				return;
				}
			b = b.right.?;
			}
		else // |cmp == 0|
			{
			return;
			}
		}
	}

const HTCAP = 1 << 16;

pub const HashTable = struct
	{
	store: [HTCAP]?*BST,
	};

fn hash(key: []const u8) u32
	{
	var result: u32 = 0;
	
	for (key) |c|
		result = (c + 31 * result);

	return result & (HTCAP - 1);
	}

pub fn init(h: *HashTable) void
	{
	var i: usize = 0;
	while (i < HTCAP) : (i += 1)
		{
		h.store[i] = null;
		}
	}

pub fn insert(h: *HashTable, allocator: std.mem.Allocator, key: []const u8) !void
	{
	var index = hash(key);
	if (h.store[index] == null)
		{
		h.store[index] = try allocator.create(BST);
		bst_init(h.store[index].?, key);
		}
	else
		try bst_insert(h.store[index].?, allocator, key);
	}
