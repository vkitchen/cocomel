#include "stdlib.h"
#include "stdio.h"
#include <fstream>
#include <iostream>
#include <map>
#include <vector>
#include <string>

int main(void) {
	std::vector<std::string> docNos;
	std::map<std::string, std::vector<size_t>> postings;

	std::ifstream fh;
	fh.open("postings.dat", std::ios::binary);
	size_t docCount;
	fh.read((char *)&docCount, 8);
	for (size_t i = 0; i < docCount; i++) {
		size_t docNoSize;
		fh.read((char *)&docNoSize, 8);
		std::string docNo;
		docNo.resize(docNoSize);
		fh.read(&docNo[0], docNoSize);
		docNos.push_back(docNo);
	}
	size_t postingsLength;
	fh.read((char *)&postingsLength, 8);
	std::cout << "Postings Length: " << postingsLength << std::endl;
	for (size_t i = 0; i < postingsLength; i++) {
		size_t stringLength;
		fh.read((char *)&stringLength, 8);
		std::string word;
		word.resize(stringLength);
		fh.read(&word[0], stringLength);

		std::vector<size_t> docs;
		postings[word] = docs;

		size_t listLength;
		fh.read((char *)&listLength, 8);
		for (size_t j = 0; j < listLength; j++) {
			size_t listItem;
			fh.read((char *)&listItem, 8);
			postings[word].push_back(listItem);
		}
	}
	fh.close();

	std::cout << "Waiting for input" << std::endl;

	std::string in;
	std::cin >> in;

	if (postings.count(in) > 0) {
		for (auto &doc : postings[in]) {
			std::cout << docNos[doc] << std::endl;
		}
	} else {
		std::cout << "::No Results::";
		std::cout << in;
	}

	return 0;
}
