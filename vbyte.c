#include <stdint.h>

int vbyte_store(uint8_t *p, uint64_t value)
{
	if (value < (1lu << 7)) {
		*p = value & 0x7Fu;
		return 1;
	}
	if (value < (1lu << 14)) {
		*p = (value & 0x7Fu) | (1u << 7);
		++p;
		*p = value >> 7;
		return 2;
	}
	if (value < (1lu << 21)) {
		*p = (value & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 7) & 0x7Fu) | (1u << 7);
		++p;
		*p = value >> 14;
		return 3;
	}
	if (value < (1lu << 28)) {
		*p = (value & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 7) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 14) & 0x7Fu) | (1u << 7);
		++p;
		*p = value >> 21;
		return 4;
	}
	if (value < (1lu << 35)) {
		*p = (value & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 7) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 14) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 21) & 0x7Fu) | (1u << 7);
		++p;
		*p = value >> 28;
		return 5;
	}
	if (value < (1lu << 42)) {
		*p = (value & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 7) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 14) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 21) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 28) & 0x7Fu) | (1u << 7);
		++p;
		*p = value >> 35;
		return 6;
	}
	if (value < (1lu << 49)) {
		*p = (value & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 7) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 14) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 21) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 28) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 35) & 0x7Fu) | (1u << 7);
		++p;
		*p = value >> 42;
		return 7;
	}
	if (value < (1lu << 56)) {
		*p = (value & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 7) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 14) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 21) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 28) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 35) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 42) & 0x7Fu) | (1u << 7);
		++p;
		*p = value >> 49;
		return 8;
	}
	if (value < (1lu << 63)) {
		*p = (value & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 7) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 14) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 21) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 28) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 35) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 42) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 49) & 0x7Fu) | (1u << 7);
		++p;
		*p = value >> 56;
		return 9;
	}
	else {
		*p = (value & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 7) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 14) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 21) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 28) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 35) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 42) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 49) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 56) & 0x7Fu) | (1u << 7);
		++p;
		*p = value >> 63;
		return 10;
	}
}
