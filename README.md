# Cocomel - A search engine

The score-at-a-time search engine that powers [potatocastles.com](https://potatocastles.com).
In the same family of search engines as [ATIRE](https://github.com/andrewtrotman/ATIRE/), [JASS](https://github.com/lintool/JASS), [JASSv2](https://github.com/andrewtrotman/JASSv2/), and [IOQP](https://github.com/JMMackenzie/IOQP/).
The potato castles website can be found here [vkitchen/potatoes](https://github.com/vkitchen/potatoes) and the crawler is [vkitchen/crawler](https://github.com/vkitchen/crawler)

## Why score-at-a-time?

As this is a hobby project and I have limited funds and only a single computer at my disposal making the best use of that computer is important.
The key advantage of score-at-a-time is that it easily lends itself towards [anytime ranking](https://andrewtrotman.github.io/papers/2015-2.pdf).
Processing is performed in descending impact order of (term, document) pairs where the documents about the least common terms in the query are considered first.
An initial result set is taken using the most relevant term in the query and is then expanded upon through the processing of additional terms or documents.
As this initial result set is a best approximation and is iteratively refined, processing can be aborted at anytime due to either server load or responsiveness requirements and relevant documents will be returned.
Instead of scaling out for availability cocomel is designed so that it will be possible (once implemented) to shed load by reducing the quality of the result set during peak traffic.
Outside of anytime ranking score-at-a-time offers two further advantages which are decreased tail latency, and a smaller index size reducing memory usage as the index is loaded into memory on startup.
The disadvantage of score-at-a-time is the lack of conjuctive queries (AND operator) compared to document-at-a-time leading to results which may confuse some users.

## Goals

1. Responsive
2. Low memory
3. Performant

## Features

* Snippets
* Top-k retrieval

## TODO

* Retrieval past top-k
* Early termination
* Porter2 stemming
* Wildcard search
* Index from tar archives
* Phrase searching
* Thesaurus
* Faster compression
* Handrolled CIFF parser

## Notes

* CIFF conversion using `./zig-out/bin/convert` expects quantised CIFF. This can be achieved using [ciffTools](https://github.com/Axiomatic314/ciffTools/)

## Compiling

You'll need to install Zig `0.16.0` then run `zig build -Doptimize=ReleaseSafe`.
Other versions of Zig including nightlies may or may not work but remain untested.
Zig is still pre-1.0 so expect breakages when attempting to build with other releases.

## Usage

Cocomel can index either the wsj collection or a folder of html files.
Usage can be found with `./zig-out/bin/index --help`.
Searching is performed with `./zig-out/bin/search`.
There is also a daemon `./zig-out/bin/cocomel` and client `./zig-out/bin/search-client`.
