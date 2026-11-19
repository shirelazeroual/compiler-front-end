/* ============================================================
   ast.h  -  the Abstract Syntax Tree (AST)
   A node has a name (like "FUNC", "+", "x") and a list of children.
   A node with no children is a leaf (a variable name, a number...).
   ============================================================ */
#ifndef AST_H
#define AST_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct node {
    char *name;               /* what is printed: "FUNC", "+", "x", "5" ... */
    struct node **child;      /* array of children                          */
    int count;                /* how many children                          */
} node;

/* create a new node with no children */
static node *mk(const char *name)
{
    node *n = (node *)malloc(sizeof(node));
    n->name  = strdup(name);
    n->child = NULL;
    n->count = 0;
    return n;
}

/* add one child at the end (does nothing if c is NULL) */
static node *add(node *parent, node *c)
{
    if (c == NULL)
        return parent;
    parent->child = (node **)realloc(parent->child, sizeof(node *) * (parent->count + 1));
    parent->child[parent->count++] = c;
    return parent;
}

/* shortcuts: a node with 1, 2 or 3 children */
static node *mk1(const char *name, node *a)                   { return add(mk(name), a); }
static node *mk2(const char *name, node *a, node *b)          { return add(mk1(name, a), b); }
static node *mk3(const char *name, node *a, node *b, node *c) { return add(mk2(name, a, b), c); }

/* move all the children of "list" to the end of "parent" (used for lists) */
static node *merge(node *parent, node *list)
{
    int i;
    if (list == NULL)
        return parent;
    for (i = 0; i < list->count; i++)
        add(parent, list->child[i]);
    return parent;
}

/* add a parameter (type, id) to the ARGS node.
   Parameters of the same type that come one after another are grouped:
   par1 int:x; par2 int:y  ->  (INT x y)                                   */
static node *add_param(node *args, node *type, char *id)
{
    node *last = (args->count > 0) ? args->child[args->count - 1] : NULL;
    if (last != NULL && strcmp(last->name, type->name) == 0)
        add(last, mk(id));
    else
        add(args, mk1(type->name, mk(id)));
    return args;
}

/* is this node a real leaf (a name or a value)? an empty BODY/BLOCK is not a leaf */
static int is_leaf(node *n)
{
    return n->count == 0 && strcmp(n->name, "BODY") != 0 && strcmp(n->name, "BLOCK") != 0;
}

/* print the tree in PREORDER: first the node, then its children (left to right).
   Each level is indented by 2 more spaces.                                   */
static void print_tree(node *n, int depth)
{
    int i, first = 0;
    if (n == NULL)
        return;
    for (i = 0; i < depth; i++) printf("  ");

    if (n->count == 0) {
        if (is_leaf(n))
            printf("%s\n", n->name);                     /* leaf: x            */
        else
            printf("(%s)\n", n->name);                   /* empty: (BLOCK)     */
        return;
    }
    if (n->count == 1 && is_leaf(n->child[0])) {       /* small node: (RET 'a') */
        printf("(%s %s)\n", n->name, n->child[0]->name);
        return;
    }
    if (strcmp(n->name, "ASS") == 0 && is_leaf(n->child[0])) {
        printf("(ASS %s\n", n->child[0]->name);         /* (ASS x  ...expression... ) */
        first = 1;
    }
    else {
        printf("(%s\n", n->name);                        /* (NAME  ...children... ) */
    }
    for (i = first; i < n->count; i++)
        print_tree(n->child[i], depth + 1);
    for (i = 0; i < depth; i++) printf("  ");
    printf(")\n");
}

#endif
