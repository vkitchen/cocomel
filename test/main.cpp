#include <iostream>
#include <stdio.h>
#include <limits.h>
#include <time.h>
#include "bst.h"

int main(void)
	{
	bst *tree = new bst(rand() % 100);
	for (int i = 0; i < INT_MAX / 1024; i++)
		tree->insert(rand() % INT_MAX);
	std::cout << "::INORDER::" << std::endl;
	clock_t ibegin = clock();
	int icount = tree->inorder();
	clock_t iend = clock();
	double itime_spent = (double)(iend - ibegin) / CLOCKS_PER_SEC;
	std::cout << "::DESTRUCTIVE::" << std::endl;
	clock_t dbegin = clock();
	int dcount = tree->destructive();
	clock_t dend = clock();
	double dtime_spent = (double)(dend - dbegin) / CLOCKS_PER_SEC;
	printf("Inorder Printed: %d times in %f seconds\n", icount, itime_spent);
	printf("Destructive Printed: %d times in %f seconds\n", dcount, dtime_spent);
	//std::cout << "::LLPRINT::" << std::endl;
	//tree->llprint();
	return 0;
	}
