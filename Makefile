
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
	search.cpp \
	tokenizer.cpp \
	tokenizer_zlib.cpp \
	vbyte.cpp

OBJECTS := $(SRC:%.cpp=%.o)

%.o: %.cpp %.h $(HEADERS)
	$(CXX) $(CXXFLAGS) -c $< -o $@

all: index search-cli search-cgi

index: index.cpp $(OBJECTS) $(HEADERS)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o $@ index.cpp $(OBJECTS)

search-cli: search_cli.cpp $(OBJECTS) $(HEADERS)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o $@ search_cli.cpp $(OBJECTS)

search-cgi: search_cgi.cpp $(OBJECTS) $(HEADERS)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o $@ search_cgi.cpp $(OBJECTS)

CLEAN := $(OBJECTS) index search-cli search-cgi
clean:
	rm -f $(CLEAN)

