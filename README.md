# Cocomel - A search engine

The impact ordered search engine that powers [potatocastles.com](https://potatocastles.com).
In the same family of search engines as [ATIRE](https://github.com/andrewtrotman/ATIRE/), [IOQP](https://github.com/JMMackenzie/IOQP/), [JASS](https://github.com/lintool/JASS), and [JASSv2](https://github.com/andrewtrotman/JASSv2/).
The potato castles website is [vkitchen/potatoes](https://github.com/vkitchen/potatoes) and the crawler is [vkitchen/crawler](https://github.com/vkitchen/crawler)

## Features

* Top-k retrieval
* Snippets

## TODO

* Retrieval past top-k
* Early termination
* Porter2 stemming
* Wildcard search
* Index from tar archives
* Phrase searching
* Thesaurus

## Notes

* CIFF conversion using `./zig-out/bin/convert` expects quantised CIFF. This can be achieved using [ciffTools](https://github.com/Axiomatic314/ciffTools/)

## Compiling

You'll need to install Zig `0.16.0` then run `zig build -Doptimize=ReleaseFast`.
Other versions of Zig including nightlies may or may not work but remain untested.
Zig is still pre-1.0 so expect breakages when attempting to build with other releases.

## Usage

Cocomel can index either the wsj collection or a folder of html files.
Usage can be found with `./zig-out/bin/index --help`.
Searching is performed with `./zig-out/bin/search`.
There is also a daemon `./zig-out/bin/cocomel` and client `./zig-out/bin/client`.
