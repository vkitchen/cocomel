# Cocomel - A search engine

## Building

Use make. And a 64 bit Linux. Nothing else is guaranteed to work

## Usage

The file to be indexed must be named `document.xml` and contain documents in XML or HTML concated together, each prefixed with a `<DOCNO></DOCNO>` tag.

There are two programs. Index and search. Index builds an index over the document. Search takes terms from stdin and outputs two columns, the document id and the relevancy score.

## Done

* Naive ranking
* Multi term searches

## Todo

* Document-at-a-time searching
* Better ranking (BM25)
* Snippets
* Phrase searching
* Run as a daemon
* General improvements
