
CXXFLAGS := -Wall -Wextra -O2 -g -lm -std=c++11

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
	vbyte.cpp

OBJECTS := $(SRC:%.cpp=%.o)

%.o: %.cpp %.h $(HEADERS)
	$(CXX) $(CXXFLAGS) -c $< -o $@

all: index search

index: index.cpp $(OBJECTS) $(HEADERS)
	$(CXX) $(CXXFLAGS) -o $@ index.cpp $(OBJECTS)

search: search.cpp $(OBJECTS) $(HEADERS)
	$(CXX) $(CXXFLAGS) -o $@ search.cpp $(OBJECTS)

CLEAN := $(OBJECTS) index search
clean:
	rm -f $(CLEAN)

