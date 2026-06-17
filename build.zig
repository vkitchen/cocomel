const std = @import("std");
const protobuf = @import("protobuf");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const clap_dep = b.dependency("clap", .{
        .target = target,
        .optimize = optimize,
    });
    const protobuf_dep = b.dependency("protobuf", .{
        .target = target,
        .optimize = optimize,
    });

    const translate_c = b.addTranslateC(.{
        .root_source_file = b.path("src/memset_avx2.h"),
        .target = target,
        .optimize = optimize,
    });
    const c_mod = translate_c.createModule();
    c_mod.addCSourceFile(.{
        .file = b.path("src/memset_avx2.c"),
    });

    const indexer = b.addExecutable(.{
        .name = "index",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/prog_index.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    indexer.root_module.addImport("clap", clap_dep.module("clap"));
    b.installArtifact(indexer);

    const daemon = b.addExecutable(.{
        .name = "cocomel",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/prog_cocomel.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{
                    .name = "c",
                    .module = c_mod,
                },
            },
        }),
    });
    b.installArtifact(daemon);

    const search_client = b.addExecutable(.{
        .name = "client",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/prog_client.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(search_client);

    const search_cli = b.addExecutable(.{
        .name = "search",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/prog_search.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{
                    .name = "c",
                    .module = c_mod,
                },
            },
        }),
    });
    b.installArtifact(search_cli);

    const search_trec = b.addExecutable(.{
        .name = "search-trec",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/prog_search_trec.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{
                    .name = "c",
                    .module = c_mod,
                },
            },
        }),
    });
    b.installArtifact(search_trec);

    const stats = b.addExecutable(.{
        .name = "stats",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/prog_stats.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    stats.root_module.addImport("clap", clap_dep.module("clap"));
    b.installArtifact(stats);

    const convert = b.addExecutable(.{
        .name = "convert",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/prog_convert.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    convert.root_module.addImport("protobuf", protobuf_dep.module("protobuf"));
    convert.root_module.addImport("clap", clap_dep.module("clap"));
    b.installArtifact(convert);

    const gen_proto = b.step("gen-proto", "Generates zig files from protocol buffer definitions");
    const protoc_step = protobuf.RunProtocStep.create(protobuf_dep.builder, target, .{
        .destination_directory = b.path("src/proto"),
        .include_directories = &.{b.path("proto")},
        .source_files = &.{
            b.path("proto/CommonIndexFileFormat.proto"),
        },
    });
    gen_proto.dependOn(&protoc_step.step);

    const test_step = b.step("test", "Run tests");
    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/test.zig"),
            .target = target,
        }),
    });
    test_step.dependOn(&unit_tests.step);
}
