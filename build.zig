const Builder = @import("std").build.Builder;
const Mode = @import("std").builtin.Mode;

pub fn build(b: *Builder) void {
    const indexer = b.addExecutable("indexer", "src/indexer.zig");
    indexer.setBuildMode(Mode.ReleaseFast);
    indexer.install();

    const search = b.addExecutable("search", "src/search.zig");
    search.setBuildMode(Mode.ReleaseFast);
    search.install();
}
