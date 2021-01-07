# Cocomel - A search engine

## Copying

The project as a whole is licensed under the ISC License. The files `str_musl.h` and `char_musl.h` are derived from parts of the [musl libc](https://musl.libc.org/) and are licensed as MIT. The variable byte compression implementation comes from [libvbyte](https://github.com/cruppstahl/libvbyte) written by Cristoph Rupp and is licensed as Apache 2.0

## Building

Use make.

## Usage

The file to be indexed must contain documents in XML or HTML concated together, each prefixed with a `<DOCNO>identifier</DOCNO>` tag.

There are two programs. Index and search. Index builds an index over the document. Search takes terms from stdin and outputs two columns, the document id and the relevancy score. To index run `index document.xml`

## Done

* BM25 ranking
* Multi term searches

## Todo

* Snippets
* Phrase searching
* Run as a daemon
* General improvements
