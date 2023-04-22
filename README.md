# Cocomel - A search engine

This is the search engine which powers [potatocastles.com](http://potatocastles.com). If you're looking for the website it is here [vkitchen/potatoes](https://github.com/vkitchen/potatoes) and the crawler it is here [vkitchen/crawler](https://github.com/vkitchen/crawler)

## Why another search engine?

Because none of the others were in Zig?

In seriousness though there's not actually a great ecosystem of OpenSource search engines available (please prove me wrong). And what is available isn't typically intended for Web Search so I decided it would be easier to just start from scratch rather than adapt something. There is also of course the pedagogical advantage of doing everything yourself which is the main reason why I didn't just fork [JASSv2](https://github.com/andrewtrotman/JASSv2) (2-Clause BSD licensed) which does do a lot of what I wanted

What I want:
1. Designed for a single node (optimises raw performance rather than scaling out)
2. Fast queries and fast indexing (I only have the one machine to run it all on)
3. Low memory usage (there is a physical limit of RAM in the computer. I would like to index as much as possible in it)
4. No allocation after startup (the server shouldn't have to allocate to handle a request except for caching)
5. Simple (I don't want lots of complex features I won't use making the code hard to understand)
6. Advanced features (simple doesn't mean it can't do select things other search engines do poorly)
7. Specialised (this is a recipe search engine and should take advantage of that vertical)
8. Adaptable (it should be possible to repurpose it to other verticals without significant changes)

This project is still in its early stages but its making progress

## Development

Development is largely driven by the needs of the [potatocastles.com](http://potatocastles.com) website and is ordered by what is most pressing until it gets fully off the ground. However if you have interest contributing or using it for other use cases you're more than welcome and I'd love to hear from you

Currently the core of the search is working and most development is geared towards building out the feature set. This is largely extending upon the domains as currently exist and introducing concepts such as richer parsing, learn to rank, semantic search, improved snippeting etc. the things that make a search engine polished

## Compiling

You'll need to install Zig 0.10.1 and then run `zig build`. As of the time of writing this is the latest stable release and this project will be updated following new stable releases. Other versions of Zig including nightlies may or may not work but remain untested. Zig is still pre-1.0 so expect breakages when attempting to build with other releases

## Usage

Indexing is geared towards the output from a naive crawler. As such there is little support for the sort of file structure you may already have and you may need to do some processing in order to get them into a form which the index understands. It is intended in the future that the indexer will support indexing from a wider variety of files so that this is easier. At this stage though only a gzipped tarball is accepted where the contained filenames are equivalent to the desired URLs stripped of the `http://` prefix. After you have compressed your HTML files into this format run `./zig-out/bin/index websites.tar.gz` this will generate two files in the current directory named `index.ccml` and `snippets.ccml`. There are two search programs `./zig-out/bin/search` and `./zig-out/bin/search-recipes` these both expect the two index files to be in the current working directory when run. `search` is a cli program to test the search. `search-recipes` is a cgi binary for deployment to a webserver and is by default cross-compiled for Linux as that is what my webserver is hosted on
