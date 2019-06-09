#include <cstdlib>
#include <cstring>
#include <utility>
#include "vbyte.h"
#include "dynamic_array.h"
#include "posting.h"

posting::posting() {
	id_capacity = 256;
	id_length = 0;
	id_store = (uint8_t *)malloc(id_capacity * sizeof(uint8_t));
	counts = new dynamic_array<uint8_t>();
}

void posting::append(uint32_t id) {
	if (this->id == id) {
		uint8_t *count = counts->back();
		if (*count < 255)
			(*count)++;
	} else {
		if (id_capacity - id_length < 10) {
			id_capacity *= 2;
			id_store = (uint8_t *)realloc(id_store, id_capacity * sizeof(uint8_t));
		}
		id_length += vbyte_store(&id_store[id_length], id - this->id);

		counts->append(1);

		this->id = id;
	}
}

size_t posting::write(char *buffer) {
	size_t offset = 2 * sizeof(uint32_t);

	memcpy(&buffer[offset], id_store, id_length);
	offset += id_length;

	memcpy(&buffer[offset], counts->store, counts->length);
	offset += counts->length;

	((uint32_t *)buffer)[0] = id_length;
	((uint32_t *)buffer)[1] = counts->length;

	return offset;
}


dynamic_array<std::pair<size_t, double>> *posting::decompress() {
	size_t id_length = ((uint32_t *)this)[0];
	size_t count_length = ((uint32_t *)this)[1];
	uint8_t *id_store = (uint8_t *)this + 2 * sizeof(uint32_t);
	uint8_t *count_store = id_store + id_length;

	dynamic_array<std::pair<size_t, double>> *out = new dynamic_array<std::pair<size_t, double>>;
	size_t prevI = 0;
	uint32_t docI = 0;
	size_t di = 0;
	size_t ci = 0;
	while (ci < count_length && di < id_length) {
		di += vbyte_read(&id_store[di], &docI);
		docI += prevI;
		prevI = docI;
		size_t count = count_store[ci];
		out->append(std::make_pair(docI, count));
		ci++;
	}
	return out;
}
