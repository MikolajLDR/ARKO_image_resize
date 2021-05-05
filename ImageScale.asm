.data

getFileIn:	.asciiz "Image file name (name.bmp): "
getFileOut:	.asciiz "New image file name (name.bmp): "
getHeight:	.asciiz "New height (in pixels): "
getWidth: 	.asciiz "New width (in pixels): "
savedTo: 	.asciiz "\nNew image saved in "
fileOpenE: 	.asciiz "Fail when loading file\n"
fileNameE: 	.asciiz "File not found\n"
fileSizeE:	.asciiz "New size is too big\n"

imageHeader: 	.space 54
imageInfo:	.space 12
pad: 		.byte 0

originFile:	.space 64
newFile:	.space 64


.text

# s0 - original image descriptor
# s1 - original image size
# s2 - original image address of allocated memory

# s3 - new image size
# s4 - new image address of allocated memory
# s5 - new image descriptor

# s6 - new image width
# s7 - new image height

main:
	li 	$v0, 4			# ask for original image name
	la 	$a0, getFileIn
	syscall
	
	li 	$v0, 8			# read original image name
	la 	$a0, originFile
	li 	$a1, 64
	syscall
	
	li 	$v0, 4			# ask for new image name
	la 	$a0, getFileOut
	syscall
	
	li 	$v0, 8			# read new image name
	la 	$a0, newFile
	li 	$a1, 64
	syscall
	
	li 	$t0, '\n'		# to delete new line from image names
	li 	$t1, 64			# to iterate over image names
	li 	$t2, 64			# to iterate over image names
	
	
deleteNewLine1:
	beqz 	$t1, deleteNewLine2
	subiu 	$t1, $t1, 1
	lb 	$t3, originFile($t1)
	bne 	$t3, $t0, deleteNewLine1
	sb 	$zero, originFile($t1)	# delete new line ('\n') from original image name
	
	
deleteNewLine2:
	beqz 	$t2, readFile
	subiu 	$t2, $t2, 1
	lb 	$t3, newFile($t2)
	bne 	$t3, $t0, deleteNewLine2
	sb 	$zero, newFile($t2)	# delete new line ('\n') from new image nameand start reading file
	
	
readFile:
	li 	$v0, 13			# open input file
	la 	$a0, originFile		# address of null-terminated string containing filename
	move 	$a1, $zero		# flags
	move 	$a2, $zero		# mode
	syscall
	move 	$s0, $v0		# store original image file descriptor
	
	bltz 	$s0, fileNameError	# error if descriptor is negative (<0)
	
	li 	$v0, 14			# reading the header of image file
	move 	$a0, $s0		# original image file descriptor
	la 	$a1, imageHeader	# store to header
	li 	$a2, 54			# maximum number of characters to read
	syscall
	
	bltz 	$v0, fileOpenError	# error if number of characters read is negative (<0)
	
	la 	$t0, imageHeader+34	# t0 - address of image size
	ulw 	$s1, ($t0)		# store number of bytes of image size
	
	li 	$v0, 9
	move 	$a0, $s1		# allocate memory for array of pixels of original image
	syscall
	
	move 	$s2, $v0		# store address of allocated memory
	
	li 	$v0, 4			# ask for destination width
	la 	$a0, getWidth
	syscall
	
	li 	$v0, 5			# read destination width
	syscall
	
	move 	$s6, $v0		# s6 - store new image height
	
	li 	$v0, 4			# ask for destination height 
	la 	$a0, getHeight
	syscall
	
	li 	$v0, 5			# read destination width
	syscall
	
	move 	$s7, $v0		# s7 - store new image height
	
	mul 	$s3, $s6, $s7		# new image size - new image width * height
	sll	$t1, $s3, 1
	addu	$s3, $s3, $t1		# size of new array of pixels in bytes (without padding)
	
	addu	$t0, $s1, $s3
	bge	$t0, 4000000, fileSizeError
	
	li 	$v0, 9
	move 	$a0, $s3		# allocate memory for new image size
	syscall
	
	move 	$s4, $v0		# s4 - store address of new image allocated memory
	
	li 	$v0, 14			# load array of pixels
	move 	$a0, $s0		# original image file descriptor
	move 	$a1, $s2		# address of input buffer - original image address of allocated memory
	move 	$a2, $s1		# maximum number of characters to read - original image size
	syscall
	
	li 	$v0, 16			# close file
	move 	$a0, $s0		# original image file descriptor
	syscall

	la  	$t1, imageInfo
	usw  	$s2, ($t1)		# store to info address of allocated memory of original image
	la 	$t2, imageHeader
	ulw 	$t3, 18($t2)		# t3 - original width
	usw 	$t3, 4($t1)		# store to info original width
	ulw 	$t3, 22($t2) 		# t3 - original height
	usw 	$t3, 8($t1)		# store to info original height
	
	la 	$a0, imageInfo		# a0 - address of info which keeps information about original image
	jal 	scaleImage

	li 	$v0, 13			# open new image file
	la 	$a0, newFile		# address of string containing filename
	li 	$a1, 1			# flag
	syscall
	
	move 	$s5, $v0		# s5 - new image file descriptor
	
	bltz 	$s5, fileNameError	# error if descriptor is negative (<0)

	# count padding in every row
	sll 	$t0, $s6, 1		# s6 - new image width
	addu 	$t0, $t0, $s6		# t0 - new image width in bytes
	srl 	$t1, $t0, 2
	addiu 	$t1, $t1, 1
	sll 	$t1, $t1, 2
	subu 	$t1, $t1, $t0

	bne 	$t1, 4, updateHeader
	move 	$t1, $zero		# t1 - size of padding


updateHeader:
	mul 	$t2, $t1, $s7		# padding * new image height
	addu 	$t3, $t2, $s3		# whole size (new image size + padding size)
	
	la  	$t4, imageHeader 	# t4 - address of header
	usw  	$s6, 18($t4)		# s6 - width
	usw 	$s7, 22($t4)		# s7 - height
	usw 	$t3, 34($t4)		# t3 - whole image size
	addiu 	$t3, $t3, 54		# t3 - whole file size
	usw 	$t3, 2($t4)		# store t3 to header
	li 	$t3, 54
	usw  	$t3, 8($t4)		# store size of header
	li 	$t3, 40
	usw 	$t3, 14($t4)		# store size of DIB header
	
	li 	$v0, 15			# write header
	move 	$a0, $s5 		# new image file descriptor
	la 	$a1, imageHeader	# address of output buffer
	li 	$a2, 54			# number of characters to write (header size)
	syscall
	
	move 	$t4, $zero		# iterator for loop which writes all new image rows of pixels

savePixels:
	li 	$v0, 15
	move 	$a0, $s5		# new image file descriptor
	move 	$a1, $s4		# address of output buffer - address of new image allocated memory
	move 	$a2, $t0		# number of characters to write - row size without padding
	syscall

	li 	$v0, 15 
	move 	$a0, $s5		# new image file descriptor
	la 	$a1, pad		# address of output buffer -  address of array of zeros
	move 	$a2, $t1		# number of characters to write - size of padding per row
	syscall
	
	addiu 	$t4, $t4, 1		# go to next row of pixels
	addu  	$s4, $s4, $t0		# move descriptor in array of new pixels
	bne 	$t4, $s7, savePixels	# if not all rows were saved go to save_pixels
	
	
end:
	j 	exitMessage
	
	
scaleImage:
	ulw 	$t0, 4($a0)		# t0 - oryginal image width
	ulw 	$t1, 8($a0)		# t1 - oryginal image height

	mul 	$t2, $t0, $t1		
	sll 	$t3, $t2, 1
	addu 	$t2, $t3, $t2		# t2 - bytes in oryginal image
	
	sll	$a3, $t0, 1
	addu	$a3, $a3, $t0		# a3 - bytes in row in oryginal image
	subu 	$t3, $s1, $t2		
	div 	$t3, $t3, $t1		# t3 - padding in row in oryginal image
	addu 	$a3, $a3, $t3		# a3 - bytes in row in oryginal image with padding
	
	move	$a2, $s4		# a2 - address of new image pixels
	
	mul 	$t4, $t1, $s7
	mul	$t5, $t0, $s6
	move	$t2, $zero		# t2 - outer loop iteration counter
scalingRow:
	move	$t7, $zero		# t2 - inner loop iteration counter
	
	div 	$t6, $t2, $s7		# t6 - row from oryginal image to get pixels to ew image
	mul	$t3, $a3, $t6		# t3 - address of first pixel in row
	
scalingPixel:
	# counting offset of pixel in row
	div 	$t8, $t7, $s6		# t8 - addres of pixel in this row
	sll	$t9, $t8, 1
	addu	$t8, $t9, $t8
	
	addu 	$a1, $s2, $t3
	addu 	$a1, $a1, $t8		# a1 - address of pixel to copy

	# copy 3 bytes with pixel's color
	lbu 	$t8, ($a1)
	sb 	$t8, ($a2)
	lbu 	$t8, 1($a1)
	sb 	$t8, 1($a2)
	lbu 	$t8, 2($a1)
	sb 	$t8, 2($a2)
	
	addiu 	$a2, $a2, 3		# moving to next pixel in new image
	
	addu	$t7, $t7, $t0
	blt 	$t7, $t5, scalingPixel	# if row is finished

nextRow:
	addu	$t2, $t2, $t1
	blt 	$t2, $t4, scalingRow	# if iamge is finished
	
finishScale:
	jr 	$ra			# jump register to addres in ra
	

exitMessage:
	li 	$v0, 4
	la 	$a0, savedTo
	syscall
	
	li 	$v0, 4
	la 	$a0, newFile
	syscall

exit:
	li 	$v0, 16
	move 	$a0, $s5
	syscall
	
	li 	$v0, 10
	syscall

fileNameError:
	li 	$v0, 4			# show error message
	la 	$a0, fileNameE
	syscall
	j 	exit


fileOpenError:
	li 	$v0, 4			# show error message
	la 	$a0, fileOpenE
	syscall
	
fileSizeError:
	li 	$v0, 4			# show error message
	la 	$a0, fileSizeE
	syscall
