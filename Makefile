CXXFLAGS = -Wall -Wextra -O2 -g -std=c++11

LDFLAGS = -lm -lz

HEADERS = \
	bst.h \
	dynamic_array.h \
	hash_table.h \
	str.h

SRC = \
	file.cpp \
	memory.cpp \
	posting.cpp \
	search.cpp \
	tokenizer.cpp \
	tokenizer_zlib.cpp \
	vbyte.cpp

OBJECTS = $(SRC:.cpp=.o)

.SUFFIXES: .cpp .o

.cpp.o: $(HEADERS)
	$(CXX) $(CXXFLAGS) -c $<

all: index search-cli search-cgi

# LDFLAGS at the end
# Might no longer occur now that we use index.o instead of index.cpp TODO
# https://stackoverflow.com/questions/9145177/undefined-reference-to-gzopen-error
index: index.o $(OBJECTS) $(HEADERS)
	$(CXX) $(CXXFLAGS) -o $@ index.o $(OBJECTS) $(LDFLAGS)

search-cli: search_cli.o $(OBJECTS) $(HEADERS)
	$(CXX) $(CXXFLAGS) -o $@ search_cli.o $(OBJECTS) $(LDFLAGS)

search-cgi: search_cgi.o $(OBJECTS) $(HEADERS)
	$(CXX) $(CXXFLAGS) -o $@ search_cgi.o $(OBJECTS) $(LDFLAGS)

clean:
	rm -f index search-cli search-cgi $(OBJECTS)

