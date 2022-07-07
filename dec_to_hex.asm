.text
main:
	lui t0, %hi(num) # load address of num
	addi t0, t0, %lo(num)
	lw a0, 0(t0) # a0 = num
	jal ra, dec_to_hex # call dec_to_hex
	jal x0, exit # exit main

dec_to_hex:
	add s3, x0, x0 # s3 = 0
	add t0, x0, x0 # i = 0
	addi t2, x0, 16 # t2 = 16
Loop:
	rem t1, a0, t2 # t1 = a0 % 16
	slli t3, t0, 2 # j = i * 4
	sll t1, t1, t3 # t1 = t1 << j
	add s3, s3, t1 # s3 = s3 + t1
	div a0, a0, t2 # a0 = a0 / 16
	addi t0, t0, 1 # i = i + 1
	bne a0, x0, Loop # if(a0 != 0), jump to Loop
	jalr x0, 0(ra) # else, return to main

exit:

.data
num:
	.word 200111420