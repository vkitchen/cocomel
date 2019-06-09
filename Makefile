
CXXFLAGS := -Wall -Wextra -O2 -g -lm -std=c++11

SRC := \
	tokenizer.cpp \
	memory.cpp \
	str.cpp \
	file.cpp \
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

