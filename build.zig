const std = @import("std");

pub fn build(b: *std.Build) !void {
    const indexer = b.addExecutable(.{
        .name = "index",
        .root_source_file = .{ .path = "src/prog_index.zig" },
        .target = b.host,
        .optimize = .ReleaseFast,
    });
    b.installArtifact(indexer);

    const daemon = b.addExecutable(.{
        .name = "cocomel",
        .root_source_file = .{ .path = "src/prog_cocomel.zig" },
        .target = b.host,
        .optimize = .ReleaseSafe,
    });
    b.installArtifact(daemon);

    const search_client = b.addExecutable(.{
        .name = "client",
        .root_source_file = .{ .path = "src/prog_client.zig" },
        .target = b.host,
        .optimize = .ReleaseSafe,
    });
    b.installArtifact(search_client);

    const search_cli = b.addExecutable(.{
        .name = "search",
        .root_source_file = .{ .path = "src/prog_search.zig" },
        .target = b.host,
        .optimize = .ReleaseSafe,
    });
    b.installArtifact(search_cli);

    const test_step = b.step("test", "Run tests");
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/test.zig" },
        .target = b.host,
    });
    test_step.dependOn(&unit_tests.step);
}
