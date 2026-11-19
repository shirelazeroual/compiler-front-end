%{
/* ============================================================
   parser.y  -  STEP 4 version: full grammar + building the AST.
                If the code is legal, the AST is printed in preorder.
   ============================================================ */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ast.h"

int yylex(void);
int yyerror(const char *s);

int scan_debug = 0;
node *root = NULL;          /* the root of the AST (CODE) */

/* parameters must be numbered in order: par1, par2, par3 ... */
int param_index = 0;
int check_param(char *par);
int ends_with_return(node *body, char *func_name);
%}

%define parse.error verbose

/* the value of a token or of a grammar variable can be: */
%union {
    char *str;              /* a lexeme (tokens):          "x", "5", "'a'" */
    struct node *node;      /* a piece of the tree (rules): FUNC, ASS, + ...  */
}

/* ---------- tokens ---------- */
%token BOOL CHAR INT REAL STRING INT_PTR CHAR_PTR REAL_PTR
%token IF ELIF ELSE WHILE FOR DO VAR TYPE RETURN RETURNS
%token K_BEGIN K_END DEF CALL AND OR NOT
%token EQ NE GE LE
%token <str> ID PARAM MAIN NULL_LIT
%token <str> BOOL_LIT CHAR_LIT INT_LIT REAL_LIT STRING_LIT

/* ---------- every grammar variable returns a tree node ---------- */
%type <node> program functions function func_name params param_list type
%type <node> var_part declarations declaration var_list var_item str_list str_item
%type <node> body nested_funcs statements statement block assignment lhs
%type <node> if_stmt elif_else call args arg_list expr

/* ---------- precedence: lowest first, highest last (like in C) ---------- */
%nonassoc LOWER_THAN_ELSE
%nonassoc ELIF ELSE
%left OR
%left AND
%left EQ NE
%left '<' '>' LE GE
%left '+' '-'
%left '*' '/'
%right NOT UNARY

%%

/* ============ program and functions ============ */

program     : functions                     { root = $1; }
            ;

functions   : function                      { $$ = mk1("CODE", $1); }
            | functions function            { $$ = add($1, $2); }
            ;

function    : DEF func_name '(' params ')' ':' RETURNS type var_part K_BEGIN body K_END
                  {
                      /* a function that returns a value must end with "return" */
                      if (!ends_with_return($11, $2->name)) YYABORT;
                      $$ = mk("FUNC");
                      add($$, $2);                          /* name          */
                      add($$, $4);                          /* (ARGS ...)    */
                      add($$, mk1("RET", $8));              /* (RET INT)     */
                      add($$, $9);                          /* (VAR ...) if any */
                      add($$, merge(mk("BODY"), $11));      /* (BODY ...)    */
                  }
            | DEF func_name '(' params ')' ':' var_part K_BEGIN body K_END
                  {
                      $$ = mk("FUNC");
                      add($$, $2);
                      add($$, $4);
                      add($$, mk1("RET", mk("VOID")));      /* procedure     */
                      add($$, $7);
                      add($$, merge(mk("BODY"), $9));
                  }
            ;

func_name   : ID                            { $$ = mk($1); }
            | MAIN                          { $$ = mk($1); }
            ;

/* ============ parameters: par1 int:x; par2 real:y ============ */

params      : /* empty */                   { $$ = mk1("ARGS", mk("NONE")); }
            | param_list                    { $$ = $1; }
            ;

param_list  : PARAM type ':' ID
                  {
                      param_index = 1;                              /* first parameter */
                      if (!check_param($1)) YYABORT;
                      $$ = add_param(mk("ARGS"), $2, $4);
                  }
            | param_list ';' PARAM type ':' ID
                  {
                      param_index++;                                /* next parameter  */
                      if (!check_param($3)) YYABORT;
                      $$ = add_param($1, $4, $6);
                  }
            ;

type        : BOOL                          { $$ = mk("BOOL"); }
            | CHAR                          { $$ = mk("CHAR"); }
            | INT                           { $$ = mk("INT"); }
            | REAL                          { $$ = mk("REAL"); }
            | INT_PTR                       { $$ = mk("INT*"); }
            | CHAR_PTR                      { $$ = mk("CHAR*"); }
            | REAL_PTR                      { $$ = mk("REAL*"); }
            ;

/* ============ variable declarations: var type int:x,y:5; ============ */

var_part    : /* empty */                   { $$ = NULL; }
            | VAR declarations              { $$ = merge(mk("VAR"), $2); }
            ;

declarations: /* empty */                   { $$ = mk("LIST"); }
            | declarations declaration      { $$ = add($1, $2); }
            ;

declaration : TYPE type ':' var_list ';'    { $$ = merge($2, $4); }
            | TYPE type var_list ';'        { $$ = merge($2, $3); }
            | TYPE STRING ':' str_list ';'  { $$ = merge(mk("STRING"), $4); }
            | TYPE STRING str_list ';'      { $$ = merge(mk("STRING"), $3); }
            ;

var_list    : var_item                      { $$ = mk1("LIST", $1); }
            | var_list ',' var_item         { $$ = add($1, $3); }
            ;

var_item    : ID                            { $$ = mk($1); }
            | ID ':' expr                   { $$ = mk1($1, $3); }        /* (i 0) */
            ;

str_list    : str_item                      { $$ = mk1("LIST", $1); }
            | str_list ',' str_item         { $$ = add($1, $3); }
            ;

str_item    : ID '[' INT_LIT ']'            { $$ = mk1($1, mk($3)); }    /* (a 30) */
            | ID '[' INT_LIT ']' ':' STRING_LIT
                                            { $$ = mk2($1, mk($3), mk($6)); }
            ;

/* ============ body: nested functions first, then statements ============ */

body        : nested_funcs statements       { $$ = merge($1, $2); }
            ;

nested_funcs: /* empty */                   { $$ = mk("LIST"); }
            | nested_funcs function         { $$ = add($1, $2); }
            ;

statements  : /* empty */                   { $$ = mk("LIST"); }
            | statements statement          { $$ = add($1, $2); }
            ;

/* ============ statements ============ */

statement   : assignment ';'                { $$ = $1; }
            | CALL ID '(' args ')' ';'      { $$ = mk2("CALL", mk($2), $4); }
            | RETURN expr ';'               { $$ = mk1("RET", $2); }
            | if_stmt                       { $$ = $1; }
            | WHILE expr ':' statement      { $$ = mk2("WHILE", $2, $4); }
            | DO ':' block WHILE ':' expr ';'
                                            { $$ = mk2("DO-WHILE", $3, $6); }
            | DO ':' block WHILE expr ';'   { $$ = mk2("DO-WHILE", $3, $5); }
            | FOR '(' assignment ';' expr ';' assignment ')' ':' statement
                  {
                      $$ = mk("FOR");
                      add($$, mk1("INIT", $3));
                      add($$, mk1("COND", $5));
                      add($$, mk1("UPDATE", $7));
                      add($$, $10);
                  }
            | block                         { $$ = $1; }
            ;

block       : var_part K_BEGIN body K_END   { $$ = merge(add(mk("BLOCK"), $1), $3); }
            ;

assignment  : lhs '=' expr                  { $$ = mk2("ASS", $1, $3); }
            ;

lhs         : ID                            { $$ = mk($1); }
            | ID '[' expr ']'               { $$ = mk2("INDEX", mk($1), $3); }
            | '*' ID                        { $$ = mk1("DEREF", mk($2)); }
            ;

/* if / elif / else */
if_stmt     : IF expr ':' statement elif_else
                  {
                      if ($5 == NULL)                                   /* if        */
                          $$ = mk2("IF", $2, $4);
                      else if ($5->count == 1 && strcmp($5->child[0]->name, "ELSE") == 0)
                          $$ = mk3("IF-ELSE", $2, $4, $5->child[0]->child[0]);  /* if-else */
                      else                                              /* if-elif-...-else */
                          $$ = merge(mk2("IF-ELIF", $2, $4), $5);
                  }
            ;

elif_else   : /* empty */                   %prec LOWER_THAN_ELSE   { $$ = NULL; }
            | ELSE ':' statement            { $$ = mk1("LIST", mk1("ELSE", $3)); }
            | ELSE statement                { $$ = mk1("LIST", mk1("ELSE", $2)); }
            | ELIF expr ':' statement elif_else
                  {
                      $$ = mk1("LIST", mk2("ELIF", $2, $4));
                      merge($$, $5);
                  }
            ;

/* function call inside an expression: "a = call foo(1,2)" or "return foo(1,2)" */
call        : CALL ID '(' args ')'          { $$ = mk2("CALL", mk($2), $4); }
            | ID '(' args ')'               { $$ = mk2("CALL", mk($1), $3); }
            ;

args        : /* empty */                   { $$ = mk1("ARGS", mk("NONE")); }
            | arg_list                      { $$ = $1; }
            ;

arg_list    : expr                          { $$ = mk1("ARGS", $1); }
            | arg_list ',' expr             { $$ = add($1, $3); }
            ;

/* ============ expressions ============ */

expr        : expr '+' expr                 { $$ = mk2("+",   $1, $3); }
            | expr '-' expr                 { $$ = mk2("-",   $1, $3); }
            | expr '*' expr                 { $$ = mk2("*",   $1, $3); }
            | expr '/' expr                 { $$ = mk2("/",   $1, $3); }
            | expr EQ  expr                 { $$ = mk2("==",  $1, $3); }
            | expr NE  expr                 { $$ = mk2("!=",  $1, $3); }
            | expr '<' expr                 { $$ = mk2("<",   $1, $3); }
            | expr '>' expr                 { $$ = mk2(">",   $1, $3); }
            | expr LE  expr                 { $$ = mk2("<=",  $1, $3); }
            | expr GE  expr                 { $$ = mk2(">=",  $1, $3); }
            | expr AND expr                 { $$ = mk2("and", $1, $3); }
            | expr OR  expr                 { $$ = mk2("or",  $1, $3); }
            | NOT expr                      { $$ = mk1("not", $2); }
            | '-' expr          %prec UNARY { $$ = mk1("-", $2); }
            | '+' expr          %prec UNARY { $$ = mk1("+", $2); }
            | '*' ID                        { $$ = mk1("DEREF", mk($2)); }   /* *x      */
            | '*' '(' expr ')'              { $$ = mk1("DEREF", $3); }       /* *(p+5)  */
            | '&' ID                        { $$ = mk1("ADDR", mk($2)); }
            | '&' ID '[' expr ']'           { $$ = mk1("ADDR", mk2("INDEX", mk($2), $4)); }
            | '|' ID '|'                    { $$ = mk1("LEN", mk($2)); }
            | '(' expr ')'                  { $$ = $2; }
            | call                          { $$ = $1; }
            | ID                            { $$ = mk($1); }
            | ID '[' expr ']'               { $$ = mk2("INDEX", mk($1), $3); }
            | INT_LIT                       { $$ = mk($1); }
            | REAL_LIT                      { $$ = mk($1); }
            | CHAR_LIT                      { $$ = mk($1); }
            | STRING_LIT                    { $$ = mk($1); }
            | BOOL_LIT                      { $$ = mk($1); }
            | NULL_LIT                      { $$ = mk($1); }
            ;

%%

#include "lex.yy.c"

int yyerror(const char *s)
{
    /* bison writes "syntax error, unexpected X, expecting Y" - keep only the useful part */
    if (strncmp(s, "syntax error, ", 14) == 0)
        s += 14;
    fprintf(stderr, "Syntax error at line %d: %s (near '%s')\n", yylineno, s, yytext);
    return 0;
}

/* check that the parameter is called par<param_index> (par1, then par2 ...) */
int check_param(char *par)
{
    char expected[32];
    sprintf(expected, "par%d", param_index);
    if (strcmp(par, expected) != 0) {
        fprintf(stderr, "Syntax error at line %d: parameter '%s' should be '%s' "
                        "(parameters must be numbered par1, par2, par3 ...)\n",
                yylineno, par, expected);
        return 0;
    }
    return 1;
}

/* the last statement of a function (with "returns") must be a return statement */
int ends_with_return(node *body, char *func_name)
{
    if (body->count == 0 || strcmp(body->child[body->count - 1]->name, "RET") != 0) {
        fprintf(stderr, "Syntax error at line %d: function '%s' must end with a return statement\n",
                yylineno, func_name);
        return 0;
    }
    return 1;
}

int main(void)
{
    if (yyparse() == 0)          /* 0 = the code is legal */
        print_tree(root, 0);
    return 0;
}
