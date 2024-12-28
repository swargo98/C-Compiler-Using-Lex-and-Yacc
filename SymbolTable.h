#ifndef SYMBOLTABLE_H
#define USYMBOLTABLE_H

#include<iostream>
#include<string>
#include<vector>
#include <algorithm>

using namespace std;

class SymbolInfo
{
    string name;
    string type;
    string var_ret_type; //variable and return type
    int unit_type; //1=variable, 2=function_declaration, 3=function_definition
    vector<SymbolInfo*> param_list;  // parameter list for function declaration, definition
    int array_size;

    string code;
    string assemblySymbol;
public:
    SymbolInfo(string n="", string t=""): name(n), type(t) {array_size=-1; unit_type=0;}
    string getname()
    {
        return name;
    }
    void setname(string k)
    {
        name=k;
    }
    string gettype()
    {
        return type;
    }
    void settype(string v)
    {
        type=v;
    }

    string get_var_ret_type()
    {
        return var_ret_type;
    }
    void set_var_ret_type(string v)
    {
        var_ret_type=v;
    }

    int get_array_size()
    {
        return array_size;
    }
    void set_array_size(int v)
    {
        array_size=v;
    }

    int get_unit_type()
    {
        return unit_type;
    }
    void set_unit_type(int v)
    {
        unit_type=v;
    }

    int get_param_size(){
        return param_list.size();
    }

    void add_param(SymbolInfo* temp) {
        param_list.push_back(temp);
    }

    SymbolInfo* get_param(int index){
        return param_list[index];
    }

    void clear_params(){
        param_list.clear();
    }

    string get_code()
    {
        return code;
    }

    string get_assembly_symbol()
    {
        return assemblySymbol;
    }

    void set_code(string c)
    {
        code = c;
    }

    void add_code(string add)
    {
        code+=add;
    }

    void set_assebly_symbol(string asmsym)
    {
        assemblySymbol = asmsym;
        //cout<<assemblySymbol<<endl;
    }
};

class llnode
{
public:
    SymbolInfo data;
    llnode* next;
    llnode(SymbolInfo kvp, llnode* n=NULL)
    {
        data = kvp;
        next = n;
    }
    ~llnode()
    {
        //cout<<"Inside Llnode Destructor"<<endl;
//        next = NULL;
//        delete next;
    }
};

class llist
{
    llnode* head;
    llnode* cursor;
    int list_size;
public:
    llist(): head(NULL), cursor(NULL), list_size(0) {}
    int getSize()
    {
        return list_size;
    }
    void Insert(SymbolInfo newkvp)
    {
        if (head == 0)
        {
            head = new llnode(newkvp);
            cursor = head;
        }
        else
        {
            cursor->next = new llnode(newkvp);
            cursor = cursor->next;
        }
        //cout<<list_size<<endl;
        list_size++;
    }
    void Delete()
    {
        llnode* p;
        llnode* q;
        list_size--;
        if(head==NULL)
            return;
        if(cursor==head && head->next==NULL)
        {
            head = NULL;
            cursor = NULL;
            return;
        }
        if (cursor == head)
        {

            p = head;
            head = head->next;
            cursor = head;
        }
        else if (cursor->next != 0)
        {
            p = cursor->next;
            cursor->data = p->data;
            cursor->next = p->next;
        }
        else
        {
            p = cursor;
            q = head;
            while(q->next != cursor)
                q = q->next;
            q->next = NULL;
            cursor = head;
        }

        delete p;
    }
    bool isEmpty()
    {
        return (head==NULL);
    }
    void gotoBeginning()
    {
        if(head==NULL)
            return;
        cursor = head;
    }
    bool gotoNext()
    {
        bool ret;   // Result returned

        if (cursor->next != 0)
        {
            cursor = cursor->next;
            ret = true;
        }
        else
            ret = false;

        return ret;
    }
    void gotoEnd()
    {
        if(cursor==0)
            return;
        while (cursor->next != 0)
        {
            cursor = cursor->next;
        }
    }
    SymbolInfo getCursor()
    {
        if(head==NULL)
        {
            //cout<<"List is empty, returning empty Key Value Pair";
            SymbolInfo newpair;
            return newpair;
        }
        return cursor->data;
    }
    ~llist()
    {
        //cout<<"Inside Llist Destructor"<<endl;
        gotoBeginning();
        llnode* temp;

        if(cursor!=0)
        {
            while (cursor->next != 0)
            {
                //cout<<"Inside While "<<cursor->data.getname()<<endl;
                temp = cursor;
                cursor = cursor->next;
                delete temp;
            }
            if(cursor==head)
            {
                //cout<<"Inside If"<<cursor->data.getname()<<endl;
                temp = cursor;
                delete temp;
            }
        }
    }
};

class ScopeTable
{
    int tableSize;
    llist *table;
    string id;
    ScopeTable* parent;
    int n_child;

public:
    ScopeTable(int table_Size=10, string t_id="1")
    {
        tableSize = table_Size;
        table = new llist[tableSize];
        id=t_id;
        parent = NULL;
        n_child = 0;
    }
    long long hash_1(string str)
    {
        long long hash_value = 0;

        for (unsigned int i = 0; i<str.length(); i++)
        {
            hash_value = hash_value + str[i];

        }
        return hash_value;
    }
    bool Insert(SymbolInfo newItem, FILE *fout=stdout)
    {

        SymbolInfo dummy;
        bool does_exist = Lookup(newItem.getname(), dummy);

        if(does_exist)
        {
            //fprintf(fout, "%s already exists in current ScopeTable\n", newItem.getname().c_str());
            return false;
        }

        long long index = 0;
        index = hash_1(newItem.getname()) % tableSize;
        //cout<<"Inserted in ScopeTable# "<<id<<" at position "<<index<<", ";
        table[index].Insert(newItem);
        return true;
    }
    bool Delete(string searchKey)
    {
        //SymbolInfo temp;
        long long index = 0;
        index = hash_1(searchKey) % tableSize;

        if (table[index].isEmpty())
            return false;

        table[index].gotoBeginning();
        int pos = 0;
        do
        {
            if (table[index].getCursor().getname() == searchKey)
            {
                //cout<<"Found in ScopeTable# "<<id<<" at position "<<index<<", "<<pos<<endl;
                table[index].Delete();
                //cout<<"Deleted Entry "<<index<<", "<<pos<<" from current ScopeTable"<<endl;
                table[index].gotoEnd();
                return true;
            }
            pos++;
        }
        while (table[index].gotoNext());

        return false;
    }
    bool Lookup(string searchKey, SymbolInfo &dataItem)
    {

        long long index = 0;
        index = hash_1(searchKey) % tableSize;


        if (table[index].isEmpty())
            return false;

        table[index].gotoBeginning();
        int pos=0;
        do
        {

            if (table[index].getCursor().getname() == searchKey)
            {
                //cout<<"Found in ScopeTable# "<<id<<" at position "<<index<<", ";
                //cout<<pos<<endl;
                dataItem = table[index].getCursor();
                table[index].gotoEnd();
                return true;
            }
            pos++;
        }
        while (table[index].gotoNext());

        return false;
    }
    void Print(FILE *fout=stdout)
    {
        //cout << "ScopeTable # " <<id<< endl;
        //bool head_printed = false;
        fprintf(fout, "ScopeTable # %s\n", id.c_str());

        for (int i = 0; i<tableSize; i++)
        {
            //cout << i << " --> ";
            if(table[i].isEmpty()) continue;
            /*if(!head_printed)
            {
                fprintf(fout, "ScopeTable # %s\n", id.c_str());
                head_printed = true;
            }*/
            fprintf(fout, "%d --> ", i);
            if (table[i].isEmpty())
                //cout << "";
                fprintf(fout, "");
            else
            {
                table[i].gotoBeginning();
                do
                {
                    //cout <<"< " <<table[i].getCursor().getname() << " : "<<table[i].getCursor().gettype()<<"> ";
                    fprintf(fout, "<%s , %s> ", table[i].getCursor().getname().c_str(), table[i].getCursor().gettype().c_str());
                    //printf("<%s , %s, %d> ", table[i].getCursor().getname().c_str(), table[i].getCursor().gettype().c_str(), table[i].getCursor().get_unit_type());
                }
                while (table[i].gotoNext());
            }
            //cout << endl;
            fprintf(fout, "\n");
        }
    }
    void incChild()
    {
        n_child++;
    }
    int getChild()
    {
        return n_child;
    }
    string getID()
    {
        return id;
    }
    ScopeTable* getParent()
    {
        return parent;
    }
    void setParent(ScopeTable* p)
    {
        parent=p;
    }
    ~ScopeTable()
    {
        //cout<<"Inside ScopeTable "<<id<<" Destructor"<<endl;
        delete[] table;
    }
};





class SymbolTable
{
    ScopeTable* cur;
    ScopeTable* prev;
    int table_size;
public:
    SymbolTable(int t_size)
    {
        table_size = t_size;
        cur = new ScopeTable(table_size);
        prev = NULL;
    }

    void EnterScope(FILE *fout=stdout)
    {
        cur->incChild();
        int id_num = cur->getChild();
        string id = cur->getID()+ "." + char(id_num+'0');
        prev = cur;
        cur = new ScopeTable(table_size, id);
        cur->setParent(prev);
        //cout<<"New ScopeTable with id "<<id<<" created"<<endl;
        //fprintf(fout, "New ScopeTable with id %s created\n", id.c_str());
    }

    void ExitScope(FILE *fout=stdout)
    {
        string id = cur->getID();
        delete cur;
        cur = prev;
        prev = cur->getParent();
        //cout<<"ScopeTable with id "<<id<<" removed"<<endl;
        //fprintf(fout, "New ScopeTable with id %s removed\n", id.c_str());
    }

    bool Insert(string name, string type,  FILE *fout=stdout)
    {
        SymbolInfo item;

        item.setname(name);
        item.settype(type);

        bool ret = cur->Insert(item, fout);
        if(ret) PrintAllScopeTable(fout);
        return ret;
    }

    bool Insert(SymbolInfo* item,  FILE *fout=stdout)
    {
        bool ret = cur->Insert(*item, fout);
        //if(ret) PrintAllScopeTable(fout);
        return ret;
    }

    bool Remove(string name)
    {
        return cur->Delete(name);
    }

    bool Lookup(string searchKey, SymbolInfo &dataItem, bool is_current_only=false)
    {
        ScopeTable* temp = cur;
        while(1)
        {
            if(temp->Lookup(searchKey, dataItem))
                return true;
            temp = temp->getParent();
            if(temp==NULL)
            {
                //delete temp;
                return false;
            }
            if(is_current_only) return false;
        }
    }
    void PrintCurrentScopeTable(FILE *fout=stdout)
    {
        cur->Print(fout);
    }

    void PrintAllScopeTable(FILE *fout=stdout)
    {
        ScopeTable* temp = cur;
        while(1)
        {
            //cout<<"Baire"<<endl;
            temp->Print(fout);
            temp = temp->getParent();
            if(temp==NULL)
            {
                break;
            }
        }
    }

    string getTableID()
    {
        string s = cur->getID();
        replace( s.begin(), s.end(), '.', '_');
        return  s;
    }

    ~SymbolTable()
    {
        //cout<<"Inside SymbolTable Destructor"<<endl;
        ScopeTable* temp;
        while(1)
        {
            if(cur==NULL) break;
            temp = cur;
            if(cur!=NULL) cur = cur->getParent();
            if(temp!=NULL)
            {
                delete temp;
            }
        }
    }

};

#endif //SYMBOLTABLE_H
