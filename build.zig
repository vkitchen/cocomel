const Builder = @import("std").build.Builder;
const Mode = @import("std").builtin.Mode;
const CrossTarget = @import("std").zig.CrossTarget;

pub fn build(b: *Builder) !void {
    const indexer = b.addExecutable("index", "src/index_cli.zig");
    indexer.setBuildMode(Mode.ReleaseFast);
    indexer.install();

    const daemon = b.addExecutable("daemon", "src/daemon.zig");
    daemon.setBuildMode(Mode.ReleaseSafe);
    daemon.install();

    const client = b.addExecutable("client", "src/client.zig");
    client.setBuildMode(Mode.ReleaseSafe);
    client.install();

    const search = b.addExecutable("search", "src/search_cli.zig");
    search.setBuildMode(Mode.ReleaseSafe);
    search.install();

    const cgi = b.addExecutable("search-recipes", "src/search_cgi.zig");
    cgi.setTarget(try CrossTarget.parse(.{ .arch_os_abi = "x86_64-linux-musl" }));
    cgi.setBuildMode(Mode.ReleaseFast);
    cgi.install();

    const client_cgi = b.addExecutable("search-recipes", "src/client_cgi.zig");
    client_cgi.setTarget(try CrossTarget.parse(.{ .arch_os_abi = "x86_64-linux-musl" }));
    client_cgi.setBuildMode(Mode.ReleaseFast);
    client_cgi.install();

    const test_step = b.step("test", "Run tests");
    const unit_tests = b.addTest("src/test.zig");
    test_step.dependOn(&unit_tests.step);
}
