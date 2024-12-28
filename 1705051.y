%{
	#include<iostream>
	#include<string>
	#include<fstream>
	#include<cstring>
	#include<string>
	#include<cstdlib>
	#include<vector>
	#include<algorithm>
	#include <sstream>
	#include "SymbolTable.h"

	using namespace std;

	int yyparse(void);
	int yylex(void);
	extern FILE *yyin;
	FILE *logout,*error, *assembly_code;

	int error_count=0;
	extern int line_count;

	SymbolTable st(30);

	string type, func_name, ret_type, code;
	int is_undeclared=0;
	vector<string> id_name;
	vector<string> type_name;
	vector<SymbolInfo*> saved_list;
	vector<int> syntax_error_lines;

	vector<pair<string, int>> initializeVariables;
	vector<string> local_vars;
	vector<string> ret_vars;

	int temp_var_cnt = 0;

	void yyerror(char *s)
	{
		//nothing
	}

	bool void_error(string type){
		if(type=="void") {
			error_count++;
			fprintf(error,"Error at line %d: Void function used in expression\n\n", line_count);
			fprintf(logout,"Error at line %d: Void function used in expression\n\n", line_count);
			return true;
		}
		return false;
	}

	void save_type_id(){
		//func_name = id_name;
		ret_type = type;
	}

	void fill_scope(){

		st.EnterScope(logout);
		if(!(saved_list.size()==1 && saved_list[0]->getname()=="void")){
			string term="TERMINAL";
			for(int i=0; i<saved_list.size(); i++){
				if(saved_list[i]->gettype()==term){
					error_count++;
					fprintf(error,"Error at line %d: %dth parameter's name not given in function definition of %s\n\n", line_count-1, i+1, func_name.c_str());
					fprintf(logout,"Error at line %d: %dth parameter's name not given in function definition of %s\n\n", line_count-1, i+1, func_name.c_str());
				}
				else{
					string var_type = saved_list[i]->gettype();
					saved_list[i]->settype("ID");
					saved_list[i]->set_var_ret_type(var_type);
					saved_list[i]->set_assebly_symbol(saved_list[i]->getname()+st.getTableID());

					initializeVariables.push_back({saved_list[i]->getname()+st.getTableID(), -1});
					local_vars.push_back(saved_list[i]->getname()+st.getTableID());

					if(!st.Insert(saved_list[i])){
						error_count++;
						fprintf(error,"Error at line %d: multiple declaration of %s in parameter\n\n", line_count-1, saved_list[i]->getname().c_str());
						fprintf(logout,"Error at line %d: multiple declaration of %s in parameter\n\n", line_count-1, saved_list[i]->getname().c_str());
					}

				}
			}
		}
		saved_list.clear();
	}

	string newTemp() {
		//Temporary Variable Creation and add to intial
		char t_name = 'A' + temp_var_cnt;
		temp_var_cnt++;
		if(temp_var_cnt==26) temp_var_cnt = 32;
		if(temp_var_cnt==57) temp_var_cnt = -17;
		string temp_var = "TEMP_";
		temp_var+=t_name;
		initializeVariables.push_back({temp_var, -1});
		return temp_var;
	}

	string newLabel(string prefix) {
		//Temporary Variable Creation and add to intial
		char t_name = 'A' + temp_var_cnt;
		temp_var_cnt++;
		if(temp_var_cnt==26) temp_var_cnt = 32;
		if(temp_var_cnt==57) temp_var_cnt = -17;
		string temp_var_in = prefix + "_" + t_name;
		return temp_var_in;
	}

	void optimize() {

		stringstream ss(code); //convert my_string into string stream

		vector<string> lines;
		string str;
		vector<string>out_lines;

		while(getline(ss, str)){ //use comma as delim for cutting string
			lines.push_back(str);
		}

		for(int i=0; i<lines.size(); ++i) {

			if (lines[i].find("MOV") != std::string::npos) {

				string cur_one, cur_two, next_one, next_two, temp;
				stringstream cur(lines[i]);
				int cnt=0;
				while(getline(cur, temp, ' ')) {
					if(cnt==1) cur_one = temp.substr(0, temp.length()-1);
					else if(cnt==2) cur_two = temp;
					else if(cnt>2) break;
					cnt++;
				}
				vector<string>window;
				window.push_back(lines[i]);
				for(int j=i+1; ;j++) {
					char first='0';
					for (char x : lines[j]) {
						if((x>='A' && x<='Z') || x==';') {
							first = x;
							break;
						}
					}
					if (first>='A' && first<='Z') {
						if (lines[j].find("MOV") != std::string::npos) {
							stringstream next(lines[j]);
							int cnt2=0;
							while(getline(next, temp, ' ')) {
								if(cnt2==1) next_one = temp.substr(0, temp.length()-1);
								else if(cnt2==2) next_two = temp;
								else if(cnt2>2) break;
								cnt2++;
							}
							cur_one.erase(remove_if(cur_one.begin(), cur_one.end(), [](char c) { return !isprint(c); } ), cur_one.end());
							cur_two.erase(remove_if(cur_two.begin(), cur_two.end(), [](char c) { return !isprint(c); } ), cur_two.end());
							next_one.erase(remove_if(next_one.begin(), next_one.end(), [](char c) { return !isprint(c); } ), next_one.end());
							next_two.erase(remove_if(next_two.begin(), next_two.end(), [](char c) { return !isprint(c); } ), next_two.end());

							if((cur_one==next_two) && (next_one==cur_two))
							{
								cout<<"Optimization at line ";
								cout<<j+1<<endl;

								for(int k=0; k<window.size(); ++k) {
									string t = window[k];
									out_lines.push_back(t);
									i++;
								}

								} else {
									out_lines.push_back(lines[i]);
								}
								} else {
									out_lines.push_back(lines[i]);
								}

								break;
							}
							else {
								window.push_back(lines[j]);
							}

						}
						//cout << lines[i] << '\n';
					}
					else {
						out_lines.push_back(lines[i]);
					}
				}



				ofstream outFile("optimized_code.asm");

				for(int i=0; i<out_lines.size(); ++i) {
					//cout<<"LINE "<<i+1<<": ";
					outFile << out_lines[i] << '\n';

				}
			}


			void function_validity(){
				int term_cnt=0;
				string ter="TERMINAL";
				for(int i=0; i<saved_list.size(); i++){
					if(saved_list[i]->gettype()==ter) term_cnt++;
				}

				int id_cnt = saved_list.size()-term_cnt;

				func_name = id_name[id_name.size()-1-id_cnt];
				ret_type = type_name[type_name.size()-1-saved_list.size()];

				SymbolInfo temp;
				bool does_exist = st.Lookup(func_name, temp);

				if(!does_exist){

					SymbolInfo* temp2 = new SymbolInfo(func_name, "ID");
					temp2->set_var_ret_type(ret_type);
					temp2->set_unit_type(3); //3 for function definition

					for(int i=0; i<saved_list.size(); i++) {
						temp2->add_param(saved_list[i]);
					}
					st.Insert(temp2);
				}
				else if(temp.get_unit_type()!=2){

					error_count++;
					fprintf(error,"Error at line %d: multiple declaration of %s\n\n", line_count, temp.getname().c_str());
					fprintf(logout,"Error at line %d: multiple declaration of %s\n\n", line_count, temp.getname().c_str());
				}
				else{
					if(temp.get_var_ret_type()!=ret_type){
						error_count++;
						fprintf(error,"Error at line %d: Return type mismatch with function declaration in function %s\n\n", line_count, func_name.c_str());
						fprintf(logout,"Error at line %d: Return type mismatch with function declaration in function %s\n\n", line_count, func_name.c_str());
					}
					else{
						int p_size = temp.get_param_size();
						bool is_exceptional = (p_size ==1 && saved_list.size()==0 && temp.get_param(0)->getname()=="void");
						is_exceptional = (is_exceptional||(p_size ==0 && saved_list.size()==1 && saved_list[0]->getname()=="void"));
						if(is_exceptional)
						{
							temp.set_unit_type(3); //definition completed
							st.Remove(temp.getname());
							SymbolInfo* tempointer;
							tempointer = &temp;
							st.Insert(tempointer);
						}
						if(!is_exceptional){
							if(p_size!=saved_list.size()){
								error_count++;

								fprintf(error,"Error at line %d: Total number of arguments mismatch with declaration in function %s\n\n", line_count, func_name.c_str());
								fprintf(logout,"Error at line %d: Total number of arguments mismatch with declaration in function %s\n\n", line_count, func_name.c_str());
							}

							else{
								bool is_inconsistent=false;
								for(int i=0; i<saved_list.size(); i++){
									if(temp.get_param(i)->gettype()!=saved_list[i]->gettype()){


										error_count++;
										fprintf(error,"Error at line %d: inconsistent function definition with its declaration for %s\n\n", line_count, func_name.c_str());
										fprintf(logout,"Error at line %d: inconsistent function definition with its declaration for %s\n\n", line_count, func_name.c_str());
										is_inconsistent = true;
									}
								}

								if(!is_inconsistent) temp.set_unit_type(3); //definition completed

								//temp.setname("HAHA");
								st.Remove(temp.getname());
								SymbolInfo* tempointer;
								tempointer = &temp;
								st.Insert(tempointer);
								//st.PrintAllScopeTable();
							}
						}
					}
				}
			}

			%}

			%union{
				SymbolInfo *symbol_info;
			}

			%token IF ELSE FOR WHILE DO BREAK INT CHAR FLOAT DOUBLE VOID RETURN SWITCH CASE DEFAULT CONTINUE MAIN PRINTLN
			%token INCOP DECOP ASSIGNOP NOT LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA SEMICOLON
			%token<symbol_info>ADDOP MULOP RELOP LOGICOP CONST_INT CONST_FLOAT CONST_CHAR ID STRING

			%type<symbol_info>type_specifier declaration_list var_declaration unit program parameter_list func_declaration factor unary_expression term simple_expression rel_expression logic_expression
			%type<symbol_info>expression expression_statement variable arguments argument_list statement statements compound_statement func_definition

			%nonassoc LOWER_THAN_ELSE
			%nonassoc ELSE


			%%

			start : program {
				fprintf(logout, "Line %d: start : program\n", line_count-1);

				if(error_count==0) {
					string initialCode="";

					initialCode+=".MODEL SMALL\n\n.STACK 100H\n\n.DATA\n";

					for(int i=0; i<initializeVariables.size(); i++) {
						if(initializeVariables[i].second==-1) {
							initialCode+="\t"+initializeVariables[i].first+" DW ?\n";
						}
						else {
							initialCode+=("\t"+initializeVariables[i].first+" DW "+to_string(initializeVariables[i].second)+" DUP(?)\n");
						}
					}

					initializeVariables.clear();

					//Necessary Variables for PRINT

					initialCode+= "\n\tCR EQU 0DH ;CARRIAGE RETURN\
					\n\tLF EQU 0AH ;LINE FEED\
					\n\tCOUNTER DB 0\
					\n\tANS DW ?\
					\n\tADDRESS DW ?\
					\n\tNEWLINE DB CR, LF, '$'\n";

					initialCode+="";
					initialCode+="\n.CODE\n\n";

					initialCode+=$1->get_code();

					initialCode+="\n\nPRINT PROC\n\
					\n\tPOP ADDRESS\
					\n\tPOP ANS\
					\n\tMOV BX, ANS\
					\n\n\t;PRINT NEWLINE\
					\n\tMOV AH,9\
					\n\tLEA DX, NEWLINE\
					\n\tINT 21H\
					\n\n\tCMP BX,0\
					\n\tJGE PUSHLOOP\
					\n\tNEG BX\
					\n\tMOV DL, '-'\
					\n\tMOV AH, 2 ; PRINT\
					\n\tINT 21H\
					\n\n\tPUSHLOOP:\
					\n\t\tMOV AX, BX ;MOVE THE SAVED VALUE TO AX\
					\n\t\tMOV DX, 0\
					\n\t\tMOV CX, 10 ;MOVE 10 TO DL TO DIVIDE\
					\n\t\tIDIV CX ; SIGNED DIVISION\
					\n\n\t\tMOV BX, 0 ; MAKE THE SAVED VALUE ZERO TO UPDATE\
					\n\t\tMOV BX, AX ; UPDATE THE QUOTIENT AS SAVED VALUE\
					\n\t\tMOV AX, 0 ; QUOTIENT IS MADE ZERO\
					\n\t\tPUSH DX ; PUSH THAT REMAINDER TO THE STACK\
					\n\n\t\tINC COUNTER ; INCREASE THE NUMBER  OF DIGIT\
					\n\n\t\tCMP BL, 0 ; IF THE QUOTIENT IS 0, GO TO PRINTLOOP\
					\n\t\tJE PRINTLOOP\
					\n\t\tJMP PUSHLOOP\
					\n\n\tPRINTLOOP:\
					\n\t\tCMP COUNTER, 0 ; IF THE COUNT FINISHES, IT WILL GOT TO THE END \
					\n\t\tJE THEEND\
					\n\t\tDEC COUNTER ; DECREASING THE VALUE OF DIGIT COUNTER\
					\n\n\t\tPOP DX ; TAKE THE POPPED VALUE TO DX, AS IT IS A SINGLE DIGIT, IT WILL AUTOMETICALLY BE SET TO DL\
					\n\t\tADD DL, '0' ; ADD '0' TO MATCH THE ASCII VALUE\
					\n\t\tMOV AH, 2 ; PRINT\
					\n\t\tINT 21H\
					\n\n\t\tJMP PRINTLOOP\
					\n\tTHEEND:\
					\n\tPUSH ADDRESS\
					\n\tRET\
					\nPRINT ENDP\
					\nEND MAIN";

					code = initialCode;
					fprintf(assembly_code,"%s",initialCode.c_str());
				}
			}
			;



			program : unit {
				$$ = new SymbolInfo($1->getname(), "PROGRAM");
				fprintf(logout,"Line %d: program : unit\n\n", line_count);
				fprintf(logout,"%s\n\n\n", $$->getname().c_str());

				$$->set_code($1->get_code());
			}
			| program unit {
				$$ = new SymbolInfo($1->getname()+"\n"+$2->getname(), "PROGRAM");
				fprintf(logout,"Line %d: program : program unit\n\n", line_count);
				fprintf(logout,"%s\n\n\n", $$->getname().c_str());

				$$->set_code($1->get_code());
				$$->add_code($2->get_code());
			}
			;

			unit : var_declaration {
				$$ = new SymbolInfo($1->getname(), "UNIT");
				fprintf(logout,"Line %d: unit : var_declaration\n\n", line_count);
				fprintf(logout,"%s\n\n\n", $1->getname().c_str());
			}

			| func_declaration {
				$$ = new SymbolInfo($1->getname(), "UNIT");
				fprintf(logout,"Line %d: unit : func_declaration\n\n", line_count);
				fprintf(logout,"%s\n\n\n", $1->getname().c_str());
			}

			| func_definition {
				$$ = new SymbolInfo($1->getname(), "UNIT");
				fprintf(logout,"Line %d: unit : func_definition\n\n", line_count);
				fprintf(logout,"%s\n\n\n", $1->getname().c_str());

				$$->set_code($1->get_code());
			}
			;

			func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON {
				fprintf(logout,"Line %d: func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON\n\n", line_count);

				string declaration="";
				declaration+=$1->getname()+"  "+$2->getname() + "(";

				fprintf(logout,"%s  %s(", $1->getname().c_str(), $2->getname().c_str());
				string term="TERMINAL";

				SymbolInfo* temp = new SymbolInfo($2->getname(), "ID");
				temp->set_var_ret_type($1->getname());
				temp->set_unit_type(2);
				for(int i=0; i<$4->get_param_size(); i++)
				{
					temp->add_param($4->get_param(i));
					if($4->get_param(i)->gettype()==term){
						fprintf(logout,"%s", $4->get_param(i)->getname().c_str());
						declaration+= $4->get_param(i)->getname();
					}
					else{
						fprintf(logout,"%s %s",$4->get_param(i)->gettype().c_str(), $4->get_param(i)->getname().c_str());
						declaration+= $4->get_param(i)->gettype()+" ";
						declaration+= $4->get_param(i)->getname();
					}
					if(i!=($4->get_param_size()-1)){
						fprintf(logout,", ");
						declaration+= ", ";
					}
				}
				fprintf(logout,");\n\n\n");
				declaration+=");";

				if(!st.Insert(temp)){
					error_count++;
					fprintf(error,"Error at line %d: multiple declaration of %s\n\n", line_count, temp->getname().c_str());
					fprintf(logout,"Error at line %d: multiple declaration of %s\n\n", line_count, temp->getname().c_str());
				}

				$$ = new SymbolInfo(declaration, "FUNC_DECLARATION");
				$4->clear_params();
				saved_list.clear();
			}
			;

			| type_specifier ID LPAREN RPAREN SEMICOLON {
				fprintf(logout,"Line %d: func_declaration : type_specifier ID LPAREN RPAREN SEMICOLON\n\n", line_count);

				string declaration="";
				declaration+=$1->getname()+"  "+$2->getname() + "();";

				fprintf(logout,"%s  %s()", $1->getname().c_str(), $2->getname().c_str());
				fprintf(logout,";\n\n\n");

				$2->set_var_ret_type($1->getname());
				$2->set_unit_type(2);
				if(!st.Insert($2)){
					error_count++;
					fprintf(error,"Error at line %d: multiple declaration of %s\n\n", line_count, $2->getname().c_str());
					fprintf(logout,"Error at line %d: multiple declaration of %s\n\n", line_count, $2->getname().c_str());
				}

				$$ = new SymbolInfo(declaration, "FUNC_DECLARATION");
			}
			;

			func_definition : type_specifier ID LPAREN parameter_list RPAREN {function_validity();} compound_statement {

				string def=$1->getname()+" "+$2->getname()+"(";

				string term="TERMINAL";
				for(int i=0; i<$4->get_param_size(); i++)
				{
					if($4->get_param(i)->gettype()==term) def+=$4->get_param(i)->getname();
					else def+=$4->get_param(i)->get_var_ret_type()+" "+$4->get_param(i)->getname();
					if(i!=($4->get_param_size()-1)) def+=", ";
				}

				def+=")"+$7->getname();

				$$=new SymbolInfo(def, ret_type);

				fprintf(logout,"Line %d: func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement\n\n", line_count);
				fprintf(logout,"%s\n\n", $$->getname().c_str());

				$$->add_code("\n\t;Line "+to_string(line_count)+": func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement");

				if($2->getname()=="main") {
					string main_proc = "\nMAIN PROC\
					\n\t;INITIALIZE DATA SEGMENT\
					\n\tMOV AX, @DATA\
					\n\tMOV DS, AX\n\n";

					string dos_exit = "\n\tDOSEXIT:\
					\n\t;DOX EXIT\
					\n\tMOV AH, 4CH\
					\n\tINT 21H\
					\nMAIN ENDP\n";

					$$->add_code(main_proc);
					$$->add_code($7->get_code());
					$$->add_code(dos_exit);
				}

				else
				{
					$$->add_code("\n"+$2->getname()+" PROC\n\tPOP ADDRESS");

					int local_var_cnt = local_vars.size()-1;
					for(int i=0; i<=local_var_cnt; i++)
					{
						$$->add_code("\n\tPOP "+local_vars[local_var_cnt-i]);
					}

					$$->add_code($7->get_code());
					$$->add_code("\n" + $2->getname() + " ENDP\n\n");

					/*string endp = "\n\tPUSH ADDRESS\
					\n\tRET\n" + $2->getname() + " ENDP\n\n";

					$$->add_code(endp);*/
				}

				local_vars.clear();
				ret_vars.clear();

			}
			| type_specifier ID LPAREN RPAREN {function_validity();} compound_statement {

				string def=$1->getname()+" "+$2->getname()+"()"+$6->getname();

				$$=new SymbolInfo(def, ret_type);

				fprintf(logout,"Line %d: func_definition : type_specifier ID LPAREN RPAREN compound_statement\n\n", line_count);
				fprintf(logout,"%s\n\n", $$->getname().c_str());

				$$->add_code("\n\t;Line "+to_string(line_count)+": func_definition : type_specifier ID LPAREN RPAREN compound_statement");

				if($2->getname()=="main")
				{
					string main_proc = "\nMAIN PROC\
					\n\t;INITIALIZE DATA SEGMENT\
					\n\tMOV AX, @DATA\
					\n\tMOV DS, AX\n\n";

					string dos_exit = "\n\tDOSEXIT:\
					\n\t;DOX EXIT\
					\n\tMOV AH, 4CH\
					\n\tINT 21H\
					\nMAIN ENDP\n";

					$$->add_code(main_proc);
					$$->add_code($6->get_code());
					$$->add_code(dos_exit);
				}

				else
				{
					$$->add_code("\n"+$2->getname()+" PROC\n\tPOP ADDRESS");

					int local_var_cnt = local_vars.size()-1;
					for(int i=0; i<=local_var_cnt; i++)
					{
						$$->add_code("\n\tPOP "+local_vars[local_var_cnt-i]);
					}

					$$->add_code($6->get_code());

					string endp = "\n\tPUSH ADDRESS\
					\n\tRET\n" + $2->getname() + " ENDP\n\n";

					$$->add_code(endp);
				}

				local_vars.clear();
				ret_vars.clear();
			}
			;


			parameter_list  : parameter_list COMMA type_specifier ID {
				fprintf(logout,"Line %d: parameter_list : parameter_list COMMA type_specifier ID\n\n", line_count);

				SymbolInfo* temp = new SymbolInfo($4->getname(), $3->getname());
				//temp->set_unit_type(2);
				temp->set_var_ret_type($3->getname());
				$$->add_param(temp);
				saved_list.push_back(temp);

				string term="TERMINAL";
				for(int i=0; i<$$->get_param_size(); i++)
				{
					if($$->get_param(i)->gettype()==term) fprintf(logout,"%s", $$->get_param(i)->getname().c_str());
					else fprintf(logout,"%s %s",$$->get_param(i)->gettype().c_str(), $$->get_param(i)->getname().c_str());
					if(i!=($$->get_param_size()-1)) fprintf(logout,", ");
				}
				fprintf(logout,"\n\n");
			}
			| parameter_list COMMA type_specifier {
				fprintf(logout,"Line %d: parameter_list : parameter_list COMMA type_specifier\n\n", line_count);

				//$3->set_unit_type(2);
				$3->set_var_ret_type($3->getname());
				$$->add_param($3);
				saved_list.push_back($3);

				string term="TERMINAL";
				for(int i=0; i<$$->get_param_size(); i++)
				{
					if($$->get_param(i)->gettype()==term) fprintf(logout,"%s", $$->get_param(i)->getname().c_str());
					else fprintf(logout,"%s %s",$$->get_param(i)->gettype().c_str(), $$->get_param(i)->getname().c_str());
					if(i!=($$->get_param_size()-1)) fprintf(logout,", ");
				}
				fprintf(logout,"\n\n");
			}
			| parameter_list error {
				if(!(find(syntax_error_lines.begin(), syntax_error_lines.end(), line_count) != syntax_error_lines.end())){
					syntax_error_lines.push_back(line_count);
					error_count++;
					fprintf(error,"Error at line %d: syntax error\n\n", line_count);
					fprintf(logout,"Error at line %d: syntax error\n\n", line_count);
				}


				string term="TERMINAL";
				for(int i=0; i<$$->get_param_size(); i++)
				{
					if($$->get_param(i)->gettype()==term) fprintf(logout,"%s", $$->get_param(i)->getname().c_str());
					else fprintf(logout,"%s %s",$$->get_param(i)->gettype().c_str(), $$->get_param(i)->getname().c_str());
					if(i!=($$->get_param_size()-1)) fprintf(logout,", ");
				}
				fprintf(logout,"\n\n");

			}
			| type_specifier ID {
				fprintf(logout,"Line %d: parameter_list : type_specifier ID\n\n", line_count);
				fprintf(logout,"%s %s\n\n", $1->getname().c_str(), $2->getname().c_str());

				SymbolInfo* temp = new SymbolInfo($2->getname(), $1->getname());
				//temp->set_unit_type(2);
				temp->set_var_ret_type($1->getname());
				$$->add_param(temp);
				saved_list.push_back(temp);
			}
			| type_specifier {
				$$ = new SymbolInfo($1->getname(), "PARAMETER_LIST");
				fprintf(logout,"Line %d: parameter_list : type_specifier\n\n", line_count);
				fprintf(logout,"%s\n\n", $1->getname().c_str());

				//$1->set_unit_type(2);
				$1->set_var_ret_type($1->getname());
				$$->add_param($1);
				saved_list.push_back($1);
			}
			;

			compound_statement : LCURL{fill_scope();} statements RCURL {
				$3->setname("{\n"+$3->getname()+"\n}");
				$$ = $3;
				fprintf(logout,"Line %d: compound_statement : LCURL statements RCURL\n\n", line_count);
				fprintf(logout,"%s\n\n", $$->getname().c_str());

				st.PrintAllScopeTable(logout);
				st.ExitScope(logout);

			}
			| LCURL{fill_scope();} RCURL {
				$$ = new SymbolInfo("{}", "");
				fprintf(logout,"Line %d: compound_statement : LCURL RCURL\n\n", line_count);
				fprintf(logout,"%s\n\n", $$->getname().c_str());

				st.PrintAllScopeTable(logout);
				st.ExitScope(logout);

			}
			;

			var_declaration : type_specifier declaration_list SEMICOLON {
				fprintf(logout,"Line %d: var_declaration : type_specifier declaration_list SEMICOLON\n\n", line_count);

				string declaration="";
				declaration+=$1->getname()+"  ";
				fprintf(logout,"%s  ", $1->getname().c_str());
				for(int i=0; i<$2->get_param_size(); i++)
				{
					fprintf(logout,"%s", $2->get_param(i)->getname().c_str());
					declaration+=$2->get_param(i)->getname();
					if($2->get_param(i)->get_array_size()>0){
						fprintf(logout,"[%d]",$2->get_param(i)->get_array_size());
						declaration+="["+to_string($2->get_param(i)->get_array_size())+"]";
					}
					if(i!=($2->get_param_size()-1)){
						fprintf(logout,",");
						declaration+=",";
					}
				}
				fprintf(logout,";\n\n\n");
				declaration+=";";

				if($1->getname()=="void"){
					error_count++;
					fprintf(error,"Error at line %d: variable type can not be void\n\n", line_count);
					fprintf(logout,"Error at line %d: variable type can not be void\n\n", line_count);
					$1->setname("float");
				}

				for(int i=0; i<$2->get_param_size(); i++)
				{

					if(!st.Insert($2->get_param(i))){
						error_count++;
						fprintf(error,"Error at line %d: multiple declaration of %s\n\n", line_count, $2->get_param(i)->getname().c_str());
						fprintf(logout,"Error at line %d: multiple declaration of %s\n\n", line_count, $2->get_param(i)->getname().c_str());
					}
					//st.Insert($2->get_param(i));
				}

				$$ = new SymbolInfo(declaration, "VAR_DECLARATION");
				$2->clear_params();
			}
			;

			type_specifier	: INT {
				$$ = new SymbolInfo("int", "TERMINAL");
				fprintf(logout,"Line %d: type_specifier : INT\n\n", line_count);
				fprintf(logout,"int \n\n");
				type = "int";
				type_name.push_back(type);
			}
			| FLOAT {
				$$ = new SymbolInfo("float", "TERMINAL");
				fprintf(logout,"Line %d: type_specifier : FLOAT\n\n", line_count);
				fprintf(logout,"float \n\n");
				type = "float";
				type_name.push_back(type);
			}
			| VOID {
				//printf("VOID %d\n", line_count);
				$$ = new SymbolInfo("void", "TERMINAL");
				fprintf(logout,"Line %d: type_specifier : VOID\n\n", line_count);
				fprintf(logout,"void \n\n");
				type = "void";
				type_name.push_back(type);
			}
			;

			declaration_list : declaration_list COMMA ID {
				//Add to variable list for initial declaration
				initializeVariables.push_back({$3->getname()+st.getTableID(),-1});

				//Previous Code
				fprintf(logout,"Line %d: declaration_list : declaration_list COMMA ID\n\n", line_count);
				$3->set_unit_type(1);
				$3->set_var_ret_type(type);

				$3->set_assebly_symbol($3->getname()+st.getTableID());

				$$->add_param($3);

				for(int i=0; i<$$->get_param_size(); i++)
				{
					fprintf(logout,"%s", $$->get_param(i)->getname().c_str());
					if($$->get_param(i)->get_array_size()>0) fprintf(logout,"[%d]",$$->get_param(i)->get_array_size());
					if(i!=($$->get_param_size()-1)) fprintf(logout,",");
				}
				fprintf(logout,"\n\n");
			}

			| declaration_list COMMA ID LTHIRD CONST_INT RTHIRD {
				//Add to variable list for initial declaration
				initializeVariables.push_back({$3->getname()+st.getTableID(), atoi($5->getname().c_str())});

				//Previous Code
				fprintf(logout,"Line %d: declaration_list : declaration_list COMMA ID LTHIRD CONST_INT RTHIRD\n\n", line_count);
				$3->set_unit_type(1);
				$3->set_var_ret_type(type);
				$3->set_array_size(atoi($5->getname().c_str()));

				$3->set_assebly_symbol($3->getname()+st.getTableID());

				$$->add_param($3);

				for(int i=0; i<$$->get_param_size(); i++)
				{
					fprintf(logout,"%s", $$->get_param(i)->getname().c_str());
					if($$->get_param(i)->get_array_size()>0) fprintf(logout,"[%d]",$$->get_param(i)->get_array_size());
					if(i!=($$->get_param_size()-1)) fprintf(logout,", ");
				}
				fprintf(logout,"\n\n");
			}

			| declaration_list error {
				if(!(find(syntax_error_lines.begin(), syntax_error_lines.end(), line_count) != syntax_error_lines.end())){
					syntax_error_lines.push_back(line_count);
					error_count++;
					fprintf(error,"Error at line %d: syntax error\n\n", line_count);
					fprintf(logout,"Error at line %d: syntax error\n\n", line_count);
				}

				for(int i=0; i<$$->get_param_size(); i++)
				{
					fprintf(logout,"%s", $$->get_param(i)->getname().c_str());
					if($$->get_param(i)->get_array_size()>0) fprintf(logout,"[%d]",$$->get_param(i)->get_array_size());
					if(i!=($$->get_param_size()-1)) fprintf(logout,", ");
				}
				fprintf(logout,"\n\n");
			}

			| ID {
				//Add to variable list for initial declaration
				initializeVariables.push_back({$1->getname()+st.getTableID(),-1});

				//Previous Code
				$$ = new SymbolInfo("declaration_list", "DECLARATION_LIST");
				fprintf(logout,"Line %d: declaration_list : ID\n\n", line_count);
				fprintf(logout,"%s\n\n",$1->getname().c_str());

				$1->set_unit_type(1);
				$1->set_var_ret_type(type);

				$1->set_assebly_symbol($1->getname()+st.getTableID());

				$$->add_param($1);
			}

			| ID LTHIRD CONST_INT RTHIRD {
				//Add to variable list for initial declaration
				initializeVariables.push_back({$1->getname()+st.getTableID(),atoi($3->getname().c_str())});

				//Previous Code
				$$ = new SymbolInfo("declaration_list", "DECLARATION_LIST");
				fprintf(logout,"Line %d: declaration_list : ID LTHIRD CONST_INT RTHIRD\n\n", line_count);
				fprintf(logout,"%s[%s]\n\n",$1->getname().c_str(), $3->getname().c_str());

				$1->set_unit_type(1);
				$1->set_var_ret_type(type);
				$1->set_array_size(atoi($3->getname().c_str()));

				$1->set_assebly_symbol($1->getname()+st.getTableID());

				$$->add_param($1);
			}
			;

			statements : statement {
				$$ = $1;
				fprintf(logout,"Line %d: statements : statement\n\n", line_count);
				fprintf(logout,"%s\n\n", $$->getname().c_str());

				$$->set_code($1->get_code());
			}
			| statements statement {

				$1->setname($1->getname()+"\n"+$2->getname());
				$$ = $1;
				fprintf(logout,"Line %d: statements : statements statement\n\n", line_count);
				fprintf(logout,"%s\n\n", $$->getname().c_str());

				$$->set_code($1->get_code());
				$$->add_code($2->get_code());

			}
			| statements error {
				if(!(find(syntax_error_lines.begin(), syntax_error_lines.end(), line_count) != syntax_error_lines.end()))
				{
					syntax_error_lines.push_back(line_count);
					error_count++;
					fprintf(error,"Error at line %d: syntax error\n\n", line_count);
					fprintf(logout,"Error at line %d: syntax error\n\n", line_count);
				}

				fprintf(logout,"%s\n\n", $$->getname().c_str());

			}
			;

			statement : var_declaration {
				$$ = $1;
				fprintf(logout,"Line %d: statement : var_declaration\n\n", line_count);
				fprintf(logout,"%s\n\n", $$->getname().c_str());

			}
			| expression_statement {
				$$ = $1;
				fprintf(logout,"Line %d: statement : expression_statement\n\n", line_count);
				fprintf(logout,"%s\n\n", $$->getname().c_str());

				$$->set_code($1->get_code());

			}
			| compound_statement {
				$$ = $1;
				fprintf(logout,"Line %d: statement : compound_statement\n\n", line_count);
				fprintf(logout,"%s\n\n", $$->getname().c_str());

			}
			| FOR LPAREN expression_statement expression_statement expression RPAREN statement {
				$3->setname("for("+$3->getname()+ $4->getname()+$5->getname()+")"+$7->getname());
				$$ = $3;
				fprintf(logout,"Line %d: statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement\n\n", line_count);
				fprintf(logout,"%s\n\n", $$->getname().c_str());

				//Temporary Variable Creation and add to intial
				string temp_var_in = newLabel("FORLOOP_IN");
				string temp_var_out = newLabel("FORLOOP_OUT");

				string forcode = $3->get_code();
				$$->set_code("\n\n\t;Line "+to_string(line_count)+": statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement");
				$$->add_code(forcode);
				$$->add_code("\n\t" + temp_var_in + ":");
				$$->add_code($4->get_code());
				$$->add_code("\n\tMOV AX, " + $4->get_assembly_symbol());
				$$->add_code("\n\tCMP AX, 0");
				$$->add_code("\n\tJE "+temp_var_out+"\n");
				$$->add_code($5->get_code()+$7->get_code());
				$$->add_code("\n\tJMP "+temp_var_in);
				$$->add_code("\n\t"+temp_var_out+":\n");

			}
			| IF LPAREN expression RPAREN statement  %prec LOWER_THAN_ELSE {
				$3->setname("if("+$3->getname()+")"+$5->getname());
				$$ = $3;
				fprintf(logout,"Line %d: statement : IF LPAREN expression RPAREN statement\n\n", line_count);
				fprintf(logout,"%s\n\n", $$->getname().c_str());

				//Temporary Variable Creation and add to intial
				string code_3 = $3->get_code();
				string temp_var = newLabel("CONDITIONAL_WITHOUT_ELSE_OUT");
				$$->set_code("\n\n\t;Line "+to_string(line_count)+": statement : IF LPAREN expression RPAREN statement");
				$$->add_code(code_3);
				$$->add_code("\n\tMOV AX, " + $3->get_assembly_symbol());
				$$->add_code("\n\tCMP AX, 0");
				$$->add_code("\n\tJE " + temp_var);
				$$->add_code($5->get_code());
				$$->add_code("\n\t" + temp_var+":\n");

			}
			| IF LPAREN expression RPAREN statement ELSE statement {
				$3->setname("if("+$3->getname()+")"+$5->getname()+"\nelse\n"+$7->getname());
				$$ = $3;
				fprintf(logout,"Line %d: statement : IF LPAREN expression RPAREN statement ELSE statement\n\n", line_count);
				fprintf(logout,"%s\n\n", $$->getname().c_str());

				string exp_code = $3->get_code();
				//Temporary Variable Creation and add to intial
				string temp_var = newLabel("CONDITIONAL_ELSE");
				string temp_var2 = newLabel("CONDITIONAL_OUT");
				$$->set_code("\n\n\t;Line "+to_string(line_count)+": statement : IF LPAREN expression RPAREN statement ELSE statement");
				$$->add_code(exp_code);
				$$->add_code("\n\tMOV AX, " + $3->get_assembly_symbol());
				$$->add_code("\n\tCMP AX, 0");
				$$->add_code("\n\tJE " + temp_var);
				$$->add_code($5->get_code());
				$$->add_code("\n\tJMP " + temp_var2);
				$$->add_code("\n\t" + temp_var+": ");
				$$->add_code($7->get_code());
				$$->add_code("\n\t" + temp_var2+": ");

			}
			| WHILE LPAREN expression RPAREN statement {
				$3->setname("while("+$3->getname()+")"+$5->getname());
				$$ = $3;
				fprintf(logout,"Line %d: statement : WHILE LPAREN expression RPAREN statement\n\n", line_count);
				fprintf(logout,"%s\n\n", $$->getname().c_str());

				string while_in = newLabel("WHILE_IN");
				string while_out = newLabel("WHILE_OUT");

				string whilecode = $3->get_code();
				$$->set_code("\n\n\t;Line "+to_string(line_count)+": statement : WHILE LPAREN expression RPAREN statement");
				$$->add_code("\n\t"+while_in+":");
				$$->add_code(whilecode);
				$$->add_code("\n\tMOV AX, "+$3->get_assembly_symbol());
				$$->add_code("\n\tCMP AX, 0");
				$$->add_code("\n\tJE "+while_out);
				$$->add_code("\n\t"+$5->get_code());
				$$->add_code("\n\tJMP "+while_in);
				$$->add_code("\n\t"+while_out+":");

			}
			| PRINTLN LPAREN ID RPAREN SEMICOLON {
				string name3 = $3->getname();
				$3->setname("printf("+$3->getname()+");");
				$$ = $3;

				fprintf(logout,"Line %d: statement : PRINTLN LPAREN ID RPAREN SEMICOLON\n\n", line_count);
				fprintf(logout,"%s\n\n", $$->getname().c_str());

				SymbolInfo temp;
				bool does_exist = st.Lookup(name3, temp);

				if(!does_exist){

					error_count++;
					fprintf(error,"Error at line %d: Undeclared variable %s\n\n", line_count, name3.c_str());
					fprintf(logout,"Error at line %d: Undeclared variable %s\n\n", line_count, name3.c_str());
				}
				else {
					if(temp.get_array_size()!=$3->get_array_size()){
						error_count++;
						fprintf(error,"Error at line %d: Type mismatch %s is an array\n\n", line_count, temp.getname().c_str());
						fprintf(logout,"Error at line %d: Type mismatch %s is an array\n\n", line_count, temp.getname().c_str());
					}
				}

				string print_cmd =
				"\n\n\t;Line "+to_string(line_count)+": PRINTLN LPAREN ID RPAREN SEMICOLON\
				\n\tPUSH AX\
				\n\tPUSH BX\
				\n\tPUSH CX\
				\n\tPUSH DX\
				\n\tPUSH ADDRESS\
				\n\tPUSH " + temp.get_assembly_symbol() +
				"\n\tCALL PRINT\
				\n\tPOP ADDRESS\
				\n\tPOP DX\
				\n\tPOP CX\
				\n\tPOP BX\
				\n\tPOP AX\n" ;

				$$->set_code(print_cmd);

			}
			| RETURN expression SEMICOLON {
				$2->setname("return "+$2->getname()+";");
				$$ = $2;
				$$->set_var_ret_type($2->gettype());
				fprintf(logout,"Line %d: statement : RETURN expression SEMICOLON\n\n", line_count);
				fprintf(logout,"%s\n\n", $$->getname().c_str());

				string returncode = $2->get_code();
				$$->set_code("\n\n\t;Line "+to_string(line_count)+": statement : RETURN expression SEMICOLON");
				$$->add_code(returncode);
				$$->add_code("\n\tPUSH " + $2->get_assembly_symbol());
				$$->add_code("\n\tPUSH ADDRESS");
				if(func_name!="main") $$->add_code("\n\tRET\n");
			}

			;

			expression_statement : SEMICOLON {

				$$ = new SymbolInfo(";", "SEMICOLON");
				fprintf(logout,"Line %d: expression_statement : SEMICOLON\n\n", line_count);
				fprintf(logout,";\n\n");

				$$->set_assebly_symbol(";");
			}
			| expression SEMICOLON {
				$1->setname($1->getname()+";");
				fprintf(logout,"Line %d: expression_statement : expression SEMICOLON\n\n", line_count);
				fprintf(logout,"%s\n\n", $1->getname().c_str());
				$$ = $1;

			}
			;

			variable : ID {

				fprintf(logout,"Line %d: variable : ID\n\n", line_count);
				fprintf(logout,"%s\n\n", $1->getname().c_str());

				SymbolInfo temp;
				bool does_exist = st.Lookup($1->getname(), temp);
				if(does_exist){

					if(temp.get_array_size()!=$1->get_array_size()){
						error_count++;
						fprintf(error,"Error at line %d: Type mismatch %s is an array\n\n", line_count, temp.getname().c_str());
						fprintf(logout,"Error at line %d: Type mismatch %s is an array\n\n", line_count, temp.getname().c_str());
					}
					$1->settype(temp.get_var_ret_type());
					$1->set_assebly_symbol(temp.get_assembly_symbol());
					if($1->gettype()=="void") $1->settype("float");
				}
				else{
					error_count++;
					fprintf(error,"Error at line %d: Undeclared variable %s\n\n", line_count, $1->getname().c_str());
					fprintf(logout,"Error at line %d: Undeclared variable %s\n\n", line_count, $1->getname().c_str());

					is_undeclared = 1;
					$1->settype("float"); //default
				}

				$$ = $1;
			}
			;
			| ID LTHIRD expression RTHIRD {
				string arr_name = $1->getname();
				$1->setname($1->getname()+"["+ $3->getname()+"]");
				fprintf(logout,"Line %d: variable : ID LTHIRD expression RTHIRD\n\n", line_count);
				fprintf(logout,"%s\n\n", $1->getname().c_str());

				SymbolInfo temp;
				bool does_exist = st.Lookup(arr_name, temp);
				int parsed_index = atoi($3->getname().c_str());

				if(does_exist){

					$1->settype(temp.get_var_ret_type());
					$1->set_array_size(temp.get_array_size());
					if($1->gettype()=="void") $1->settype("float");
				}
				else{
					error_count++;
					fprintf(error,"Error at line %d: undeclared variable %s\n\n", line_count, $1->getname().c_str());
					fprintf(logout,"Error at line %d: undeclared variable %s\n\n", line_count, $1->getname().c_str());

					is_undeclared = 1;
					$1->settype("float"); //default
				}


				if(does_exist && temp.get_array_size()==-1){
					error_count++;
					fprintf(error,"Error at line %d: type mismatch(not array)\n\n", line_count);
					fprintf(logout,"Error at line %d: type mismatch(not array)\n\n", line_count);
				}

				else if($3->gettype()!="int"){
					error_count++;
					fprintf(error,"Error at line %d: non-integer array index\n\n", line_count);
					fprintf(logout,"Error at line %d: non-integer array index\n\n", line_count);
				}

				else if(does_exist && temp.get_array_size()<=parsed_index){
					error_count++;
					fprintf(error,"Error at line %d: Array index out of range\n\n", line_count);
					fprintf(logout,"Error at line %d: Array index out of range\n\n", line_count);
				}

				$$ = $1;

				$$->set_code("\n\t;Line "+to_string(line_count)+": variable : ID LTHIRD expression RTHIRD");
				$$->add_code($3->get_code());
				$$->add_code("\n\tMOV BX, "+$3->get_assembly_symbol());
				$$->add_code("\n\tSHL BX, 1");

				$$->set_assebly_symbol(temp.get_assembly_symbol());
			}
			;

			expression : logic_expression {

				$$ = $1;
				fprintf(logout,"Line %d: expression : logic_expression\n\n", line_count);
				fprintf(logout,"%s\n\n", $1->getname().c_str());

			}
			| variable ASSIGNOP logic_expression {

				SymbolInfo temp;
				bool does_exist = st.Lookup(id_name[id_name.size()-1], temp);



				$1->setname($1->getname()+"="+ $3->getname());
				fprintf(logout,"Line %d: expression : variable ASSIGNOP logic_expression\n\n", line_count);
				fprintf(logout,"%s\n\n", $1->getname().c_str());

				string check_void = $3->gettype();
				if(check_void=="ID") check_void = $3->get_var_ret_type();
				if(void_error(check_void)) $3->settype($1->gettype());

				string type3 = $3->gettype();
				if(type3=="ID") type3 = $3->get_var_ret_type();


				if(type3!=$1->gettype() && !($1->gettype()=="float" && type3=="int")){
					if(is_undeclared) is_undeclared = 0;
					else if(does_exist){
						error_count++;
						fprintf(error,"Error at line %d: type mismatch(%s = %s)\n\n", line_count, $1->gettype().c_str(), type3.c_str());
						fprintf(logout,"Error at line %d: type mismatch(%s = %s)\n\n", line_count, $1->gettype().c_str(), type3.c_str());
					}
					else{
						$1->settype(type3); //undeclared variable typecasting
					}

				}

				$$ = $1;

				string code_1 = $1->get_code();
				$$->set_code("\n\t;Line "+to_string(line_count)+": expression : variable ASSIGNOP logic_expression");
				if($1->get_array_size()>0)
				{
					//Temporary Variable Creation and add to intial
					string temp_var =  newTemp();

					$$->add_code(code_1);
					$$->add_code($3->get_code());
					$$->add_code("\n\tMOV AX, "+$3->get_assembly_symbol());
					$$->add_code("\n\tMOV " + $1->get_assembly_symbol() + "[BX], AX");
					$$->add_code("\n\tMOV " + temp_var +", AX");
					$$->set_assebly_symbol(temp_var);
				}
				else {
					$$->add_code(code_1);
					$$->add_code($3->get_code());
					$$->add_code("\n\tMOV AX, "+$3->get_assembly_symbol());
					$$->add_code("\n\tMOV " + $1->get_assembly_symbol() +", AX");
					$$->set_assebly_symbol($1->get_assembly_symbol());
				}
			}
			;

			logic_expression : rel_expression {

				$$ = $1;
				fprintf(logout,"Line %d: logic_expression : rel_expression\n\n", line_count);
				fprintf(logout,"%s\n\n", $1->getname().c_str());
			}
			| rel_expression LOGICOP rel_expression {
				$1->setname($1->getname()+$2->getname()+$3->getname());
				fprintf(logout,"Line %d: logic_expression : rel_expression LOGICOP rel_expression\n\n", line_count);
				fprintf(logout,"%s\n\n", $1->getname().c_str());
				$$ = $1;

				//void checking
				string check_void = $1->gettype();
				if(check_void=="ID") check_void = $1->get_var_ret_type();
				string check_void3 = $3->gettype();
				if(check_void3=="ID") check_void3 = $3->get_var_ret_type();
				if(void_error(check_void)) $1->settype(check_void3);
				if(void_error(check_void3)) $3->settype(check_void);

				if(check_void=="void" && check_void3=="void") {
					$1->settype("float");
					$3->settype("float");
				}

				$$->settype("int");

				string temp_var = newTemp();
				string temp_label_out_all = newLabel("LOGICOP_OUT_OF_THE_BLOCK");
				string temp_label_out = newLabel("LOGICOP_SKIP_VALUE_SETTING");

				string code_1 = $1->get_code();
				$$->set_code("\n\t;Line "+to_string(line_count)+": logic_expression : rel_expression LOGICOP rel_expression");
				$$->add_code(code_1);
				$$->add_code($3->get_code());

				if($2->getname()=="&&") {
					$$->add_code("\n\tMOV AX, " + $1->get_assembly_symbol());
					$$->add_code("\n\tCMP AX, 0");
					$$->add_code("\n\tJE " + temp_label_out);

					$$->add_code("\n\tMOV AX, " + $3->get_assembly_symbol());
					$$->add_code("\n\tCMP AX, 0");
					$$->add_code("\n\tJE " + temp_label_out);

					$$->add_code("\n\tMOV AX, 1");
					$$->add_code("\n\tMOV "+ temp_var +", AX");
					$$->add_code("\n\tJMP " + temp_label_out_all);

					$$->add_code("\n\t"+ temp_label_out +":");
					$$->add_code("\n\tMOV AX, 0");
					$$->add_code("\n\tMOV "+ temp_var +", AX");

					$$->add_code("\n\t"+ temp_label_out_all +":");
				}

				else if($2->getname()=="||") {
					$$->add_code("\n\tMOV AX, " + $1->get_assembly_symbol());
					$$->add_code("\n\tCMP AX, 0");
					$$->add_code("\n\tJNE " + temp_label_out);

					$$->add_code("\n\tMOV AX, " + $3->get_assembly_symbol());
					$$->add_code("\n\tCMP AX, 0");
					$$->add_code("\n\tJNE " + temp_label_out);

					$$->add_code("\n\tMOV AX, 0");
					$$->add_code("\n\tMOV "+ temp_var +", AX");
					$$->add_code("\n\tJMP " + temp_label_out_all);

					$$->add_code("\n\t"+ temp_label_out +":");
					$$->add_code("\n\tMOV AX, 1");
					$$->add_code("\n\tMOV "+ temp_var +", AX");

					$$->add_code("\n\t"+ temp_label_out_all +":");
				}

				$$->set_assebly_symbol(temp_var);


			}
			;

			rel_expression	: simple_expression {

				$$ = $1;
				fprintf(logout,"Line %d: rel_expression : simple_expression\n\n", line_count);
				fprintf(logout,"%s\n\n", $1->getname().c_str());
			}
			| simple_expression RELOP simple_expression {
				$1->setname($1->getname()+$2->getname()+$3->getname());
				fprintf(logout,"Line %d: rel_expression : simple_expression RELOP simple_expression\n\n", line_count);
				fprintf(logout,"%s\n\n", $1->getname().c_str());
				$$ = $1;

				//void checking
				string check_void = $1->gettype();
				if(check_void=="ID") check_void = $1->get_var_ret_type();
				string check_void3 = $3->gettype();
				if(check_void3=="ID") check_void3 = $3->get_var_ret_type();
				if(void_error(check_void)) $1->settype(check_void3);
				if(void_error(check_void3)) $3->settype(check_void);

				if(check_void=="void" && check_void3=="void") {
					$1->settype("float");
					$3->settype("float");
				}

				$$->settype("int");

				string temp_var = newTemp();
				string temp_label_in = newLabel("RELOP");
				string temp_label_out = newLabel("RELOP");

				string code_1 = $1->get_code();
				$$->set_code("\n\t;Line "+to_string(line_count)+": rel_expression : simple_expression RELOP simple_expression");

				$$->add_code(code_1);
				$$->add_code($3->get_code());
				$$->add_code("\n\tMOV AX, " + $1->get_assembly_symbol());
				$$->add_code("\n\tCMP AX, " + $3->get_assembly_symbol());


				if($2->getname()=="<") {
					$$->add_code("\n\tJL "+ temp_label_in );
					$$->add_code("\n\tMOV AX, 0");
					$$->add_code("\n\tMOV "+temp_var+", AX");
					$$->add_code("\n\tJMP "+ temp_label_out);
					$$->add_code("\n\t"+ temp_label_in +":");
					$$->add_code("\n\tMOV AX, 1");
					$$->add_code("\n\tMOV "+temp_var+", AX");
					$$->add_code("\n\t"+ temp_label_out + ":");
				}
				else if($2->getname()=="<=") {
					$$->add_code("\n\tJLE "+ temp_label_in);
					$$->add_code("\n\tMOV AX, 0");
					$$->add_code("\n\tMOV "+temp_var+", AX");
					$$->add_code("\n\tJMP "+ temp_label_out);
					$$->add_code("\n\t"+ temp_label_in +":");
					$$->add_code("\n\tMOV AX, 1");
					$$->add_code("\n\tMOV "+temp_var+", AX");
					$$->add_code("\n\t"+ temp_label_out + ":");
				}
				else if($2->getname()==">") {
					$$->add_code("\n\tJG "+ temp_label_in);
					$$->add_code("\n\tMOV AX, 0");
					$$->add_code("\n\tMOV "+temp_var+", AX");
					$$->add_code("\n\tJMP "+ temp_label_out);
					$$->add_code("\n\t"+ temp_label_in +":");
					$$->add_code("\n\tMOV AX, 1");
					$$->add_code("\n\tMOV "+temp_var+", AX");
					$$->add_code("\n\t"+ temp_label_out + ":");
				}
				else if($2->getname()==">=") {
					$$->add_code("\n\tJGE "+ temp_label_in);
					$$->add_code("\n\tMOV AX, 0");
					$$->add_code("\n\tMOV "+temp_var+", AX");
					$$->add_code("\n\tJMP "+ temp_label_out);
					$$->add_code("\n\t"+ temp_label_in +":");
					$$->add_code("\n\tMOV AX, 1");
					$$->add_code("\n\tMOV "+temp_var+", AX");
					$$->add_code("\n\t"+ temp_label_out + ":");
				}
				else if($2->getname()=="==") {
					$$->add_code("\n\tJE "+ temp_label_in);
					$$->add_code("\n\tMOV AX, 0");
					$$->add_code("\n\tMOV "+temp_var+", AX");
					$$->add_code("\n\tJMP "+ temp_label_out );
					$$->add_code("\n\t"+ temp_label_in +":");
					$$->add_code("\n\tMOV AX, 1");
					$$->add_code("\n\tMOV "+temp_var+", AX");
					$$->add_code("\n\t"+ temp_label_out + ":");
				}
				else if($2->getname()=="!=") {
					$$->add_code("\n\tJNE "+ temp_label_in );
					$$->add_code("\n\tMOV AX, 0");
					$$->add_code("\n\tMOV "+temp_var+", AX");
					$$->add_code("\n\tJMP "+ temp_label_out );
					$$->add_code("\n\t"+ temp_label_in +":");
					$$->add_code("\n\tMOV AX, 1");
					$$->add_code("\n\tMOV "+temp_var+", AX");
					$$->add_code("\n\t"+ temp_label_out + ":");
				}

				$$->set_assebly_symbol(temp_var);

			}
			;

			simple_expression : term {
				$$ = $1;
				fprintf(logout,"Line %d: simple_expression : term\n\n", line_count);
				fprintf(logout,"%s\n\n", $1->getname().c_str());
			}
			| simple_expression ADDOP term {
				$1->setname($1->getname()+$2->getname()+$3->getname());
				fprintf(logout,"Line %d: simple_expression : simple_expression ADDOP term\n\n", line_count);
				fprintf(logout,"%s\n\n", $1->getname().c_str());
				$$ = $1;

				//void checking
				string check_void = $1->gettype();
				if(check_void=="ID") check_void = $1->get_var_ret_type();
				string check_void3 = $3->gettype();
				if(check_void3=="ID") check_void3 = $3->get_var_ret_type();
				if(void_error(check_void)) $1->settype(check_void3);
				if(void_error(check_void3)) $3->settype(check_void);

				if(check_void=="void" && check_void3=="void") {
					$1->settype("float");
					$3->settype("float");
				}

				if($1->gettype()=="float" || $3->gettype()=="float") $$->settype("float");
				else $$->settype("int");

				//Temporary Variable Creation and add to intial
				string temp_var = newTemp();

				string code_1 = $1->get_code();
				$$->set_code("\n\t;Line "+to_string(line_count)+": simple_expression : simple_expression ADDOP term");
				$$->add_code(code_1);
				$$->add_code($3->get_code());
				$$->add_code("\n\tMOV AX, " + $1->get_assembly_symbol());
				if($2->getname()=="+") {
					$$->add_code("\n\tADD AX, "+ $3->get_assembly_symbol());
				}
				else if($2->getname()=="-") {
					$$->add_code("\n\tSUB AX, "+ $3->get_assembly_symbol());
				}
				$$->add_code("\n\tMOV " + temp_var + ", AX");
				$$->set_assebly_symbol(temp_var);
			}
			;

			term :	unary_expression {
				$$ = $1;
				fprintf(logout,"Line %d: term : unary_expression\n\n", line_count);
				fprintf(logout,"%s\n\n", $1->getname().c_str());
			}
			|  term MULOP unary_expression {
				$1->setname($1->getname()+$2->getname()+$3->getname());
				fprintf(logout,"Line %d: term : term MULOP unary_expression\n\n", line_count);
				fprintf(logout,"%s\n\n", $1->getname().c_str());
				$$ = $1;

				//void checking
				string check_void = $1->gettype();
				if(check_void=="ID") check_void = $1->get_var_ret_type();
				string check_void3 = $3->gettype();
				if(check_void3=="ID") check_void3 = $3->get_var_ret_type();
				if(void_error(check_void)) $1->settype(check_void3);
				if(void_error(check_void3)) $3->settype(check_void);

				if(check_void=="void" && check_void3=="void") {
					$1->settype("float");
					$3->settype("float");
				}

				if(($2->getname()=="%")&&($1->gettype()!="int" || $3->gettype()!="int")) {
					error_count++;
					fprintf(error, "Error at line %d: Non-Integer operand on modulus operator\n\n", line_count);
					fprintf(logout, "Error at line %d: Non-Integer operand on modulus operator\n\n", line_count);
				}

				if(($2->getname()=="%")&&($1->getname()=="0" || $3->getname()=="0")) {
					error_count++;
					fprintf(error, "Error at line %d: Modulus by Zero\n\n", line_count);
					fprintf(logout, "Error at line %d: Modulus by Zero\n\n", line_count);
				}

				if($2->getname()=="%") $$->settype("int");
				else if($1->gettype()=="float" || $3->gettype()=="float") $$->settype("float");
				else $$->settype("int");

				//Temporary Variable Creation and add to intial
				string temp_var = newTemp();

				string code_1 = $1->get_code();
				$$->set_code("\n\t;Line "+to_string(line_count)+": term : term MULOP unary_expression");
				$$->add_code(code_1);
				$$->add_code($3->get_code());
				$$->add_code("\n\tMOV AX, " + $1->get_assembly_symbol());
				if($2->getname()=="*") {
					$$->add_code("\n\tMOV BX, " + $3->get_assembly_symbol());
					$$->add_code("\n\tIMUL BX");
					$$->add_code("\n\tMOV "+ temp_var +", AX");
				}
				else if($2->getname()=="/") {
					$$->add_code("\n\tCWD");
					$$->add_code("\n\tMOV BX, " + $3->get_assembly_symbol());
					$$->add_code("\n\tDIV BX");
					$$->add_code("\n\tMOV "+ temp_var +", AX");
				}
				else if($2->getname()=="%") {
					$$->add_code("\n\tCWD");
					$$->add_code("\n\tMOV BX, " + $3->get_assembly_symbol());
					$$->add_code("\n\tDIV BX");
					$$->add_code("\n\tMOV "+ temp_var +", DX");
				}

				$$->set_assebly_symbol(temp_var);

			}
			;

			unary_expression : ADDOP unary_expression {
				$2->setname($1->getname()+$2->getname());
				$$ = $2;
				fprintf(logout,"Line %d: unary_expression : ADDOP unary_expression\n\n", line_count);
				fprintf(logout,"%s\n\n", $2->getname().c_str());

				string check_void = $2->gettype();
				if(check_void=="ID") check_void = $2->get_var_ret_type();
				if(void_error(check_void)) $$->settype("float");

				string code_2 = $2->get_code();
				$$->set_code("\n\t;Line "+to_string(line_count)+": unary_expression : ADDOP unary_expression");
				$$->add_code(code_2);
				//Temporary Variable Creation and add to intial
				//IF ADDOP=="+" WE DONT HAVE TO DO ANYTHING
				if($1->getname()=="-")
				{
					string temp_var = newTemp();
					$$->add_code("\n\tMOV AX, "+$2->get_assembly_symbol());
					$$->add_code("\n\tMOV "+ temp_var +", AX");
					$$->add_code("\n\tNEG "+ temp_var);

					$$->set_assebly_symbol(temp_var);
				}


			}
			| NOT unary_expression {
				$2->setname("!"+$2->getname());
				$$ = $2;
				fprintf(logout,"Line %d: unary_expression : NOT unary_expression\n\n", line_count);
				fprintf(logout,"%s\n\n", $2->getname().c_str());

				string check_void = $2->gettype();
				if(check_void=="ID") check_void = $2->get_var_ret_type();
				if(void_error(check_void)) $$->settype("float");

				$$->settype("int"); //not operator always returns 0 or 1

				//Temporary Variable Creation and add to intial
				string temp_var = newTemp();
				string set_zero = newLabel("SET_ZERO");
				string set_done = newLabel("NEGATING_EXIT");

				string code_2 = $2->get_code();
				$$->set_code("\n\t;Line "+to_string(line_count)+": unary_expression : NOT unary_expression");
				$$->add_code(code_2);

				$$->add_code("\n\tMOV AX, " + $2->get_assembly_symbol());
				$$->add_code("\n\tCMP AX, 1");
				$$->add_code("\n\tJE " + set_zero );
				$$->add_code("\n\tMOV AX, 1");
				$$->add_code("\n\tMOV "+temp_var+", AX");
				$$->add_code("\n\tJMP " + set_done);

				$$->add_code("\n\t" + set_zero + ":");
				$$->add_code("\n\tMOV AX, 0");
				$$->add_code("\n\tMOV "+temp_var+", AX");
				$$->add_code("\n\t" + set_done + ":");

				$$->set_assebly_symbol(temp_var);
			}
			| factor {
				$$ = $1;
				fprintf(logout,"Line %d: unary_expression : factor\n\n", line_count);
				fprintf(logout,"%s\n\n", $1->getname().c_str());
			}
			;

			factor : variable {

				fprintf(logout,"Line %d: factor : variable\n\n", line_count);
				fprintf(logout,"%s\n\n", $1->getname().c_str());

				$$ = $1;


				if($$->get_array_size()>-1) {
					//Temporary Variable Creation and add to intial
					string temp_var = newTemp();

					string code_1 = $1->get_code();
					$$->set_code("\n\t;Line "+to_string(line_count)+": factor : variable");
					$$->add_code(code_1);
					$$->add_code("\n\tMOV AX, " + $1->get_assembly_symbol()+ "[bx]");
					$$->add_code("\n\tMOV " + temp_var + ", AX\n");
					$$->set_assebly_symbol(temp_var);
				}
			}
			| ID LPAREN argument_list RPAREN {

				string idname = $1->getname();
				$3->setname($1->getname()+"("+$3->getname()+")");
				fprintf(logout,"Line %d: factor : ID LPAREN argument_list RPAREN\n\n", line_count);
				fprintf(logout,"%s\n\n", $3->getname().c_str());



				$$ = $3;


				SymbolInfo temp;

				bool does_exist = st.Lookup(idname, temp);

				if(!does_exist){
					$$->settype("float");
					error_count++;
					fprintf(error, "Error at line %d: no such identifier found\n\n", line_count);
					fprintf(logout, "Error at line %d: no such identifier found\n\n", line_count);

					is_undeclared=1;
				}
				else if(temp.get_unit_type()!=3)
				{

					if(temp.get_unit_type()==2){
						$$->set_var_ret_type(temp.get_var_ret_type());
						$$->settype("ID");
					}
					else $$->settype("float");
					error_count++;
					fprintf(error, "Error at line %d: no such function definition found\n\n", line_count);
					fprintf(logout, "Error at line %d: no such function definition found\n\n", line_count);
				}
				else{

					$$->set_var_ret_type(temp.get_var_ret_type());
					bool is_exceptional = (temp.get_param_size() ==1 && $$->get_param_size()==0 && temp.get_param(0)->getname()=="void");
					if(is_exceptional) $$->settype(temp.gettype());

					if(temp.get_param_size()!=$$->get_param_size()){

						$$->settype("ID");
						error_count++;
						fprintf(error, "Error at line %d: Total number of arguments mismatch in function %s\n\n", line_count, temp.getname().c_str());
						fprintf(logout, "Error at line %d: Total number of arguments mismatch in function %s\n\n", line_count, temp.getname().c_str());
					}

					else{
						//bool is_default=false;

						for(int i=0; i<$$->get_param_size(); i++){

							string typemain = $$->get_param(i)->gettype();
							if(typemain=="ID") typemain = $$->get_param(i)->get_var_ret_type();

							if(temp.get_param(i)->get_var_ret_type()!=typemain)
							{

								//$$->settype("float");
								error_count++;
								fprintf(error, "Error at line %d: %dth argument mismatch in function %s\n\n", line_count, i+1, temp.getname().c_str());
								fprintf(logout, "Error at line %d: %dth argument mismatch in function %s\n\n", line_count, i+1, temp.getname().c_str());
								//is_default=true;
								break;
							}
						}

						//if(!is_default) $$->settype(temp.gettype());
						$$->settype(temp.get_var_ret_type());
					}
				}

				//Temporary Variable Creation and add to intial

				string temp_var =newTemp();

				string code_3 = $3->get_code();
				$$->set_code("\n\t;Line "+to_string(line_count)+": factor : ID LPAREN argument_list RPAREN");
				$$->add_code(code_3);

				$$->add_code("\n\n\t;FUNCTION_CALL_COMMAND");

				for(int i=0; i<ret_vars.size(); i++) {
					$$->add_code("\n\tPUSH "+ret_vars[i]);
				}

				for(int i=0; i<local_vars.size(); i++) {
					$$->add_code("\n\tPUSH "+local_vars[i]);
				}
				string cmd =
				"\n\tPUSH AX\
				\n\tPUSH BX\
				\n\tPUSH CX\
				\n\tPUSH DX\
				\n\tPUSH ADDRESS";

				$$->add_code(cmd);

				for(int i=0; i<$$->get_param_size(); i++){
					$$->add_code("\n\tPUSH "+$$->get_param(i)->get_assembly_symbol());
				}


				$$->add_code("\n\tCALL " + temp.getname());

				if($$->gettype()!="void") {
					$$->add_code("\n\tPOP " + temp_var);
				}

				cmd = "\n\tPOP ADDRESS\
				\n\tPOP DX\
				\n\tPOP CX\
				\n\tPOP BX\
				\n\tPOP AX" ;
				$$->add_code(cmd);

				for(int i=local_vars.size()-1; i>=0; i--) {
					$$->add_code("\n\tPOP "+local_vars[i]);
				}

				for(int i=ret_vars.size()-1; i>=0; i--) {
					$$->add_code("\n\tPOP "+ret_vars[i]);
				}

				ret_vars.push_back(temp_var);
				$$->set_assebly_symbol(temp_var);

				$$->clear_params();
			}
			| LPAREN expression RPAREN {

				$2->setname("("+$2->getname()+")");
				fprintf(logout,"Line %d: factor : LPAREN expression RPAREN\n\n", line_count);
				fprintf(logout,"%s\n\n", $2->getname().c_str());

				string check_void = $2->gettype();
				if(check_void=="ID") check_void = $2->get_var_ret_type();
				if(void_error(check_void)) $2->settype("float");

				$$ = $2;
			}
			| CONST_INT {
				$$ = new SymbolInfo($1->getname(), "int");
				fprintf(logout,"Line %d: factor : CONST_INT\n\n", line_count);
				fprintf(logout,"%s\n\n", $1->getname().c_str());

				$$->set_assebly_symbol($1->getname());
			}
			| CONST_FLOAT {
				$$ = new SymbolInfo($1->getname(), "float");
				fprintf(logout,"Line %d: factor : CONST_FLOAT\n\n", line_count);
				fprintf(logout,"%s\n\n", $1->getname().c_str());

				$$->set_assebly_symbol($1->getname());
			}
			| variable INCOP {

				$1->setname($1->getname()+"++");
				fprintf(logout,"Line %d: factor : variable INCOP\n\n", line_count);
				fprintf(logout,"%s\n\n", $1->getname().c_str());

				$$ = $1;

				//Temporary Variable Creation and add to intial
				string temp_var = newTemp();

				string code_1 = $1->get_code();
				$$->set_code("\n\t;Line "+to_string(line_count)+": factor : variable INCOP");
				$$->add_code(code_1);
				if($1->get_array_size()>-1) {
					$$->add_code("\n\tMOV AX, " + $1->get_assembly_symbol() + "[BX]");
					$$->add_code("\n\tMOV " + temp_var + ", AX");
					$$->add_code("\n\tINC "+ $1->get_assembly_symbol() + "[BX]\n");

				}
				else {
					$$->add_code("\n\tMOV AX, " + $1->get_assembly_symbol());
					$$->add_code("\n\tMOV " + temp_var + ", AX");
					$$->add_code("\n\tINC "+ $1->get_assembly_symbol() + "\n");
				}

				$$->set_assebly_symbol(temp_var);
			}
			| variable DECOP {

				$1->setname($1->getname()+"--");
				fprintf(logout,"Line %d: factor : variable DECOP\n\n", line_count);
				fprintf(logout,"%s\n\n", $1->getname().c_str());

				$$ = $1;

				//Temporary Variable Creation and add to intial
				string temp_var = newTemp();
				string code_1 = $1->get_code();
				$$->set_code("\n\t;Line "+to_string(line_count)+": factor : variable DECOP");
				$$->add_code(code_1);

				if($1->get_array_size()>-1) {
					$$->add_code("\n\n\tMOV AX, " + $1->get_assembly_symbol() + "[BX]");
					$$->add_code("\n\tMOV " + temp_var + ", AX");
					$$->add_code("\n\tDEC "+ $1->get_assembly_symbol() + "[BX]\n");
				}
				else {
					$$->add_code("\n\n\tMOV AX, " + $1->get_assembly_symbol());
					$$->add_code("\n\tMOV " + temp_var + ", AX");
					$$->add_code("\n\tDEC "+ $1->get_assembly_symbol() + "\n");
				}

				$$->set_assebly_symbol(temp_var);
			}
			;

			argument_list : arguments {
				fprintf(logout,"Line %d: argument_list : arguments\n\n", line_count);
				fprintf(logout,"%s\n\n", $1->getname().c_str());

				$$ = $1;
			}
			| {
				fprintf(logout,"Line %d: argument_list : empty string\n\n", line_count);
				$$ = new SymbolInfo("", "argument_list");;
			}
			;

			arguments : arguments COMMA logic_expression {

				$1->setname($1->getname()+","+ $3->getname());
				fprintf(logout,"Line %d: arguments : arguments COMMA logic_expression\n\n", line_count);
				fprintf(logout,"%s\n\n", $1->getname().c_str());

				$$ = $1;
				$$->add_code($3->get_code());
				$$->add_param($3);
			}
			| logic_expression {

				fprintf(logout,"Line %d: arguments : logic_expression\n\n", line_count);
				fprintf(logout,"%s\n\n", $1->getname().c_str());


				$$ = $1;
				$$->add_param($1);
			}
			;

			%%
			int main(int argc,char *argv[]) {

				if((yyin=fopen(argv[1],"r"))==NULL)
				{
					printf("Cannot Open Input File.\n");
					exit(1);
				}

				logout= fopen("1705051_log.txt","w");
				fclose(logout);

				error= fopen("1705051_error.txt","w");
				fclose(error);

				assembly_code= fopen("code.asm","w");
				fclose(error);

				logout= fopen("1705051_log.txt","a");
				error= fopen("1705051_error.txt","a");
				assembly_code = fopen("code.asm","a");

				yyparse();

				st.PrintAllScopeTable(logout);

				fprintf(logout,"\ntotal lines read: %d\n\n",line_count-1);
				fprintf(logout,"total errors encountered: %d",error_count);
				fprintf(error,"total error encountered: %d",error_count);

				fclose(logout);
				fclose(error);
				fclose(yyin);
				optimize();
				return 0;
			}
			/*
			Script

			#!/bin/bash

			yacc -d -v -y 1705051.y
			echo 'Generated the parser C file as well the header file'
			g++ -w -c -o y.o y.tab.c
			echo 'Generated the parser object file'
			flex 1705051.l
			echo 'Generated the scanner C file'
			g++ -w -c -o l.o lex.yy.c
			# if the above command doesn't work try g++ -fpermissive -w -c -o l.o lex.yy.c
			echo 'Generated the scanner object file'
			g++ y.o l.o -lfl
			echo 'All ready, running'
			./a.out input.c

			*/
