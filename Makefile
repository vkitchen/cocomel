
CFLAGS := -Wall -Wextra -O2 -g -lm

SRC := \
	tokenizer.c \
	memory.c \
	string2.c \
	file.c \
	flexarray.c \
	htable_kv.c \
	vector.c \
	vector_kv.c \
	linked_vector_kv.c \
	bst_kv.c \
	posting.c \
	postings.c \
	vbyte.c

OBJECTS := $(SRC:%.c=%.o)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

all: index search

index: index.c $(OBJECTS)
	$(CC) $(CFLAGS) -o $@ index.c $(OBJECTS)

search: search.c $(OBJECTS)
	$(CC) $(CFLAGS) -o $@ search.c $(OBJECTS)

CLEAN := $(OBJECTS) index search
clean:
	rm -f $(CLEAN)

