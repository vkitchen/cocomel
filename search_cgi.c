#include <stdio.h>
#include <string.h>
#include "dynamic_array_kv_32.h"
#include "dynamic_array_kv_64.h"
#include "file.h"
#include "search.h"

static char *uri_encode(char *uri)
	{
	char reserved[] = "!*'();:@&=+$,?#[]"; // the slash / would normally be escaped but we already have it in the file name
	// can't expand more than three times size. TODO replace dirty hack
	char *out = (char *)malloc(strlen(uri) * 3);
	char *enc = out;
	for (; *uri != '\0'; uri++)
		if (strchr(reserved, *uri) == NULL)
			*enc++ = *uri;
		else
			enc += sprintf(enc, "%%%02X", *uri);
	*enc++ = '\0';
	return out;
	}

int main(void)
	{
	char *index;
	file_slurp("index.dat", &index);

	// Decode index
	struct dynamic_array_kv_32 docNos;
	dynamic_array_kv_32_init(&docNos);
	docNos.length = ((uint32_t *)index)[1];
	docNos.store = (uint32_t *)&index[2 * sizeof(uint32_t)];

	puts("Content-Type: text/html; charset=utf-8\n");

	puts("<!DOCTYPE html>");
	puts("<html>");
	puts("<head>");
	puts("<meta charset='utf-8'>");
	puts("<link rel='stylesheet' type='text/css' href='/main.css'>");
	puts("<title>cocomel search results - Vaughan.Kitchen</title>");
	puts("</head>");
	puts("<body>");
	puts("<h1 class='site-logo'><a href='/'>Vaughan Kitchen</a></h1>");
	puts("<h3>(leading a life un-styled)</h3>");
	puts("<h4>Site search powered by <a href='http://github.com/vkitchen/cocomel'>cocomel</a></h4>");
	puts("<form class='site-search' action='/cgi-bin/search' method='get'>");
	puts("<input type='text' name='search' placeholder='Search anything...'>");
	puts("<input type='submit' value='Search'>");
	puts("</form>");

	char *data = getenv("QUERY_STRING");
	if (data != NULL && data[0] != '\0')
		{
		char *line = (char *)malloc(strlen(data) + 1);
		line[0] = '\0';
		sscanf(data, "search=%s", line);
		if (line != NULL && line[0] != '\0')
			{
			struct dynamic_array_kv_64 *result_list = search(index, line);

			if (result_list == NULL)
				puts("No results");
			else
				{
				puts("<h4>Search results:</h4>");
				puts("<ul>");
				for (size_t i = 0; i < result_list->length; i++)
					{
					size_t docId = dynamic_array_kv_64_at(result_list, i)[0] - 1;
					printf("<li><a href='/%s'>%s</a></li>\n", uri_encode(index + dynamic_array_kv_32_at(&docNos, docId)[0]), index + dynamic_array_kv_32_at(&docNos, docId)[0]);
					}
				puts("</ul>");
				}
			}
		}

	puts("</body>");
	puts("</html>");

	return 0;
	}
