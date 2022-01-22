segment .data
; Define standard constants.
STDOUT    equ 1  ;standard output
SYS_write equ 1  ; call code for write
EXIT_SUCCESS equ 0
SYS_exit     equ 60
SYS_brk      equ 12
STDIN        equ  0  ; standard input
Sys_read     equ  0  ; call code for read 

LF  equ   10         ;Line feed
NULL equ  0          ;end of string

TRUE  equ 1
FALSE equ 0

Error_parsing:  db  "Error parsing input",0  
newLine:        db  10, NULL
None db  0
 
; Token types
t_integer: db "INTERGER",0
t_plus    : db "PLUS",0
t_eof     : db "EOF",0 
t_minus   : db "MINUS",0  

interP db ">>> "

struc Token
    t_value resq  1
    t_type  resq  1
    align 8
endstruc

Token_Pointer dq 0

struc Interpreter_state
    I_text resq  1
    I_pos resq  1
    I_current_token resq 1
    I_current_char resb  1  
    
    align 8
endstruc

Interpreter_state_pointer dq 0 

 
int8b   dq  0

String_to_parseLen equ 200 

segment .bss
stringTo_Print  resb  10
chr             resb  1
string_to_parse resb   String_to_parseLen+2
multidigit      resb  20   

C_char db 0

segment .text 
;****************************************************************
;Token generation 
; Arguments:
;     0) Heap Pointer(rdi) 
;     1) Type(rsi)
;     2) Value(rdx)
; Examples:
;            Token(INTEGER, 3)
;            Token(PLUS '+') 

global Tokens
Tokens:
 
lea r15, qword [rdi+t_type]
mov [r15], rsi 

mov r9,rdx
mov qword [rdi+t_value], r9 
 
mov rax, rdi

ret

;********************************************************
;Heap allocation by using sys_brk.
;Arguments:
; 1) size(rdi)  

global Heap_Allocation
Heap_Allocation:
 
xor rax, rax
mov rax, SYS_brk
mov rsi, rdi
mov rdi,0
syscall
push rax 
lea rdi,[rax+rsi]
mov rax, SYS_brk
syscall
pop rax
ret
;**********************************************
;Returns the length of the given string
;Arguments
; 1) String adress(rdi)
;Return
;  The size in RAX

global strLen
strLen:
xor eax, eax
xor r10,r10
.forLoop: 
   cmp byte [rdi],al
   je  strLen.endForLoop
   inc r10
   inc rdi
   jmp strLen.forLoop 
 .endForLoop:

mov rax, r10
ret

;****************************************************
; Error Function
; Arguments
;  1) Adress of the error message(rdi)
global error_message
error_message:

push rbx
mov rbx, rdi
call strLen
mov r9, rax  

mov rax, SYS_write
mov rdi, STDOUT
mov rsi, rbx
mov rdx, r9
syscall
 
pop rbx
ret

;********************************************************
; Determines whether the character is a valid decimal digit.
; Receives: dil = character
; Returns: Rax=1 if  dil contains a valid decimal
; digit; otherwise, Rax=0.
global Isdigit
Isdigit:

xor eax, eax
cmp byte [rdi], "0"
jl Isdigit.endOfFunc

cmp byte [rdi], "9"
jg Isdigit.endOfFunc
mov rax,1 
.endOfFunc:
ret

;********************************************************
; Determines whether a character is a valid alpha .
; Receives: dil = character
; Returns: Rax=1 if  dil contains a valid alpha
; digit; otherwise, rax=0.
global IsAlpha
IsAlpha:

xor eax,eax
cmp byte [rdi], 'a'
jle IsAlpha.endOfFunc

cmp byte [rdi], 'z'
jge IsAlpha.endOfFunc

mov rax,1 
.endOfFunc:
ret

;********************************************************
; Analog of std::atoi 
; Converts a byte string to an integer value
; Arguments
;   1) str(rdi)	-	pointer to the null-terminated byte string to be interpreted
; Return
; Integer value corresponding to the contents of str on success.
; If no conversion can be performed, ​0​ is returned.
global ascTointerger
ascTointerger:
xor r8d,r8d
xor eax,eax
push rax
.whileTrue:
cmp r8, rsi
jg ascTointerger.endOfFunc
call Isdigit
cmp rax, 1
jne  ascTointerger.endOfFunc
pop rax
xor r9d, r9d
mov r9b, byte [rdi]
sub r9b, "0"
imul rax, 10
add rax, r9
inc rdi
inc r8
push rax
jmp ascTointerger.whileTrue

.endOfFunc:
pop qword [int8b]
ret

;********************************************************
;  
; Converts a integer to a string
; Arguments
;   1) interger value(rdi)
;   2) string adress (rsi)
;   Return(rax) the adress of the string 

global integerToAsc
integerToAsc:

xor r9d, r9d  ; digitCount
xor r10d,r10d
mov rax, rdi 
mov rcx, 10

test rdi, rdi
jns integerToAsc.divideLoop
    neg rdi
    mov byte [rsi], "-" 
    inc r10
    mov rax, rdi

.divideLoop:
    xor rdx, rdx 
    div  rcx
    push rdx
    inc r9
    cmp rax,0
    jne integerToAsc.divideLoop
.popLoop:
    pop r8 ;charDigit
    add r8, "0"
    mov byte [rsi + r10], r8b
    inc r10
    dec r9
    cmp r9,0
    jne integerToAsc.popLoop
    mov byte [rsi + r10], 0
    mov rax,rsi
ret 

;*****************************************************
;Eat.
; Arguments
;   1) token_type (rdi)

global Eat
Eat:
mov r11,qword [Token_Pointer]

mov rcx, qword [r11+t_type]
mov rsi, qword rcx 
call strcmp
cmp rax, 1
jne Eat.Token_not_Equal

mov r10, qword [Interpreter_state_pointer]

mov rdi,qword [r10+I_text]
lea rsi, qword [r10+I_pos]
lea rdx, qword [r10+I_current_char]

 
call get_next_token
 
jmp Eat.endOfFunc

.Token_not_Equal:
mov rdi, Error_parsing
call error_message 

.endOfFunc:

ret

;***********************************************************
;Expr
global Expr
Expr:

mov rdi, Token_size
call Heap_Allocation
mov [Token_Pointer], rax

push rbx 
push r14
 
mov rbx, [Token_Pointer]
 
mov r10, qword [Interpreter_state_pointer]

mov rdi, qword [r10+I_text]
lea rsi, qword [r10+I_pos]
lea rdx, qword [r10+I_current_char]
 
call get_next_token 

call term
mov r14, rax

.while_loop:

mov rdi, qword [rbx+t_type]
lea rsi, qword [t_plus] 
call strcmp 
cmp rax, 1
jne Expr.Is_not_plus

mov rdi, t_plus
call Eat
call term
add r14, rax 
jmp Expr.End_of_loop

.Is_not_plus:

mov rdi, qword [rbx+t_type]
lea rsi, qword [t_minus] 
call strcmp 
cmp  rax, 1
jne Expr.outOfLoop
mov rdi, t_minus
call Eat
call term
sub r14, rax

.End_of_loop:

jmp Expr.while_loop

.outOfLoop:

mov rax, r14
 
.endOfFunc:
pop r14
pop rbx
ret
;*****************************************************
;Lexical analyzer, This method is responsible for breaking a sentence apart into tokens. One token at a time.
; Arguments
;   1) text pointer (rdi)
;   2) position (rsi)
;   3) current_char(rdx)

global get_next_token
get_next_token:

cmp byte [rdx], NULL
je get_next_token.is_none
 
 call skip_whitespace

 push rdi
 mov rdi,rdx
 call Isdigit
 pop rdi
 cmp rax,1
 jne get_next_token.is_not_digit
 call integer
 
 mov rdi, qword [Token_Pointer]
 mov rsi, t_integer
 mov rdx, qword [int8b] 
 call Tokens
 jmp get_next_token.endOfFunc  
 .is_not_digit:

cmp byte [rdx],"+"
jne get_next_token.Is_not_plus
 call Advance
 mov rdi, qword [Token_Pointer]
 mov rsi, t_plus
 mov rdx,  "+"
 call Tokens
 jmp get_next_token.endOfFunc 
 .Is_not_plus:

 cmp byte [rdx],"-"
 jne get_next_token.Is_not_minus
 call Advance
 mov rdi, qword [Token_Pointer]
 mov rsi, t_minus
 mov rdx, "-"
 call Tokens
 jmp get_next_token.endOfFunc 
.Is_not_minus:

cmp byte [rdx], NULL
je get_next_token.endOfFunc
mov rdi, Error_parsing
call error_message 

.is_none:
 mov rdi, qword [Token_Pointer]
 mov rsi, None
 mov rdx, 0
 call Tokens

 .endOfFunc

ret
;****************************************
;Arguments
; 1) text (rdi)

global Interpreter
Interpreter:

mov r8, rdi
mov rdi, Interpreter_state_size
call Heap_Allocation
mov qword [Interpreter_state_pointer], rax

mov r13, rax 

mov qword [rax+I_text], r8
mov qword [rax+I_pos], 0
mov qword [rax+I_current_token], None
 
mov rdi, [rax+I_text]
movzx r9, byte [rdi]
mov byte [rax+I_current_char], r9b
lea rbp, [rax+I_current_char]
call Expr
ret

;*******************************************
; Analog of strcmp()
; Arguments
;   1) str1(rdi)
;   2) str2(rsi)
; Return equal(1) or not equal (0) on rax 

global strcmp
strcmp:
xor  edx, edx

.LoopIn:
mov dl, byte [rdi]
cmp dl, 0
je strcmp.outOfLoop  

cmp byte [rsi], dl
jne strcmp.NotEqual
inc rsi
inc rdi
jmp strcmp.LoopIn

.outOfLoop:
cmp byte [rsi], dl
jne strcmp.NotEqual 

mov rax,1
jmp strcmp.endOfFunc

.NotEqual:
mov rax,0

.endOfFunc:

ret

;******************************************
;Read characters from the user (one at time)
;Arguments:
;  1) string to store (rdi)

global ReadCharacters
ReadCharacters:

mov r8, 0
push rbx
mov rbx, rdi 

 mov rax, SYS_write
 mov rdi, STDOUT
 mov rsi, interP
 mov rdx, 4
 syscall

.Loop_ReadCharacter:

   
   
    mov rax, Sys_read
    mov rdi, STDIN
    lea rsi, qword [chr]
    mov rdx, 1
    syscall
    
    mov al,byte [chr]
    cmp al, LF
    je ReadCharacters.readDone
    
    inc r8
    cmp r8, String_to_parseLen
    jge  ReadCharacters.readDone

    mov byte [rbx], al
    inc rbx
    jmp ReadCharacters.Loop_ReadCharacter

.readDone:
    mov byte [rbx],0
    pop rbx
ret
;********************************************
;Advance- Advance the 'pos' pointer and set the 'current_char' variable
;Current char adress (rdx)
;position adress (rsi)
;text adress (rdi)

global Advance
Advance:

inc qword [rsi]
push rsi
push rdx
push rdi

call strLen
dec rax

pop rdi
pop rdx
pop rsi

mov r9, qword [rsi]
mov r8b, byte [rdi + r9] 

cmp qword [rsi], rax
jg Advance.Greater

mov byte [rdx], r8b 

jmp Advance.endOfFunc

.Greater:

mov byte [rdx], NULL

.endOfFunc:

ret

;*****************************************
; Skip_whitespace
; Args
;  1) text (rdi)
;  2) current char (rdx)
;  3) position (rsi)

global skip_whitespace
skip_whitespace:
xor r9, r9
.whileTrue:
cmp byte [rdx], 32
jne skip_whitespace.endOfFunc  
inc r9
push r9
call Advance
pop r9
jmp skip_whitespace.whileTrue

.endOfFunc:

ret
;***************************************************
; Integer """Return a (multidigit) integer consumed from the input."""
;  1) text (rdi)
;  2) current char (rdx)
;  3) position (rsi)
global integer
integer:
xor r8, r8
.whileTrue:

push rdi
push rdx
push rsi
push r8

mov  rdi,rdx 
call Isdigit

pop r8
pop rsi
pop rdx
pop rdi

cmp rax, 1
jne integer.convert

mov r9b, byte [rdx]
mov [multidigit+r8],r9b

inc r8 
push r8

cmp r8,19 
jg integer.error
call Advance
pop r8
jmp integer.whileTrue

.error:
pop r8
mov rdi, Error_parsing
call error_message
jmp integer.endOfFunc

.convert:

cmp r8, NULL
je integer.endOfFunc

mov rdi,multidigit
dec r8
mov rsi,r8  
call ascTointerger 

.endOfFunc:

mov r13, rax
ret 
;*****************************************
; """Return an INTEGER token value"""
; return by value on (rax)

global term
term:
mov r8, qword [Token_Pointer] 
mov rax,  qword [r8+t_value]
push rax
lea rdi, [t_integer]
call Eat
pop rax

ret

;*****************************************
; Main
global _start
_start:


mov RAX, -45
test rax, rax
not rax
inc rax
test rax,rax  


mov rdi,string_to_parse
call ReadCharacters

mov rdi, string_to_parse
call Interpreter

mov rdi, rax
mov rsi, stringTo_Print
call integerToAsc

mov rax, SYS_write
mov rdi, STDOUT
mov rsi, stringTo_Print
mov rdx, r10
syscall
  
mov rax, SYS_write
mov rdi, STDOUT
mov rsi, newLine
mov rdx, 1
syscall

mov rax, SYS_exit
mov rdi, EXIT_SUCCESS
syscall
ret


