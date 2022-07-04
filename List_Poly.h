/*************************************************************
 *
 *  List_Poly.h
 *  Created by LinLin on 2019/9/24.
 *  Copyright © 2019 LinLin. All rights reserved.
 *
 *************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#ifndef C_LIST_POLY_H
#define C_LIST_POLY_H

typedef struct PolyNode {
    float Coef;      //系数
    int Expn;      //指数
    struct PolyNode* Next;
} PolyNode, * PolyList;

#define NewPolyList() ({\
	    PolyList __list = malloc(sizeof(PolyNode));\
	    assert(__list);\
	    __list->Next = NULL;\
	    __list;\
	})

#define NewPolyNode(coef, expn) ({\
	    PolyNode* __NewNode = NewPolyList();\
	    __NewNode->Coef = (coef);\
	    __NewNode->Expn = (expn);\
	    __NewNode;\
	})

#define PolyCreate() ({\
        PolyList __list = NewPolyList();\
        int count;\
        scanf("%d", &count);\
        while (count--) {\
            float coef;\
            int expn;\
            scanf("%f%d", &coef, &expn);\
            PolyInsert(__list, coef, expn);\
        }\
        __list;\
	})

#define PolyFindPrevious(list, expn) ({\
        PolyNode* __Position = (list);\
        int __expn = (expn);\
        while (__Position->Next && __Position->Next->Expn != __expn) {\
            __Position = __Position->Next;\
        }\
        __Position;\
    })

#define PolyFind(list, expn) ({\
        PolyFindPrevious((list), (expn))->Next;\
    })

#define PolyRemove(list, expn) ({\
        PolyNode* __Previous = PolyFindPrevious((list), (expn));\
        PolyNode* __RemoveNode = __Previous->Next;\
        if (__RemoveNode) {\
            __Previous->Next = __RemoveNode->Next;\
           free(__RemoveNode);\
        }\
        !!(__RemoveNode);\
    })

#define PolyInsert(list, coef, expn) do {\
	    float __coef = (coef);\
	    int __expn = (expn);\
	    if (!__coef)\
	        break;\
	    PolyNode* __Position = (list);\
	    while (__Position->Next && __Position->Next->Expn < __expn) {\
	        __Position = __Position->Next;\
	    }\
	    if (__Position->Next && __Position->Next->Expn == __expn) {\
	        __Position->Next->Coef += __coef;\
	        if (!__Position->Next->Coef) {\
                PolyNode* __RemoveNode = __Position->Next;\
                __Position->Next = __RemoveNode->Next;\
                free(__RemoveNode);\
	        }\
	    }\
	    else {\
	        \
	        PolyNode* __NextNode = __Position->Next;\
	        __Position = __Position->Next = NewPolyNode(__coef, __expn);\
	        __Position->Next = __NextNode;\
	    }\
	} while(0)

#define PolyArithmetic(PolyA, PolyB, flag) ({\
	    PolyList __PolyA = PolyA->Next, __PolyB = PolyB->Next;\
	    PolyList __PolyResult = NewPolyList();\
	    PolyList __PolyList = __PolyResult;\
	    while (__PolyA && __PolyB) {\
	        if (__PolyA->Expn == __PolyB->Expn) {\
	            float __coef = flag ? __PolyA->Coef + __PolyB->Coef : __PolyA->Coef - __PolyB->Coef;\
	            if (__coef) {\
	                __PolyResult = __PolyResult->Next = NewPolyNode(__coef, __PolyA->Expn);\
	            }\
	            __PolyA = __PolyA->Next;\
	            __PolyB = __PolyB->Next;\
	        }\
	        else {\
	            if (__PolyA->Expn < __PolyB->Expn) {\
	                __PolyResult = __PolyResult->Next = NewPolyNode(__PolyA->Coef, __PolyA->Expn);\
	                __PolyA = __PolyA->Next;\
	            }\
	            else {\
	                __PolyResult = __PolyResult->Next = NewPolyNode(flag ? __PolyB->Coef : -__PolyB->Coef, __PolyB->Expn);\
	                __PolyB = __PolyB->Next;\
	            }\
	        }\
	    }\
	    while (__PolyA) {\
	        __PolyResult = __PolyResult->Next = NewPolyNode(__PolyA->Coef, __PolyA->Expn);\
	        __PolyA = __PolyA->Next;\
	    }\
	    while (__PolyB) {\
	        __PolyResult = __PolyResult->Next = NewPolyNode(flag ? __PolyB->Coef : -__PolyB->Coef, __PolyB->Expn);\
	        __PolyB = __PolyB->Next;\
	    }\
	    __PolyList;\
	})

#define PolyAdd(PolyA, PolyB) PolyArithmetic(PolyA, PolyB, 1)

#define PolySubtract(PolyA, PolyB) PolyArithmetic(PolyA, PolyB, 0)

#define PolyDisplay(list) do {\
	    const PolyNode* __Position = (list)->Next;\
	    if (__Position) {\
	        float __coef = __Position->Coef;\
	        printf("%.*fx(%d)", __coef != (int)__coef, __coef, __Position->Expn);\
	        __Position = __Position->Next;\
	    }\
	    while (__Position) {\
	        float __coef = __Position->Coef;\
	        printf("%+.*fx(%d)", __coef != (int)__coef, __coef, __Position->Expn);\
	        __Position = __Position->Next;\
	    }\
	    putchar(10);\
	} while(0)

#endif //C_LIST_POLY_H
