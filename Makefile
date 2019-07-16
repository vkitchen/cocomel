
CXXFLAGS := -Wall -Wextra -O2 -g -std=c++11

LDFLAGS := -lm -lz

HEADERS := \
	bst.h \
	dynamic_array.h \
	hash_table.h \
	str.h

SRC := \
	file.cpp \
	memory.cpp \
	posting.cpp \
	tokenizer.cpp \
	tokenizer_zlib.cpp \
	vbyte.cpp

OBJECTS := $(SRC:%.cpp=%.o)

%.o: %.cpp %.h $(HEADERS)
	$(CXX) $(CXXFLAGS) -c $< -o $@

all: index search

index: index.cpp $(OBJECTS) $(HEADERS)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o $@ index.cpp $(OBJECTS)

search: search.cpp $(OBJECTS) $(HEADERS)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o $@ search.cpp $(OBJECTS)

CLEAN := $(OBJECTS) index search
clean:
	rm -f $(CLEAN)

