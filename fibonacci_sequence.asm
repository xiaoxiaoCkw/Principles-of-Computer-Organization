.text
main:
	lui t0, %hi(num) # load address of num
	addi t0, t0, %lo(num)
	lw a0, 0(t0) # a0 = num
	jal ra, fibonacci # call fibonacci
	jal x0, exit # exit main

fibonacci:
	addi t1, x0, 1 # fib(1) = 1
	addi t2, x0, 1 # fib(2) = 1
	addi t3, x0, 3 # n = 3
	add s3, x0, x0 # s3 = 0
Loop:
	add s3, t1, t2 # fib(n) = fib(n-1) + fib(n-2)
	add t1, t2, x0 # fib(n-2) = fib(n-1)
	add t2, s3, x0 # fib(n-1) = fib(n)
	addi t3, t3, 1 # n = n + 1
	ble t3, a0, Loop # if(n <= num), jump to Loop
	jalr x0, 0(ra) # else, back to main

exit:

.data
num:
	.word 20
