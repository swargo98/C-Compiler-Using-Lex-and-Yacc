int fibonacci(int a){
    if(a==1 || a==2) return 1;
    return fibonacci(a-1) + fibonacci(a-2);
}

int main(){
    int a, b, c;
    b=5;
    a=fibonacci(b);
    printf(a);
    return 0;
}
