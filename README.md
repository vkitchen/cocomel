# Cocomel - A Term-at-a-time Search Engine Written In Zig

## Copying

This project is licensed under the ISC License

## Usage

The file to be indexed must contain documents in XML or HTML concated together, each prefixed with a `<DOCNO>identifier</DOCNO>` tag.

There are two programs. Index and search. Index builds an index over the documents. Search takes terms from stdin and outputs two columns, the document id and the relevancy score

## Done

* BM25 ranking
* Multi term search

## Todo

* Impact ordering
* Snippeting
* Phrase search
* Daemon mode
* Speed improvements
