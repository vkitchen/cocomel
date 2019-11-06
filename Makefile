
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

# LDFLAGS must go on the end
# https://stackoverflow.com/questions/9145177/undefined-reference-to-gzopen-error
index: index.cpp $(OBJECTS) $(HEADERS)
	$(CXX) $(CXXFLAGS) -o $@ index.cpp $(OBJECTS) $(LDFLAGS)

search-cli: search_cli.cpp $(OBJECTS) $(HEADERS)
	$(CXX) $(CXXFLAGS) -o $@ search_cli.cpp $(OBJECTS) $(LDFLAGS)

search-cgi: search_cgi.cpp $(OBJECTS) $(HEADERS)
	$(CXX) $(CXXFLAGS) -o $@ search_cgi.cpp $(OBJECTS) $(LDFLAGS)

CLEAN := $(OBJECTS) index search-cli search-cgi
clean:
	rm -f $(CLEAN)

