const Builder = @import("std").build.Builder;
const Mode = @import("std").builtin.Mode;
const CrossTarget = @import("std").zig.CrossTarget;

pub fn build(b: *Builder) !void {
    const indexer = b.addExecutable("index", "src/prog_index.zig");
    indexer.setBuildMode(Mode.ReleaseFast);
    indexer.install();

    const daemon = b.addExecutable("cocomel", "src/prog_cocomel.zig");
    daemon.setBuildMode(Mode.ReleaseSafe);
    daemon.install();

    const search_client = b.addExecutable("client", "src/prog_client.zig");
    search_client.setBuildMode(Mode.ReleaseSafe);
    search_client.install();

    const search_cli = b.addExecutable("search", "src/prog_search.zig");
    search_cli.setBuildMode(Mode.ReleaseSafe);
    search_cli.install();

    const test_step = b.step("test", "Run tests");
    const unit_tests = b.addTest("src/test.zig");
    test_step.dependOn(&unit_tests.step);
}
