const Builder = @import("std").build.Builder;
const Mode = @import("std").builtin.Mode;
const CrossTarget = @import("std").zig.CrossTarget;

pub fn build(b: *Builder) !void {
    const indexer = b.addExecutable(.{
        .name = "index",
        .root_source_file = .{ .path = "src/prog_index.zig" },
        .optimize = Mode.ReleaseFast,
    });
    b.installArtifact(indexer);

    const daemon = b.addExecutable(.{
        .name = "cocomel",
        .root_source_file = .{ .path = "src/prog_cocomel.zig" },
        .optimize = Mode.ReleaseSafe,
    });
    b.installArtifact(daemon);

    const search_client = b.addExecutable(.{
        .name = "client",
        .root_source_file = .{ .path = "src/prog_client.zig" },
        .optimize = Mode.ReleaseSafe,
    });
    b.installArtifact(search_client);

    const search_cli = b.addExecutable(.{
        .name = "search",
        .root_source_file = .{ .path = "src/prog_search.zig" },
        .optimize = Mode.ReleaseSafe,
    });
    b.installArtifact(search_cli);

    const test_step = b.step("test", "Run tests");
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/test.zig" },
    });
    test_step.dependOn(&unit_tests.step);
}
