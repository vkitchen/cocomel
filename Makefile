CFLAGS = -Wall -Wextra -O2 -g

LDFLAGS = -lm -lz

HEADERS = \
	bst.h \
	char.h \
	dynamic_array_8.h \
	dynamic_array_64.h \
	dynamic_array_kv_32.h \
	dynamic_array_kv_64.h \
	file.h \
	hash_table.h \
	memory.h \
	posting.h \
	search.h \
	str.h \
	tar.h \
	tokenizer.h \
	tokenizer_zlib.h \
	vbyte.h

SRC = \
	bst.c \
	file.c \
	hash_table.c \
	memory.c \
	posting.c \
	search.c \
	tokenizer_zlib.c \
	vbyte.c

OBJECTS = $(SRC:.c=.o)

.SUFFIXES: .c .o

.c.o: $(HEADERS)
	$(CC) $(CFLAGS) -c $<

all: index search-cli search-cgi

# LDFLAGS at the end
# Might no longer occur now that we use index.o instead of index.cpp TODO
# https://stackoverflow.com/questions/9145177/undefined-reference-to-gzopen-error
index: index.o $(OBJECTS) $(HEADERS)
	$(CC) $(CFLAGS) -o $@ index.o $(OBJECTS) $(LDFLAGS)

search-cli: search_cli.o $(OBJECTS) $(HEADERS)
	$(CC) $(CFLAGS) -o $@ search_cli.o $(OBJECTS) $(LDFLAGS)

search-cgi: search_cgi.o $(OBJECTS) $(HEADERS)
	$(CC) $(CFLAGS) -o $@ search_cgi.o $(OBJECTS) $(LDFLAGS)

clean:
	rm -f index search-cli search-cgi $(OBJECTS) index.o search_cli.o search_cgi.o

