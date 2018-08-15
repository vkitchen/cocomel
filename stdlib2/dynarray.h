#ifndef DYNARRAY_H_
#define DYNARRAY_H_

#define dynarray_typedef(content_type__, content_type_name__)				\
typedef struct {																											\
	size_t capacity;																										\
	size_t count;																											\
	content_type__ *items;																							\
} content_type_name__


#define dynarray_append(a, value) do {														\
	if ((a)->items == NULL) {																							\
		(a)->capacity = 2;																									\
		(a)->count = 0;																											\
		(a)->items = malloc((a)->capacity * sizeof((a)->items[0]));					\
	}																																			\
	if ((a)->count == (a)->capacity) {																			\
		(a)->capacity += (a)->capacity;																			\
		(a)->items = realloc((a)->items, (a)->capacity * sizeof((a)->items[0]));	\
	}																																	\
	(a)->items[(a)->count++] = (value);																			\
} while(0)


#define dynarray_swap_remove(a, index) do {																	\
	if (!((a)->items == NULL && (a)->count == 0)) {														\
		(a)->items[index] = (a)->items[--(a)->count];														\
	}																																					\
} while(0)


#define dynarray_free(a) free((a)->items)

#endif
