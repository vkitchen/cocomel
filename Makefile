
.SUFFIXES: .c .h .o

CFLAGS := -Wall -Wextra -O2 -g

SRC := \
	stdlib2/memory.c \
	stdlib2/string2.c \
	stdlib2/file.c \
	index.c


HEADERS := \
	stdlib2/memory.h \
	stdlib2/string2.h	\
	stdlib2/file.h


OBJECTS := $(SRC:%.c=%.o)

%.o: %.c $(HEADERS)
	$(CC) $(CFLAGS) -c $< -o $@

index: $(OBJECTS)
	$(CC) -o $@ $(OBJECTS)

CLEAN := $(OBJECTS) index
clean:
	rm -f $(CLEAN)

