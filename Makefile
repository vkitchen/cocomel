
.SUFFIXES: .c .h .o

CFLAGS := -Wall -Wextra -O2 -g

SRC := \
	memory.c \
	stdlib2/string2.c \
	stdlib2/file.c \
	flexarray.c \
	rb_tree/rb_tree.c


HEADERS := \
	memory.h \
	stdlib2/string2.h	\
	stdlib2/file.h


OBJECTS := $(SRC:%=%.o)

%.c.o: %.c $(HEADERS)
	$(CC) $(CFLAGS) -c $< -o $@

%.cpp.o: %.cpp $(HEADERS)
	$(CXX) $(CFLAGS) -c $< -o $@

all: index search

index: index.c $(OBJECTS)
	$(CC) $(CFLAGS) -o $@ index.c $(OBJECTS)

search: search.cpp $(OBJECTS)
	$(CXX) $(CFLAGS) -o $@ search.cpp $(OBJECTS)

CLEAN := $(OBJECTS) index search
clean:
	rm -f $(CLEAN)

