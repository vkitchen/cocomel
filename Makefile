
.SUFFIXES: .c .h .o

CFLAGS := -Wall -Wextra -O2 -g

SRC := \
	memory.c \
	stdlib2/string2.c \
	stdlib2/file.c \
	flexarray.c \
	htable_kv.c \
	vector_kv.c \
	rbt_kv.c \
	posting.c


HEADERS := \
	memory.h \
	stdlib2/string2.h	\
	stdlib2/file.h \
	htable_kv.h \
	vector_kv.h \
	rbt_kv.h \
	posting.h


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

