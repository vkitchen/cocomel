CFLAGS = -Wall -Wextra -O2 -g

LDFLAGS = -lm -lz

HEADERS = \
	file.h \
	fucs.h

SRC = \
	file.c \
	fucs.c

OBJECTS = $(SRC:.c=.o)

.SUFFIXES: .c .o

.c.o: $(HEADERS)
	$(CC) $(CFLAGS) -c $<

all: main gen

main: main.o $(OBJECTS) $(HEADERS)
	$(CC) -o $@ main.o $(OBJECTS) $(LDFLAGS)

gen: gen.o file.o $(HEADERS)
	$(CC) -o $@ gen.o file.o $(LDFLAGS)

clean:
	rm -f main $(OBJECTS) main.o lookup_table.h

