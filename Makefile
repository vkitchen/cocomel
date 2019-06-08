
CXXFLAGS := -Wall -Wextra -O2 -g -lm -std=c++11

SRC := \
	tokenizer.cpp \
	memory.cpp \
	string2.cpp \
	file.cpp \
	hash_table.cpp \
	vector.cpp \
	vector_kv.cpp \
	bst.cpp \
	posting.cpp \
	vbyte.cpp

OBJECTS := $(SRC:%.cpp=%.o)

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

all: index search

index: index.cpp $(OBJECTS)
	$(CXX) $(CXXFLAGS) -o $@ index.cpp $(OBJECTS)

search: search.cpp $(OBJECTS)
	$(CXX) $(CXXFLAGS) -o $@ search.cpp $(OBJECTS)

CLEAN := $(OBJECTS) index search
clean:
	rm -f $(CLEAN)

