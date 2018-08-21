#ifndef FLEXARRAY_H_
#define FLEXARRAY_H_

typedef struct flexarrayrec *flexarray;

extern void flexarray_append(flexarray f, void *item);
extern void flexarray_free(flexarray f);
extern flexarray flexarray_new();
extern void flexarray_print(flexarray f, FILE *stream);
int flexarray_length(flexarray f);
void *flexarray_get(flexarray f, int pos);
void flexarray_remove(flexarray f, int pos);

#endif
