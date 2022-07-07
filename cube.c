#include <stdio.h>

int main(void){
    int x = 20; //学号后2位
    int result; //立方运算结果
    int xa, xb; //存储当前乘法运算的被乘数xa, 乘数xb
    int i;
    xa = x;
    // xa * xb
    for(i = 0; i < 2; i++){
        result = 0;
        for(xb = x; xb > 0; xb = xb >> 1){
            if((xb & 1) == 1){
                //乘数当前位为1, 加被乘数
                result += xa;
            }
            xa = xa << 1;
        }
        xa = result;
    }
    printf("%d\n", result);
    return 0;
}