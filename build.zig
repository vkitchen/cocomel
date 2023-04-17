const Builder = @import("std").build.Builder;
const Mode = @import("std").builtin.Mode;
const CrossTarget = @import("std").zig.CrossTarget;

pub fn build(b: *Builder) !void {
    const indexer = b.addExecutable("index", "src/indexer.zig");
    indexer.setBuildMode(Mode.ReleaseFast);
    indexer.install();

    const search = b.addExecutable("search", "src/search_cli.zig");
    search.setBuildMode(Mode.ReleaseFast);
    search.install();

    const cgi = b.addExecutable("search-recipes", "src/search_cgi.zig");
    cgi.setTarget(try CrossTarget.parse(.{ .arch_os_abi = "x86_64-linux-musl" }));
    cgi.setBuildMode(Mode.ReleaseFast);
    cgi.install();

    const test_step = b.step("test", "Run tests");
    const unit_tests = b.addTest("src/stem_s.zig");
    test_step.dependOn(&unit_tests.step);
}
