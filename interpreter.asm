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

Nome db  7

; Token types
interger: db "INTERGER",0
plus    : db "PLUS",0
eof     : db "EOF",0 

text  db "5+5",0

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
    
    align 8
endstruc

Interpreter_state_pointer dq 0 

Left  dq  0
Righ  dq  0
int8b   db  0

String_to_parseLen equ 3

segment .bss
stringTo_Print resb  10
chr             resb 1
string_to_parse resb String_to_parseLen+2

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
 
mov qword [rdi+t_type], rsi 

movzx r9, byte [rdx]
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
 
lea rdi,[rax+rsi]
mov rax, SYS_brk
syscall

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
jle Isdigit.endOfFunc

cmp byte [rdi], "9"
jge Isdigit.endOfFunc
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

call Isdigit
cmp rax, 1
jne  Isdigit.endOfFunc
xor eax,eax
xor r9d, r9d
mov r9b, byte [rdi]
sub r9b, "0"
imul rax, 10
add rax, r9
mov [int8b], rax

.endOfFunc:

ret

;********************************************************
;  
; Converts a interger to a string
; Arguments
;   1) interger value(rdi)
;   2) string adress (rsi)
;   Return(rax) the adress of the string 

global intergerToAsc
intergerToAsc:

xor r9d, r9d  ; digitCount
xor r10d,r10d
mov rax, rdi 
mov rcx, 10
.divideLoop:
    xor rdx, rdx 
    div  rcx
    push rdx
    inc r9
    cmp rax,0
    jne intergerToAsc.divideLoop
.popLoop:
    xor r8d,r8d
    pop r8 ;charDigit
    add r8, "0"
    mov byte [rsi + r10], r8b
    inc r10
    dec r9
    cmp r9,0
    jne intergerToAsc.popLoop
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
lea rsi, qword [r10+I_current_token]
lea rdx, qword [r10+I_pos]

 
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

mov r8, [Token_Pointer]

mov r10, qword [Interpreter_state_pointer]

mov rdi,qword [r10+I_text]
lea rsi, qword [r10+I_current_token]
lea rdx, qword [r10+I_pos]
 

call get_next_token
 
mov r9, qword [r8+t_value]
mov qword [Left], r9

lea rdi, [interger]
call Eat

mov r9, [r8+t_value] ; op
mov r10, r9
mov rdi, plus
call Eat

mov r9, [r8+t_value] 
mov [Righ], r9
mov rdi, interger
call Eat

mov rax, qword [Left]
add rax, qword [Righ]

ret
;*****************************************************
;Lexical analyzer, This method is responsible for breaking a sentence apart into tokens. One token at a time.
; Arguments
;   1) text pointer (rdi)
;   2) position (rdx)
;   3) current_token(rsi)

global get_next_token
get_next_token:

mov rcx, rdi
call strLen
dec rax
mov rdi, rcx
cmp qword [rdx], rax
jle get_next_token.endOFLine
 
mov rdi,   [Token_Pointer]
lea rsi,   [eof]
lea rdx,   [None] 
call Tokens
jmp get_next_token.endOfFunc

.endOFLine:
 
push r15
mov rcx, qword [rdx]
lea r15,[rdi + rcx]  ;current_char 
mov rdi,r15

call Isdigit
cmp rax,1 
jne get_next_token.isNotDigit
 
mov r10, qword [Interpreter_state_pointer]
inc qword [r10+I_pos]

call ascTointerger
mov rdi, [Token_Pointer]
mov rsi, interger
mov rdx, int8b
call Tokens

jmp get_next_token.endOfFunc

.isNotDigit:

call IsAlpha
cmp rax, 1
jne get_next_token.isNotAlpha
mov r10, qword [Interpreter_state_pointer]
inc qword [r10+I_pos]
mov rdi, [Token_Pointer]
mov rsi, interger
mov rdx,  r15
call Tokens
jmp get_next_token.endOfFunc

.isNotAlpha:

cmp byte [rdi], "+"
jne  get_next_token.isNotPlus
 
mov r10, qword [Interpreter_state_pointer]
inc qword [r10+I_pos] 

mov rdi, [Token_Pointer]
mov rsi, plus
mov rdx, r15
call Tokens

jmp get_next_token.endOfFunc
 
.isNotPlus:
mov rdi,Error_parsing
call error_message

.endOfFunc:
pop r15
ret
;****************************************
;Arguments
; 1) text (rdi)

global Interpreter
Interpreter:

mov r8, rdi
mov rdi, 24
call Heap_Allocation
mov qword [Interpreter_state_pointer], rax
 
mov r10, qword [Interpreter_state_pointer]

mov qword [r10+I_text], r8
mov qword [r10+I_pos], 0
mov qword [r10+I_current_token], None
 
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
.Loop_ReadCharacter:
    mov rax, Sys_read
    mov rdi, STDIN
    lea rsi, [chr]
    mov rdx, 1
    syscall

    mov al, byte [chr]
    cmp al, LF
    je ReadCharacters.readDone
    
    inc r8
    cmp r8, String_to_parseLen
    jge  ReadCharacters.readDone

    mov byte [rdi], al
    inc rdi
    jmp ReadCharacters.Loop_ReadCharacter

    .readDone:
ret
;*****************************************
; Main
global _start
_start:

mov rax, Sys_read
mov rdi, STDIN
lea rsi, [string_to_parse]
mov rdx, String_to_parseLen
syscall

mov rdi, string_to_parse
call Interpreter

mov rdi, rax
mov rsi, stringTo_Print
call intergerToAsc

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



