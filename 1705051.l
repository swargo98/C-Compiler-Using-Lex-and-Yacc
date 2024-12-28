%option noyywrap

%x INSIDESTRING
%x INSIDESTARCOMMENT
%x INSIDESLASHCOMMENT

%{
#include<iostream>
#include<string>
#include<fstream>
#include<cstring>
#include<cstdlib>

#include "SymbolTable.h"
#include "y.tab.h"

using namespace std;

int line_count=1;
extern int error_count;
extern vector<string> id_name;
extern int is_undeclared;

void yyerror(char *);

extern FILE *logout;
extern FILE *error;

char ToChar(const char* ptr, int is_str=0) {
	if(ptr[1-is_str] != '\\')  return ptr[1];


	if(ptr[1-is_str] == '\\') {
		if(ptr[2-is_str] == 'n') return '\n';
		else if(ptr[2-is_str] == 't') return '\t';
		else if(ptr[2-is_str] == '\\') return (char) 92;
		else if(ptr[2-is_str] == '\'') return (char) 39;
		else if(ptr[2-is_str] == 'a') return '\a';
		else if(ptr[2-is_str] == 'f') return '\f';
		else if(ptr[2-is_str] == 'r') return '\r';
		else if(ptr[2-is_str] == 'v') return '\v';
		else if(ptr[2-is_str] == 'b') return '\b';
		else if(ptr[2-is_str] == '0') return '\0';
		else if(ptr[2-is_str] == '\"') return (char) 34;

		else {
			return ' ';
		}
	}

	else {
			return ' ';
	}

}

string text="";
string saveSTR="";
int prev_line_no;

%}

/* GENERAL GRAMMARS */
WHITESPACE [ \t\f\r\v]+
LETTER [a-zA-Z]
DIGIT [0-9]
NEWLINE \n

/* OPERATORS AND PUNTUATIONS */
ADDOP [+-]
MULOP [*/%]
INCOP ("++")
DECOP ("--")
RELOP ("<"|"<="|">"|">="|"=="|"!=")
ASSIGNOP ("=")
LOGICOP ("&&"|"||")
NOT ("!")
LPAREN ("(")
RPAREN (")")
LCURL ("{")
RCURL ("}")
LTHIRD ("[")
RTHIRD ("]")
COMMA (",")
SEMICOLON (";")

/* LITERALS AND IDENTIFIERS */
INTEGER_LITERAL {DIGIT}+
EXP ([Ee][-+]?{DIGIT}+)
FLOAT_DECIMALEX (\.{DIGIT}+)({EXP})?
FLOAT_INTEX ({DIGIT}+)({EXP})?
FLOAT_BOTH ({DIGIT}+\.{DIGIT}+)({EXP})?
FLOATING_POINT_LITERAL ({FLOAT_BOTH}|{FLOAT_DECIMALEX}|{FLOAT_INTEX})

NORMAL_CHAR ([ -~]{-}['\\])
SPECIAL_CHAR (\\[nt\\afrbv0\'"])
CHARACTER_LITERAL '({NORMAL_CHAR}|{SPECIAL_CHAR})'

IDENTIFIER [A-Z_a-z][0-9A-Z_a-z]*

/* STRING */
STRING_NORMAL ([\t -~]{-}["\\])*
STRING_SPECIAL (\\[nt\\afrbv0\'"])
STRING_LINEEND ("\\\n"|"\\\r\n")
STRING_SLASH ("\\")
STRING_START [\"]

/* SINGLE LINE(SLASH) COMMENT */
SLINECOM_START "//"
SLINECOM_MULTI ("\\\n"|"\\\r\n")
SLINECOM_END ("\n"|"\r\n")

/* MULTILINE COMMENT */
MULTLITNECOM_START ("/*")
MULTLITNECOM_NORMAL ([\t\n !-~]{-}[\*])*
MULTLITNECOM_END ("*/")
MULTLITNECOM_STAR ("*")

/* ERRORS */
ERROR_TOOMANYDECIMALPOINT ({DIGIT}*(\.{DIGIT}+)(\.{DIGIT}+)+)
ERROR_ILLFORMED_EXP ({DIGIT}*\.?{DIGIT}+)({EXP})+({FLOAT_BOTH}|{FLOAT_DECIMALEX})+
ERROR_ILLFORMED_DEC ({DIGIT}+\.+)
ERROR_ILLFORMED ({ERROR_ILLFORMED_EXP}|{ERROR_ILLFORMED_DEC})
ERROR_INVALIDPREFIX [0-9]+{IDENTIFIER}
ERROR_MULTICHARCONST '(({NORMAL_CHAR}|{SPECIAL_CHAR})({NORMAL_CHAR}|{SPECIAL_CHAR})+)'
ERROR_UNFINISEDCHAR ('|'(({NORMAL_CHAR}|{SPECIAL_CHAR})+))
ERROR_EMPTYCHARCONST ''
%%

{WHITESPACE}        { //Do Nothing
            }

{NEWLINE} {line_count++;
	//printf("Inside Newline %d\n", line_count);
	is_undeclared=0;
	   //return NEWLINE;
	}


"if"	{return IF;}

"else"	{ return ELSE;}

"for"	{return FOR;}

"while" {return WHILE;}

"do"	{return DO;}

"break" {return BREAK;}

"int"	{return INT;}

"char"	{return CHAR;}

"float" {return FLOAT;}

"double" {return DOUBLE;}

"void"	{return VOID;}

"return" {return RETURN;}

"switch" {return SWITCH;}

"case"	{return CASE;}

"default" {return DEFAULT;}

"continue" {return CONTINUE;}


"printf"	{return PRINTLN;}

"println"	{return PRINTLN;}

{ADDOP}		{
			SymbolInfo *s=new SymbolInfo(yytext,"ADDOP");
			yylval.symbol_info=s;
			return ADDOP;

		}

{MULOP}		{
			SymbolInfo *s=new SymbolInfo(yytext,"MULOP");
			yylval.symbol_info=s;
			return MULOP;

		}

{INCOP} {return INCOP;}

{DECOP} {return DECOP;}

{RELOP}		{
			SymbolInfo *s=new SymbolInfo(yytext,"RELOP");
			yylval.symbol_info=s;
			return RELOP;

		}

{ASSIGNOP} {return ASSIGNOP;}

{LOGICOP}		{
			SymbolInfo *s=new SymbolInfo(yytext,"LOGICOP");
			yylval.symbol_info=s;
			return LOGICOP;

		}

{NOT}	{return NOT;}

{LPAREN} {return LPAREN;}

{RPAREN} {return RPAREN;}

{LCURL} {return LCURL;}

{RCURL} {return RCURL;}

{LTHIRD} {return LTHIRD;}

{RTHIRD} {return RTHIRD;}

{COMMA} {return COMMA;}

{SEMICOLON} {return SEMICOLON;}


{INTEGER_LITERAL} 	{
				SymbolInfo *s=new SymbolInfo(yytext,"CONST_INT");
				yylval.symbol_info=s;
				return CONST_INT;
			}

{FLOATING_POINT_LITERAL} 	{
				SymbolInfo *s=new SymbolInfo(yytext,"CONST_FLOAT");
				yylval.symbol_info=s;
				return CONST_FLOAT;
			}

{CHARACTER_LITERAL} 	{
				string temp;
				temp = ToChar(yytext);
				SymbolInfo *s=new SymbolInfo(temp.c_str(),"CONST_CHAR");
				yylval.symbol_info=s;
				return CONST_CHAR;
			}

{IDENTIFIER} 	{
				SymbolInfo *s=new SymbolInfo(yytext,"ID");
				yylval.symbol_info=s;
				id_name.push_back(yytext);
				return ID;
			}

{STRING_START}	{
			prev_line_no = line_count;
			saveSTR = saveSTR + yytext;
			BEGIN INSIDESTRING;  // another state starts
			}
<INSIDESTRING>{STRING_START} {
					saveSTR = saveSTR + yytext;

					SymbolInfo *s=new SymbolInfo(text.c_str(),"STRING");
					yylval.symbol_info=s;

					//fprintf(tokenout,"<STRING, \"%s\"> ",text.c_str());
					//fprintf(logout,"\nLine no %d: Token <STRING> Lexeme %s found --> <STRING, \"%s\"> \n",prev_line_no,saveSTR.c_str(), text.c_str());

					saveSTR = "";
					text = "";

					//BEGIN INITIAL;
					return STRING;
		}
<INSIDESTRING>{STRING_SPECIAL} {
					char c = ToChar(yytext, 1);
					saveSTR = saveSTR + yytext;
					text = text + c;
				}

<INSIDESTRING>{STRING_SLASH} {
					saveSTR = saveSTR + yytext;
					text = text + yytext;
				}

<INSIDESTRING>{STRING_NORMAL} {
					saveSTR = saveSTR + yytext;
					text = text + yytext;
				}
<INSIDESTRING>{STRING_LINEEND} {
					saveSTR = saveSTR + yytext;

					line_count++;

				}

<INSIDESTRING><<EOF>> {
					fprintf(error,"\nLexical Error at line no %d: Unterminated String %s\n",prev_line_no,saveSTR.c_str());
					fprintf(logout,"\nLexical Error at line no %d: Unterminated String %s\n",prev_line_no,saveSTR.c_str());
					//st.PrintAllScopeTable(logout);
					//line_count--;
					error_count++;
					//fprintf(logout,"\nTotal lines: %d\n",line_count);
					//fprintf(logout,"Total errors: %d\n",error_count);
					//return 0;

				}

<INSIDESTRING>{NEWLINE} {
					fprintf(logout,"\nError at line no %d: Unterminated String %s\n",prev_line_no,saveSTR.c_str());
					fprintf(error,"\nError at line no %d: Unterminated String %s\n",prev_line_no,saveSTR.c_str());
					error_count++;
					line_count++;
					saveSTR = "";
					text = "";
					BEGIN INITIAL;
				}

{SLINECOM_START}	{
			prev_line_no = line_count;
			saveSTR = saveSTR + yytext;
			BEGIN INSIDESLASHCOMMENT;  // another state starts
			}
<INSIDESLASHCOMMENT>{SLINECOM_END} {
					line_count++;

					//fprintf(logout,"\nLine no %d: Token <COMMENT> Lexeme %s found\n",prev_line_no,saveSTR.c_str());

					saveSTR = "";


					BEGIN INITIAL;
		}

<INSIDESLASHCOMMENT>{SLINECOM_MULTI} {
					saveSTR = saveSTR + yytext;
					line_count++;

				}
<INSIDESLASHCOMMENT>. {

					saveSTR = saveSTR + yytext;

				}



{MULTLITNECOM_START}	{
			prev_line_no = line_count;
			saveSTR = saveSTR + yytext;
			BEGIN INSIDESTARCOMMENT;  // another state starts
			}

<INSIDESTARCOMMENT>{MULTLITNECOM_END} {
					saveSTR = saveSTR + yytext;

					//fprintf(logout,"\nLine no %d: Token <COMMENT> Lexeme %s found\n",line_count,saveSTR.c_str());

					for(int i=0; i<saveSTR.length(); i++) {
						if(saveSTR[i] == '\n') {
							line_count++;
						}
					}

					saveSTR = "";

					BEGIN INITIAL;
		}

<INSIDESTARCOMMENT>{MULTLITNECOM_STAR} {
					saveSTR = saveSTR + yytext;
				}

<INSIDESTARCOMMENT>{MULTLITNECOM_NORMAL} {
					saveSTR = saveSTR + yytext;
					text = text + yytext;
				}

<INSIDESTARCOMMENT><<EOF>> {
					fprintf(error,"\nLexical Error at line no %d: Unterminated Comment %s",prev_line_no,saveSTR.c_str());
					fprintf(logout,"\nLexical Error at line no %d: Unterminated Comment %s",prev_line_no,saveSTR.c_str());

					for(int i=0; i<saveSTR.length(); i++) {
						if(saveSTR[i] == '\n') {
							line_count++;
						}
					}

					//st.PrintAllScopeTable(logout);
					//line_count--;
					error_count++;
					//fprintf(logout,"\nTotal lines: %d\n",line_count);
					//fprintf(logout,"Total errors: %d\n",error_count);
					//return 0;

				}

{ERROR_TOOMANYDECIMALPOINT}		{
			error_count++;
			fprintf(error,"\nLexical Error at line no %d: Too many decimal points %s\n",line_count,yytext);
			fprintf(logout,"\nLexical Error at line no %d: Too many decimal points %s\n",line_count,yytext);

		}

{ERROR_ILLFORMED}		{
			error_count++;
			fprintf(error,"\nLexical Error at line no %d: Ill formed number %s\n",line_count,yytext);
			fprintf(logout,"\nLexical Error at line no %d: Ill formed number %s\n",line_count,yytext);

		}

{ERROR_INVALIDPREFIX}		{
			error_count++;
			fprintf(error,"\nLexical Error at line no %d: Invalid prefix on ID or invalid suffix on Number %s\n",line_count,yytext);
			fprintf(logout,"\nLexical Error at line no %d: Invalid prefix on ID or invalid suffix on Number %s\n",line_count,yytext);

		}

{ERROR_MULTICHARCONST}		{
			error_count++;
			fprintf(error,"\nLexical Error at line no %d: Multi character constant error %s\n",line_count,yytext);
			fprintf(logout,"\nLexical Error at line no %d: Multi character constant error %s\n",line_count,yytext);

		}

{ERROR_UNFINISEDCHAR}		{
			error_count++;
			fprintf(error,"\nLexical Error at line no %d: Unterminated character %s\n",line_count,yytext);
			fprintf(logout,"\nLexical Error at line no %d: Unterminated character %s\n",line_count,yytext);

		}

{ERROR_EMPTYCHARCONST}		{
			error_count++;
			fprintf(error,"\nLexical Error at line no %d: Empty character constant error %s\n",line_count,yytext);
			fprintf(logout,"\nLexical Error at line no %d: Empty character constant error %s\n",line_count,yytext);

		}

.   {
		fprintf(logout,"Error at line no %d: Unrecognized character %s\n\n",line_count,yytext);
		fprintf(error,"Error at line no %d: Unrecognized character %s\n\n",line_count,yytext);
		error_count++;
	}
%%
