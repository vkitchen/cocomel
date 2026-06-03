const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});

    const clap = b.dependency("clap", .{});

    const indexer = b.addExecutable(.{
        .name = "index",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/prog_index.zig"),
            .target = target,
            .optimize = .ReleaseSafe,
        }),
    });
    indexer.root_module.addImport("clap", clap.module("clap"));
    b.installArtifact(indexer);

    const daemon = b.addExecutable(.{
        .name = "cocomel",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/prog_cocomel.zig"),
            .target = target,
            .optimize = .ReleaseSafe,
        }),
    });
    b.installArtifact(daemon);

    const search_client = b.addExecutable(.{
        .name = "client",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/prog_client.zig"),
            .target = target,
            .optimize = .ReleaseSafe,
        }),
    });
    b.installArtifact(search_client);

    const search_cli = b.addExecutable(.{
        .name = "search",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/prog_search.zig"),
            .target = target,
            .optimize = .ReleaseSafe,
        }),
    });
    b.installArtifact(search_cli);

    const stats = b.addExecutable(.{
        .name = "stats",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/prog_stats.zig"),
            .target = target,
            .optimize = .ReleaseSafe,
        }),
    });
    stats.root_module.addImport("clap", clap.module("clap"));
    b.installArtifact(stats);

    const test_step = b.step("test", "Run tests");
    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/test.zig"),
            .target = target,
        }),
    });
    test_step.dependOn(&unit_tests.step);
}
