# Cocomel - A search engine

**coco**nut + cara**mel**

Cocomel is an [anytime](https://andrewtrotman.github.io/papers/2015-2.pdf) search engine used for research at the [University of Otago](https://www.otago.ac.nz/).

This puts it in the same family as [ATIRE](https://github.com/andrewtrotman/ATIRE/), [IOQP](https://github.com/JMMackenzie/IOQP/), [JASS](https://github.com/lintool/JASS), and [JASSv2](https://github.com/andrewtrotman/JASSv2/).

## Features

* Searches

## TODO

* Lots of stuff

## Compiling

You'll need to install Zig `0.16.0` then run `zig build -Doptimize=ReleaseFast`.
Other versions of Zig may work but remain untested.

## Usage

Cocomel can index from either a trec format `<DOC><DOCNO>DOC_001</DOCNO></DOC>` file or a folder of html files.
Conversion from [ciff](https://github.com/osirrc/ciff) is supported using the `convert` tool.
The indexer, search etc. can be found in `./zig-out/bin/` with usage described by the `--help` flag.
There is also a daemon `cocomel` and example `client`.
Indexing is a batch job and the daemon will need to be restarted to use a new index however this only takes a few seconds as the index is simply read not decompressed.

## Tuning

See `src/config.zig`.

## Acknowledgments

* [Andrew Trotman](https://andrewtrotman.github.io/) for teaching me most of what I know about search engines
* [Katelyn Harlan](https://github.com/Axiomatic314) for her insights into search engine performance
