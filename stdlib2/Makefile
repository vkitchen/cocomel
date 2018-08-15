
.SUFFIXES: .c .h .o

CFLAGS := -Iexternal/Unity-2.4.0/src -I./ \
        -fPIC -Wall -Wpointer-sign

LDFLAGS := -fPIC


SRC := \
	tests/main.c  \
	file.c        \
	string2.c     \
	memory.c      \
	external/Unity-2.4.0/src/unity.c

OBJECTS := $(SRC:%.c=%.o)

.c.o:
	$(CC) $(CFLAGS) -c $< -o $@

unittest: $(OBJECTS)
	$(CC) $(LDFLAGS) -o $@ $(OBJECTS)

CLEAN := $(OBJECTS) unittest
clean:
	rm -f $(CLEAN)
