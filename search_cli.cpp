#include <stdio.h>
#include <utility>
#include "dynamic_array.h"
#include "file.h"
#include "search.h"

int main(void)
	{
	char *index;
	file_slurp("index.dat", &index);

	// Decode index
	dynamic_array<std::pair<uint32_t, uint32_t>> *docNos = new dynamic_array<std::pair<uint32_t, uint32_t>>();
	docNos->length = ((uint32_t *)index)[1];
	docNos->store = (std::pair<uint32_t, uint32_t> *)&index[2 * sizeof(uint32_t)];

	// Accept input
	char line[1024];
	if (fgets(line, sizeof(line), stdin) != NULL)
		{
		dynamic_array<std::pair<size_t, double>> *result_list = search(index, line);

		if (result_list == NULL)
			{
			printf("No results\n");
			exit(0);
			}

		for (size_t i = 0; i < result_list->length; i++)
			{
			size_t docId = result_list->store[i].first - 1;
			double rsv = result_list->store[i].second;
			printf("%s %f\n", index + docNos->store[docId].first, rsv);
			}

		}

	return 0;
	}
