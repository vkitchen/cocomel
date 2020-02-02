#include <stdio.h>
#include "dynamic_array_kv_32.h"
#include "dynamic_array_kv_64.h"
#include "file.h"
#include "search.h"

int main(void)
	{
	char *index;
	file_slurp("index.dat", &index);

	// Decode index
	struct dynamic_array_kv_32 docNos;
	dynamic_array_kv_32_init(&docNos);
	docNos.length = ((uint32_t *)index)[1];
	docNos.store = (uint32_t *)&index[2 * sizeof(uint32_t)];

	// Accept input
	char line[1024];
	if (fgets(line, sizeof(line), stdin) != NULL)
		{
		struct dynamic_array_kv_64 *result_list = search(index, line);

		if (result_list == NULL)
			{
			printf("No results\n");
			exit(0);
			}

		for (size_t i = 0; i < result_list->length; i++)
			{
			size_t docId = dynamic_array_kv_64_at(result_list, i)[0] - 1;
			double rsv = *(double *)&dynamic_array_kv_64_at(result_list, i)[1];
			printf("%s %f\n", index + dynamic_array_kv_32_at(&docNos, docId)[0], rsv);
			}

		}

	return 0;
	}

