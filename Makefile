
.SUFFIXES: .c .h .o

CFLAGS := -Wall -Wextra -O2 -g

SRC := \
	stdlib2/memory.c \
	stdlib2/string2.c \
	stdlib2/file.c


HEADERS := \
	stdlib2/memory.h \
	stdlib2/string2.h	\
	stdlib2/file.h


OBJECTS := $(SRC:%=%.o)

%.c.o: %.c $(HEADERS)
	$(CC) $(CFLAGS) -c $< -o $@

%.cpp.o: %.cpp $(HEADERS)
	$(CXX) $(CFLAGS) -c $< -o $@

all: index search

index: index.cpp $(OBJECTS)
	$(CXX) -o $@ index.cpp $(OBJECTS)

search: search.cpp $(OBJECTS)
	$(CXX) -o $@ search.cpp $(OBJECTS)

CLEAN := $(OBJECTS) index search
clean:
	rm -f $(CLEAN)

