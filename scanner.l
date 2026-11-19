%{
/* ============================================================
   scanner.l  -  the Scanner (Lexical Analyzer) of our language
   ============================================================ */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int scan_debug;   /* 1 = print every token (for testing) */

int comment_line = 0;     /* the line where the last comment #-> started */

/* SHOW: when testing, print the line number, the token name and the lexeme */
#define SHOW(name) \
    if (scan_debug) printf("line %-3d %-12s %s\n", yylineno, name, yytext)

/* T(X): return the token X */
#define T(tok)  do { SHOW(#tok); return tok; } while (0)

/* TV(X): return the token X, and also pass its text (the lexeme) to Yacc in yylval */
#define TV(tok) do { yylval.str = strdup(yytext); SHOW(#tok); return tok; } while (0)

/* C(): return a one-character token, like '+' or ';' (the character is its own token) */
#define C()     do { SHOW("CHAR_TOKEN"); return yytext[0]; } while (0)

/* lexical error: print where and what, then stop */
#define LEX_ERROR(msg) do { \
        fprintf(stderr, "Lexical error at line %d: %s: %s\n", yylineno, msg, yytext); \
        exit(1); \
    } while (0)
%}

%option yylineno
%option noyywrap

%x COMMENT

DIGIT     [0-9]
HEXDIGIT  [0-9A-Fa-f]
LETTER    [a-zA-Z]
EXPONENT  [eE][+-]?{DIGIT}+

%%

 /* ---------- comments: #-> ... <-# (can span many lines) ---------- */
"#->"                 { comment_line = yylineno; BEGIN(COMMENT); }
<COMMENT>"<-#"        { BEGIN(INITIAL); }
<COMMENT>\n           { /* skip - yylineno still counts the line */ }
<COMMENT>.            { /* skip */ }
<COMMENT><<EOF>>      { fprintf(stderr, "Lexical error at line %d: comment was opened but never closed (missing <-#)\n", comment_line); exit(1); }

 /* ---------- types ---------- */
"bool"                T(BOOL);
"char"                T(CHAR);
"int"                 T(INT);
"real"                T(REAL);
"string"              T(STRING);
"int*"                T(INT_PTR);
"char*"               T(CHAR_PTR);
"real*"               T(REAL_PTR);

 /* ---------- keywords ---------- */
"if"                  T(IF);
"elif"                T(ELIF);
"else"                T(ELSE);
"while"               T(WHILE);
"for"                 T(FOR);
"do"                  T(DO);
"var"                 T(VAR);
"type"                T(TYPE);
"return"              T(RETURN);
"returns"             T(RETURNS);
"begin"               T(K_BEGIN);
"end"                 T(K_END);
"def"                 T(DEF);
"call"                T(CALL);
"and"                 T(AND);
"or"                  T(OR);
"not"                 T(NOT);
"null"                TV(NULL_LIT);
"_main_"              TV(MAIN);
"par"{DIGIT}+         TV(PARAM);

 /* ---------- operators made of 2 characters ---------- */
"=="                  T(EQ);
"!="                  T(NE);
">="                  T(GE);
"<="                  T(LE);

 /* ---------- operators and symbols made of 1 character ---------- */
[-+*/&=<>|;,:()\[\]]  C();

 /* ---------- literals ---------- */
"TRUE"|"FALSE"                                        TV(BOOL_LIT);
'[ -~]'                                               TV(CHAR_LIT);
0[xX]{HEXDIGIT}+                                      TV(INT_LIT);
0|[1-9]{DIGIT}*                                       TV(INT_LIT);
({DIGIT}+"."{DIGIT}*|"."{DIGIT}+){EXPONENT}?          TV(REAL_LIT);
{DIGIT}+{EXPONENT}                                    TV(REAL_LIT);
\"[^"\n]*\"                                           TV(STRING_LIT);

 /* ---------- identifiers (must come AFTER the keywords) ---------- */
{LETTER}({LETTER}|{DIGIT}|_)*                         TV(ID);

 /* ---------- white space ---------- */
[ \t\r\n]+            { /* skip */ }

 /* ---------- lexical errors ---------- */
0{DIGIT}+             LEX_ERROR("a decimal number cannot start with 0");
\"[^"\n]*             LEX_ERROR("string is not closed on the same line");
.                     LEX_ERROR("illegal character");

%%
