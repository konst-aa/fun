.data
arr: .word 9 1 4 5 7 1 2 3 5 6 
len: .word 10
# arr: .word 9 2 1 # 3 4 9
# len: .word 3

# written to practice for comparch2 in april 2024

.text
j main
mergesort:
# a1 <- start, a2 <- end

subi $sp, $sp, 20

sub $t1, $a2, $a1 # dist between args

sw $ra, 0($sp)

beq $t1, 4, return # base case
beq $t1, 0, return # base case

srl $t1, $t1, 3
sll $t1, $t1, 2
add $t2, $a1, $t1  # midpoint

sw $a1, 4($sp)  # start
sw $t2, 8($sp)  # middle
sw $a2, 12($sp) # end
sw $t1, 16($sp) # distance to middle in bytes!

addi $a2, $t2, 0
jal mergesort   # sort lower

lw $a1, 8($sp)  # make a1 start at mid for upper mergesort
lw $a2, 12($sp)

jal mergesort    # sort upper

# merge 2 lists
lw $t0, 4($sp) # p1 to return to
lw $t1, 4($sp) # p1
lw $t2, 8($sp) # p2
lw $t3, 8($sp) # 12($sp) # upper bound
# add $t3, $t1, #
# lw $t4, 16($sp) # size of temporary array
lw $t8 12($sp) # upper bound
sub $t4, $t8, $t0

# RIP Stack, alloc temp array
sub $sp, $sp, $t4
# add $sp, $sp, 20 # make stack size of temp

# temp array start
addi $t5, $sp, 0
add $t9, $t5, $t4 # upper bounds

merge_loop:
# ensure p1 < p2 < upper
blt $t1, $t2, merge_loop_skip_incr
# addi $t2, $t2, 4 # p2++
# addi $t1, $t1, 4 # p1++
merge_loop_skip_incr:

bge $t5, $t9, merge_loop_end

lw $t6, ($t1)
lw $t7, ($t2)

bge $t2, $t8, merge_loop_if
bge $t1, $t3, merge_loop_else
blt $t6, $t7, merge_loop_if

j merge_loop_else
merge_loop_if:

sw $t6, ($t5) # add *p2 to temp arr
addi $t1, $t1, 4 # p1++

j merge_loop_end_if
merge_loop_else:

sw $t7, ($t5) # otherwise 
addi $t2, $t2, 4 # p2++

merge_loop_end_if:

addi $t5, $t5, 4 # *temp++
j merge_loop

merge_loop_end:

add $t6, $t0, $t4 # upper bounds
# add $t5, $sp, $t4

# j skip
merge_loop_copy_loop:
bge $sp, $t5, merge_loop_copy_loop_end
lw $t7, ($sp)
sw $t7, ($t0)

addi $t0, $t0, 4
addi $sp, $sp, 4
j merge_loop_copy_loop
merge_loop_copy_loop_end:
# skip:

# addi $sp, $t5, 0
# sw $t8, 0($sp)
# add $sp, $sp, $t5 # free temp arr
return:

lw $ra, 0($sp)
addi $sp, $sp, 20 # free space

jr $ra

main:
subi $sp, $sp, 8
la $t1, arr
lw $t2, len

sll $t2, $t2,  2

add $t2, $t2, $t1

addi $v0, $zero, 1

add $a1, $t1, $zero
add $a2, $t2, $zero

sw $t1, 0($sp)
sw $t2, 4($sp)

jal mergesort

lw $t1, 0($sp)
lw $t2, 4($sp)

loop:
beq $t1, $t2, end

lw $a0, 0($t1)
addi $t1, $t1, 4

syscall
j loop
end:
