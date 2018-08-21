#include <stdio.h>
#include <stdlib.h>
#include "flexarray.h"

struct flexarrayrec {
    int capacity;
    int itemcount;
    void **items;
};

flexarray flexarray_new(int capacity)
{
    flexarray f = malloc(sizeof(*f));
    f->capacity = capacity;
    f->itemcount = 0;
    f->items = malloc(capacity * sizeof(f->items[0]));
    return f;
}

void flexarray_append(flexarray f, void *item)
{
    if (f->itemcount == f->capacity) {
        f->capacity *= 2;
        f->items = realloc(f->items, f->capacity * sizeof(f->items[0]));
    }
    f->items[f->itemcount++] = item;
}

void flexarray_print(flexarray f, FILE *stream)
{
    for (int i = 0; i < f->itemcount; i++) {
        if (f->items[i] == NULL) {
            fprintf(stream, "NULL\n");
        } else {
            fprintf(stream, "%p\n", f->items[i]);
        }
    }
}

int flexarray_length(flexarray f)
{
    return f->itemcount;
}


void *flexarray_get(flexarray f, int pos)
{
    if (pos >= 0 && pos < f->itemcount) {
        return f->items[pos];
    } else if (pos < 0 && -pos <= f->itemcount) {
        return f->items[f->itemcount + pos];
    } else {
        fprintf(stderr, "Out of bounds flexarray_get access\n");
        exit(EXIT_FAILURE);
    }
}

void flexarray_remove(flexarray f, int pos)
{
    if (pos >= f->itemcount) {
        fprintf(stderr, "Out of bounds flexarray_remove access\n");
        exit(EXIT_FAILURE);
    }
    for (int i = pos + 1; i < f->itemcount; i++) {
        f->items[i - 1] = f->items[i];
    }
    f->itemcount--;
}

void flexarray_free(flexarray f)
{
    free(f->items);
    free(f);
}
