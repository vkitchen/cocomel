
.SUFFIXES: .c .h .o

CFLAGS := -Wall -Wextra -O2 -g

SRC := \
	memory.c \
	stdlib2/string2.c \
	stdlib2/file.c \
	flexarray.c \
	htable_kv.c \
	vector.c \
	vector_kv.c \
	linked_vector_kv.c \
	bst_kv.c \
	postings.c \
	vbyte.c


HEADERS := \
	memory.h \
	stdlib2/string2.h	\
	stdlib2/file.h \
	htable_kv.h \
	vector.h \
	vector_kv.h \
	linked_vector_kv.h \
	bst_kv.h \
	postings.h \
	vbyte.h


OBJECTS := $(SRC:%.c=%.o)

%.o: %.c $(HEADERS)
	$(CC) $(CFLAGS) -c $< -o $@

all: index search

index: index.c $(OBJECTS)
	$(CC) $(CFLAGS) -o $@ index.c $(OBJECTS)

search: search.c $(OBJECTS)
	$(CC) $(CFLAGS) -o $@ search.c $(OBJECTS)

CLEAN := $(OBJECTS) index search
clean:
	rm -f $(CLEAN)

