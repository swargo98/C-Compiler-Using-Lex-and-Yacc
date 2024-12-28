int one_to_n(int a){
    if(a==1) return 1;
    return a + one_to_n(a-1);
}

int main(){
    int a, b, c;
    b=5;
    a=one_to_n(b);
    printf(a);
    return 0;
}
