;            rax ; rdi  ; rsi  ; rdx    ; r10 ; r8 ; r9  ; returns

%define READ   0 ;  fd  ; buff ; count  
%define WRITE  1 ;  fd  ; buff ; count  
%define OPEN   2 ; name ; mode                           ; fd
%define CLOSE  3 ;  fd
%define LSEEK  8 ;  fd  ; offs ; orig                    ; offset from the beggining of file
%define BRK   12 ; size                                  ; program brk
%define EXIT  60 ; ret  
%define FTRNC 77 ;  fd  ; size

%define STDIN  0
%define STDOUT 1

%define RDONLY 0
%define WRONLY 1
%define RDWR   2

%define SKSET  0
%define SKCUR  1
%define SKEND  2

%define TRUE   1
%define FALSE  0

section 	.data

nline 	db  0xA
sepr 	db  "==", 0xa

name	db	"file.txt",0x0
tline   db  0xC, 0x0, 0x0, 0x0, "it werks :3", 0xa

;text choose option [A]dd empty line 
;                   [W]rite 
;                   [R]emove last line
;                   [S]save and quit
tcho 	db 	0xE, 0x0, 0x0, 0x0, "Choose mode: ", 0xa
;text enter line number
teln 	db  0x14, 0x0, 0x0, 0x0, "Enter line Number: ", 0xa
;text enter new text
tent 	db  0x11, 0x0, 0x0, 0x0, "Enter new line: ", 0xa

fp  	dq  0x0 
;heap bottom/top
hbtp	dq  0x0
htpp	dq  0x0
;first heap ptr
hfpp	dq  0x0


section 	.text
global  	_start

_start:
	jmp main

; =================================
; PROCEDURES
; return ; name             ; rdi  ;  rsi  ; rdx
; ------ ; ---------------- ; ---- ; ----- ;
;        ; print_num        ; num  ;       ;
;        ; heap_init        ;      ;       ;
; ptr    ; allocate         ; size ;       ;
;        ; free             ; ptr  ;       ;
;        ; memcpy           ; src  ; dest  ; size
; ptr    ; getline          ; fd   ;       ;
; ptr    ; dla_create       ; size
;        ; dla_destroy      ; ptr 
; ptr    ; dla_get_elem     ; ptr  ; index ;
; int    ; dla_get_elem_val ; ptr  ; index ;
; ptr    ; dla_add_elem     ; ptr  ; elem  ; 
; ptr    ; dla_rem_elem     ; ptr  ; index ;
; int    ; STOI             ; ptr  ;       ;

; =================================

; takes number to print in rdi
print_num:
	push 	rbx

	xor 	rbx, rbx
	mov 	rax, rdi
	mov 	rcx, 0xA
pn_div_loop:
	mov 	rdx, 0x0
	
	div 	rcx ; rax - result ; rdx remainder 

	inc  	rbx
	add 	dl, 0x30 ;dl cause its 1B
	; manual push
	dec 	rsp
	mov 	[rsp], dl

	cmp 	rax, 0x0 
	jne  	pn_div_loop
	
; printing time
	mov 	rax, WRITE
	mov 	rdi, STDOUT
	mov 	rsi, rsp
	mov 	rdx, rbx
	syscall
	
	mov 	rax, WRITE
	mov 	rdi, STDOUT
	mov 	rsi, nline
	mov 	rdx, 0x1
	syscall
	
; cleaning up stack
	add 	rsp, rbx

	pop 	rbx

	ret

; =================================

heap_init:
; get current data limit
	mov 	rax, BRK
	mov 	rdi, 0x0
	syscall

	mov 	[hbtp], rax

; reserve 65KB
	add 	rax, 0xFFFF
	mov 	rdi, rax
	mov 	rax, BRK
	syscall
	
	mov 	[htpp], rax
	
; create first free block

; rax now has pointer to the first address of heap
	mov 	QWORD rax, [hbtp]

; set nblock to 0x0
	xor 	QWORD [rax], 0x0

; set isFree to true
	add 	rax, 0x8
	mov 	DWORD [rax], TRUE
	
; set size to 0xFFFF - 0xF
	add 	rax, 0x4
	mov 	DWORD [rax], 0xFFF0

; sets hfpp to point to first data
	add 	rax, 0x4
	mov 	[hfpp], rax

	ret

; =================================

; returns ptr to memory in rax
; takes   size of memory in rdi
allocate:
	push 	rbx
	mov 	rax, [hfpp]

all_loop:		; loops through blocks
	; check if free
	sub 	rax, 0x8
	cmp 	DWORD [rax], TRUE
	je  	all_check_size

	jmp 	all_next_mem

all_check_size:
	add 	rax, 0x4
	cmp 	[rax], edi
	jae  	all_found
	
	sub 	rax, 0x4

	jmp 	all_next_mem

all_next_mem:
	sub 	rax, 0x8
	
	cmp 	QWORD [rax], 0x0
	je  	all_not_found

	mov 	rax, [rax]
	jmp 	all_loop

all_found:
	; splits if neccessary
	mov 	edx, [rax] ; edx = size
	sub 	edx, edi   ; edx -= memory to allocate
	cmp 	edx, 0x20  ; if required memory at least 32 bytes bigger, split
	jl 		all_ret

	sub 	rax, 0xC
	mov 	rdx, rax   ; rdx points to found memory
	add 	rax, rdi   ; move by required memory
	add 	rax, 0x10

	; set pointer to whatever last block is pointing
	mov 	rcx, [rdx]
	mov 	[rax], rcx 	

	; set pointer of first block to the second block
	add 	rax, 0x10
	mov 	[rdx], rax
	sub 	rax, 0x10
	
	; set isFree to true
	add 	rax, 0x8
	mov 	DWORD [rax], TRUE
	
	; set size to total size - rsi - 0x10
	add 	rax, 0x4	

	;	gets size of last
	add 	rdx, 0xC
	mov 	rcx, [rdx]
	sub 	rdx, 0xC

	sub 	rcx, rdi
	sub 	rcx, 0x10

	mov 	[rax], ecx

	; set size of first block to be correct
	add 	rdx, 0xC
	mov 	[rdx], edi

; rax and rdx are swapped so we need to swap them
	mov 	rcx, rdx
	mov 	rdx, rax
	mov 	rax, rcx


all_ret:
	; marks block as not free
	sub 	rax, 0x4
	mov 	DWORD [rax], FALSE 
	add 	rax, 0x8

	pop 	rbx
	ret

all_not_found:
	mov 	rax, 0x0
	
	pop 	rbx
	ret

; =================================

; takes   ptr to memory in rdi
free:
	push	rbx

	mov 	rax, rdi
	sub 	rax, 0x8
	mov 	DWORD [rax], TRUE ; set this memory to free
	
	sub 	rax, 0x8
	mov 	rbx, [rax]

; if next_mem != null && next_mem is free merge
	cmp 	rbx, 0x0
	je  	fr_ret
	
	sub 	rbx, 0x8
	cmp 	DWORD [rbx], TRUE
	jne 	fr_ret
	
	sub 	rbx, 0x8
	;both rbx and rax point to literally first addresses of blocks
	;rax to first, rbx to second

	; next mem of first is whatever second points to
	mov 	rdi, [rbx]
	mov 	[rax], rbx 

	; modify size
	add 	rax, 0xC
	add 	rbx, 0xC
	; rdi holds size of next
	mov 	rdi, [rbx]
	add 	[rax], rdi
	add 	DWORD [rax], 0x10

fr_ret:
	pop 	rbx
	ret

; =================================

; takes 1st mem in rdi, 2nd mem in rsi, size in rdx
; assumes that the size of 2nd mem is enough
; copies from rdi to rsi
memcpy:
	push 	rbx

	xor 	rcx, rcx
mc_loop:
	; rsi[rcx] = rdi[rcx]
	mov 	bl, [rcx + rdi]
	mov 	[rcx + rsi], bl
	
	inc 	rcx

	cmp 	rcx, rdx
	jl  	mc_loop
	
	pop 	rbx
	ret

; =================================
; returns ptr to allocated memory or nullptr if no memory was allocated
; takes fd in rdi
getline:
	push	rbx
	push 	r12
	push 	r13

	mov 	r12, rdi ; fp in r12

	; rbx points to first char
	dec 	rsp
	mov 	rbx, rsp
	
	; r13 stores amount of chars
	mov 	r13, 0x1

	; if \n break
	; else push one char
gl_loop:
	; set up to read chars one by one
	mov 	rax, READ
	mov 	rdi, r12
	mov 	rsi, rsp
	mov 	rdx, 0x1
	syscall

	cmp 	BYTE [rsp], 0xA
	je  	gl_end_loop
	cmp 	BYTE [rsp], 0x0
	je  	gl_not_found
	

	dec 	rsp
	inc 	r13
	

	jmp 	gl_loop

gl_end_loop:
	cmp 	r13, 0x0
	je   	gl_not_found

	; allocate necessary space
	mov 	rdi, r13
	add 	rdi, 0x4 ; for size
	call	allocate

	; copy memory from stack to heap, in reverse because fuck
	; adding to stack resulted in the fact that memory is backwards
	; stack is in rsp, rax is allocated address, r13 is the size

	xor 	rcx, rcx
gl_mc_loop:
	; rax[rcx] = rbx[rcx] (almost)
	mov 	dil, [rbx]
	mov 	[rcx + rax + 0x4], dil
	dec 	rbx
	
	inc 	rcx

	cmp 	rcx, r13
	jl  	gl_mc_loop
	

	; clear stack ptr
	add 	rsp, rcx
	pop 	r13
	pop 	r12
	pop 	rbx

	mov 	[rax], ecx ; moves size
	ret

gl_not_found:
	inc 	rsp
	pop 	r13
	pop 	r12
	pop 	rbx
	
	xor 	rax, 0x0
	ret

; =================================
; returns pointer to dla
; takes size in elements in rdi
; structure of dla is 
;	ptr-0x4   ptr
;	size      data
dla_create:
	; size can be found from size of the block, then divide it by 8
	shl 	rdi, 0x3
	call 	allocate
	ret 

; =================================
; returns &(rdi[index])
; takes pointer to dla in rdi, takes index in rsi
dla_get_elem:
	lea 	rax, [rdi + rsi * 8]
	ret

dla_get_elem_val:
	mov 	rax, [rdi + rsi * 8]
	ret

; =================================

; takes pointer to dla in rdi
dla_destroy:
	push 	r12
	push 	rbx
	push 	rdi

	mov 	r12, rdi
	mov 	ebx, [rdi - 0x4]
	sub 	rbx, 0x8
; free every line
dla_d_loop:
	mov 	rdi, [r12 + rbx]
	call 	free

	sub 	rbx, 0x8
	cmp 	rbx, 0x0
	jl  	dla_d_loop

	pop 	rdi
	call	free

	pop 	rbx
	pop 	r12
	ret


; =================================
; returns ptr to new dla
; takes dla ptr in rdi, takes elem value in rsi
dla_add_elem:
	push 	rbx
	push 	rsi
	push 	rdi

	mov 	ebx, [rdi - 0x4] ; takes size
	add 	rbx, 0x8 ; add size for new elem
	mov 	rdi, rbx
	call 	allocate

	pop 	rdi
	push 	rdi
	mov 	rsi, rax
	mov 	rdx, rbx
	call 	memcpy

	pop 	rdi
	pop 	rsi
	sub 	rbx, 0x8
	mov 	[rax + rbx], rsi
	push 	rax


	; on rdi
	call 	free

	pop 	rax
	pop 	rbx
	ret 

; =================================
; returns ptr to new dla
; takes dla ptr in rdi
dla_rem_elem:
	push 	rbx
	push 	rsi
	push 	rdi

	mov 	ebx, [rdi - 0x4] ; takes size
	sub 	rbx, 0x8 ; change size for less elem
	mov 	rdi, rbx
	call 	allocate

	pop 	rdi
	mov 	rsi, rax
	mov 	rdx, rbx
	call 	memcpy

	pop 	rsi
	push 	rax

	; on rdi
	call 	free

	pop 	rax
	pop 	rbx
	ret 


; =================================
; returns number in rax
; takes char* in rdi and length in rsi
stoi:
	push 	rbx
	xor 	rbx, rbx
	xor 	rax, rax

stoi_loop:
	; rax = rax * 0xA
	mov 	edx, 0xA
	imul 	rax, rdx 
	
	xor 	rcx, rcx
	add 	BYTE cl, [rdi + rbx]
	add 	rax, rcx
	sub 	rax, 0x30 ; ascii offset
	inc 	rbx
	
	cmp 	rbx, rsi
	jl   	stoi_loop

	pop 	rbx
	ret


; =================================

main:
	call 	heap_init

	mov 	rax, OPEN
	mov 	rdi, name
	mov 	rsi, RDWR
	syscall
	mov 	[fp], rax
	
	mov 	rdi, 0x0
	call 	dla_create
	mov 	r12, rax
;

readf_loop:
	mov 	rdi, [fp]
	call 	getline
	cmp 	rax, 0x0
	je  	readf_end_loop

	mov 	rdi, r12
	mov 	rsi, rax
	call 	dla_add_elem
	mov 	r12, rax
	
	jmp 	readf_loop

readf_end_loop:


editor_loop:
	mov 	rax, WRITE
	mov 	rdi, STDOUT
	mov 	rsi, sepr 
	mov 	rdx, 0x3
	syscall
	
	xor 	rbx, rbx ; used as counter
	mov 	r13d, [r12 - 0x4]
	shr 	r13, 0x3 ; divide by 8 
print_loop:
	cmp 	rbx, r13
	jge  	print_loop_end

	mov 	rdi, r12
	mov 	rsi, rbx 	
	call	dla_get_elem_val
	mov 	r14, rax

	mov 	rax, WRITE
	mov 	rdi, STDOUT
	lea 	rsi, [r14 + 0x4]
	mov 	edx, [r14]
	syscall

	inc 	rbx

	jmp 	print_loop

print_loop_end:
	mov 	rax, WRITE
	mov 	rdi, STDOUT
	mov 	rsi, sepr 
	mov 	rdx, 0x3
	syscall

; chooose option
	mov 	rax, WRITE
	mov 	rdi, STDOUT
	lea 	rsi, [tcho + 0x4]
	mov 	edx, [tcho]
	syscall

	mov 	rdi, STDIN
	call 	getline

	cmp 	BYTE [rax + 0x4], 0x41 ; A
	je  	add
	cmp 	BYTE [rax + 0x4], 0x57 ; W
	je  	write
	cmp 	BYTE [rax + 0x4], 0x52 ; R
	je  	remove
	cmp 	BYTE [rax + 0x4], 0x53 ; S
	je  	save


	jmp 	editor_loop

add:
	mov 	rax, WRITE
	mov 	rdi, STDOUT
	lea 	rsi, [tent + 0x4]
	mov 	edx, [tent]
	syscall

	mov 	rdi, STDIN
	call 	getline
	mov 	rdi, r12
	mov 	rsi, rax
	call 	dla_add_elem
	mov 	r12, rax

	jmp 	editor_loop

write:
; get input
	mov 	rax, WRITE
	mov 	rdi, STDOUT
	lea 	rsi, [teln + 0x4]
	mov 	edx, [teln]
	syscall
	
	mov 	rdi, STDIN
	call 	getline
	mov 	rbx, rax

	lea 	rdi, [rbx + 0x4]
	mov 	esi, [rbx]
	dec 	esi
	call 	stoi
	mov 	r13, rax

	mov 	rdi, rbx
	call 	free

	mov 	rax, WRITE
	mov 	rdi, STDOUT
	lea 	rsi, [tent + 0x4]
	mov 	edx, [tent]
	syscall

	mov 	rdi, STDIN
	call 	getline
	mov 	r14, rax

	mov 	rdi, r12
	mov 	rsi, r13
	call 	dla_get_elem
	mov 	rbx, rax

	mov 	rdi, [rax]
	call 	free

	mov 	[rbx], r14

	jmp 	editor_loop

remove:
	mov 	rdi, r12
	call 	dla_rem_elem
	mov 	r12, rax

	jmp 	editor_loop

save:
	mov 	rax, LSEEK
	mov 	rdi, [fp]
	mov 	rsi, 0x0
	mov 	rdx, SKSET
	syscall
	
	mov 	rax, FTRNC
	mov 	rdi, [fp]
	mov 	rsi, 0x0
	syscall


	xor 	rbx, rbx ; used as counter
	mov 	r13d, [r12 - 0x4]
	shr 	r13, 0x3 ; divide by 8 
save_loop:
	cmp 	rbx, r13
	jge  	save_loop_end

	mov 	rdi, r12
	mov 	rsi, rbx 	
	call	dla_get_elem_val
	mov 	r14, rax

	mov 	rax, WRITE
	mov 	rdi, [fp] 
	lea 	rsi, [r14 + 0x4]
	mov 	edx, [r14]
	syscall

	inc 	rbx

	jmp 	save_loop	

save_loop_end:
;
	mov 	rdi, r12
	call 	dla_destroy
	
	mov 	rax, CLOSE
	mov 	rdi, [fp]
	syscall

; exit program
	mov 	rdi, 0x0
	mov 	rax, EXIT
	syscall
	
