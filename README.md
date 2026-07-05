# Cocomel - Smol web search

Cocomel is an experiment in searching the [smol web](https://erock.prose.sh/what-is-the-smol-web).
It's a simple search engine designed to be fast on a single node without any scale out complexity.

## What?

Cocomel performs disjunctive (OR) search unlike more common conjunctive (AND) search engines.
This puts it in the same family as [ATIRE](https://github.com/andrewtrotman/ATIRE/), [IOQP](https://github.com/JMMackenzie/IOQP/), [JASS](https://github.com/lintool/JASS), and [JASSv2](https://github.com/andrewtrotman/JASSv2/).
The key advantage of disjunctive search is the ability to [cap execution time](https://andrewtrotman.github.io/papers/2015-2.pdf) with a tailorable tradeoff between compute usage and results quality. The disadvantage is that additional query terms increases the results set rather than restricts it. This is mostly nullified by [BM25](https://en.wikipedia.org/wiki/Okapi_BM25) ranking.

Currently I'm using cocomel for recipe search at [potatocastles.com](https://potatocastles.com).

## Features

* Top-k retrieval
* Early termination
* Snippets

## TODO

* Retrieval past top-k
* Porter2 stemming
* Thesaurus

## Out of scope

* Phrase search - blows out index size
* Wildcard search - blows out execution time

## Compiling

You'll need to install Zig `0.16.0` then run `zig build -Doptimize=ReleaseFast`.
Other versions of Zig may work but are untested.

## Usage

Cocomel can index from either a trec format `<DOC><DOCNO>DOC_001</DOCNO></DOC>` file or a folder of html files.
Conversion from [ciff](https://github.com/osirrc/ciff) is also supported using the `convert` tool.
The indexer, search etc. can be found in `./zig-out/bin/` with usage described by the `--help` flag.
There is also a search daemon named `cocomel` and example `client`.
Indexing is a batch job and the daemon will need to be restarted to use a new index however this typically only takes a few seconds as searching is performed entirely within the compressed structure.

## Tuning

The default configuration is tuned towards performance with decent precision.
It should be sufficient for typical web search with few terms per query.

However here are some basic tuning tips for the values in `src/config.zig`:

* Lots of terms in query? Loss of precision? Set `AccumulatorType` to `u16` N.B. will reduce performance
* Index too large? Set `quantise_bits` to `6` N.B. will reduce precision
* Search taking too long? Set `SearchProportion` to `0.05` N.B. will reduce precision

## Acknowledgments

* [Andrew Trotman](https://andrewtrotman.github.io/) for teaching me most of what I know about search engines
* [Katelyn Harlan](https://github.com/Axiomatic314) for her insights into search engine performance
