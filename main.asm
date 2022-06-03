.386	;Using native 386 processor instructions sets
.model flat, stdcall
;.stack 65536
option casemap:none

;includes
include		windows.inc ;allowing using windows API

include		user32.inc	;allowing UI interfaces
includelib	user32.lib

include		kernel32.inc
includelib	kernel32.lib

include		msvcrt.inc	;alloing C native runtime functions
includelib	msvcrt.lib

;Function prototypes 
;used to engaging exit
ExitProcess proto, dwExitcode: dword
;Customzied functions
PUBLIC GetArgc
PUBLIC GetArgv
;constants
.const
 
szError db	'ERROR',0
szInfo db 'Infomation',0
szExceptionTooFewArguments db "Invalid argument count(-1)",0
szExceptionAllcation db "Unexpected allocation failure(-2)",0
szExceptionMatError db "Unhandled math exception: Invalid matrix size(-3)",0
szNormalText db "This is a normal execution",0

szld db "%ld",0
szd db "%d",0
szr_plus db "r+",0
szw_plus db "w+",0
szResult db "Result:\n",0

chBlank	= ' ',0
chDeli = '"',0
chCRLF db '\n',0	;This CRLF is incorrect due to it's two bytes wide
					; thus we use 0dh to determine this charater.
					; Which may cause error.

;datas
.data

;undefined datas
.data?
;prefix hf:
;	handle of file

hfMat1 dword ?
hfMat2 dword ?
hfSave dword ?

.code

;Get input arguments count
;para: null
;retn: dword, arguments count
;--stable--
GetArgc PROC
		local	@dwArgc
		pushad
		mov	@dwArgc, 0
		invoke GetCommandLine
		mov	esi, eax 
		cld ;operating direction: left to right
	GetArgc_loop:
	;Initalizing
		lodsb ;load first string character into al (byte type eax)
		or	al, al ; = cmp al,EOF
		jz	GetArgc_end 
		cmp	al, chBlank ;recognition of blank char
		jz	GetArgc_loop ;skip blanks
		dec	esi 
		inc	@dwArgc
		
	GetArgc_loop1:
	;try operating arguments
		lodsb
		or	al, al
		jz	GetArgc_end
		cmp	al, chBlank
		jz	GetArgc_loop
		cmp	al, chDeli
		jnz	GetArgc_loop1
	
	_praser_quotation_marks:
	;deprecated :
	;@@
	;praser quotation marks, which shall be always paired.
		lodsb
		or	al, al
		jz	GetArgc_end
		cmp	al, chDeli
		jnz	_praser_quotation_marks	;if not quotation marks, continue scanning
		;deprecated:
		;jnz @B
		jmp	GetArgc_loop1 ;if paired
	GetArgc_end:
		popad
		mov	eax, @dwArgc
		ret
 
GetArgc		ENDP

;Get arguments string by its id.
;para:
; _dwArgv:		id of argument
; _lpReturn:	return address of string
; _dwSize:		size of _lpReturn
;local:
; @dwArgv:		self-increase index for determine whether its _dwArgv
; @dwFlag:		When approached target, set to TRUE.
;return: no return.
;--stable--
GetArgv proc,
		_dwArgv:dword,
		_lpReturn:ptr byte,
		_dwSize:dword
		local	@dwArgv, @dwFlag
		
		pushad
		inc	_dwArgv ; make it convenient to determine by @dwArgv
		mov	@dwArgv, 0
		mov	edi, _lpReturn 
 
		invoke	GetCommandLine
		mov	esi, eax
		cld 
 
	GetArgv_loop: 
		lodsb
		or	al, al
		jz	GetArgv_end
		cmp	al, chBlank
		jz	GetArgv_loop
		
		dec	esi
		inc	@dwArgv
		mov	@dwFlag, FALSE; setting defalut value of @dwFlag
		mov	eax, _dwArgv 
		cmp	eax, @dwArgv ; = cmp _dwArgv, @dwArgv
		jnz	@F
		mov	@dwFlag, TRUE ; setting flag to true if it's correct
	@@:
	GetArgv_loop1:
		lodsb
		or	al, al
		jz	GetArgv_end
		cmp	al, chBlank
		jz	GetArgv_loop 
		cmp	al, chDeli
		jz	GetArgv_loop2
		cmp	_dwSize, 1
		jle	@F
		;If approached the maximum chars count and the pair failed, exit.
		;Do not contiune load stosb.
		cmp	@dwFlag, TRUE
		jne	@F
		;If its not target, do not load.
		stosb
		dec	_dwSize
	@@:
		jmp	GetArgv_loop1	
 
	GetArgv_loop2:
		lodsb
		or	al, al
		jz	GetArgv_end
		cmp	al, chDeli
		jz	GetArgv_loop1
		cmp	_dwSize, 1 
		jle	@F 
		cmp	@dwFlag, TRUE
		jne	@F 
		stosb
		dec	_dwSize
	@@:
		jmp	GetArgv_loop2
 
	GetArgv_end:
		xor	al, al 
		stosb	;storge 0 to the final chars
		popad
		ret
 
GetArgv		endp
 
; deprecated
;--stable--
;ZeroMemory PROC,
;	_source: ptr byte,
;	_dwSize: DWORD
;	pushad
;	mov ecx, _dwSize
;	xor eax,eax
;	mov edi, [_source]
;	rep stos BYTE ptr [edi]
;	popad
;	leave
;	ret
;ZeroMemory ENDP

;Allocating memory and set it to all zero. You shall free this memory by GlobalFree.
; This function will try to allocated until its succeed.
;para:
; _dwSize: requested sizeof memory going to be allocated.
;local:
; @addr: the return value of GlobalAlloc
;return:
; eax, the address of requested memory.
;--stable--
AllocateAndZeroMemory PROC,
		_dwSize: DWORD
		local @addr
		pushad

		allocation:
		push _dwSize
		push GPTR
		call GlobalAlloc

		cmp eax,0
		jz allocation

		mov @addr,eax

		push _dwSize
		push @addr
		call RtlZeroMemory

		popad
		mov eax,@addr
		ret
AllocateAndZeroMemory ENDP

;Parser string based input matrix and get its ROW number.
;para:
; _str: string pointer which are going to be parsered.
;local:
; @m: row counter.
;return:
; eax, row count.
;--stable--
GetMatirxRow PROC,
		_str: ptr byte
		local @m:DWORD
		pushad
		mov esi,_str
		mov @m,0

	GetMatirxRow_LOOP:
		lodsb
		or al,al
		jz GetMatirxRow_END
		cmp al,0dh	;chCRLF = 0dh, 0ah
		;inc esi
		jnz GetMatirxRow_LOOP
		inc @m
		jmp GetMatirxRow_LOOP

	GetMatirxRow_END:
		popad
		mov eax,@m
		add eax, 1
		ret
GetMatirxRow ENDP

;Parser string based input matrix and get its COLUMN number.
;para:
; _str: string pointer which are going to be parsered.
;local:
; @m: column counter.
;return:
; eax, column count.
;--stable--
GetMatirxCol PROC,
		_str: ptr byte
		local @m:DWORD
		pushad
		mov esi,_str
		mov @m,0

	GetMatirxCol_LOOP:
		lodsb
		cmp al, 0dh
		jz GetMatirxCol_END
		cmp al,20h
		jnz GetMatirxCol_LOOP
		inc @m
		jmp GetMatirxCol_LOOP

	GetMatirxCol_END:
		popad
		mov eax,@m
		ret
GetMatirxCol ENDP

;Calcualte matrix multipy
;para:
; _szMat1
CalculateMatrix PROC,
	_szMat1: ptr BYTE,
	_szMat2: ptr BYTE,
	_result: ptr DWORD

	local @result:	DWORD
	local @_r1:DWORD
	local @_r2:DWORD
	local @_c1:DWORD
	local @_c2:DWORD
	local @Mat1: ptr DWORD
	local @Mat2: ptr DWORD
	local @MatRes: ptr DWORD
	local @temp: ptr DWORD

	local @i: DWORD
	local @_f: DWORD
	local @k: DWORD
	local @n: DWORD

	local @tmp[16] : byte

	pushad
	mov @_r1, 0
	mov @_r2, 0
	mov @_c1, 0
	mov @_c2, 0

	push _szMat1
	call GetMatirxRow
	mov @_r1,eax

	push _szMat1
	call GetMatirxCol
	mov @_c1,eax

	push _szMat2
	call GetMatirxRow
	mov @_r2,eax

	push _szMat2
	call GetMatirxCol
	mov @_c2,eax

	push eax
	mov eax,@_c2
	cmp eax,@_r1
	jnz _exception_size
	pop eax

	push eax
	mov eax, @_c2
	imul eax, @_r1
	imul eax, 4
	push eax
	call AllocateAndZeroMemory
	mov _result, eax
	pop eax

	;getiing first string data
	mov @i,0
	mov @k,0
	mov @_f,0

_reading_string_loop:
	mov ecx, dword ptr @i
	movsx edx, byte ptr _szMat1[ecx]
	; if ( [edx] < '0'
	cmp edx, 30h	;'0'
	jl short _not_digits
	; || > '9') goto _not_digits	
	cmp edx, 39h	;'9'
	jg short _not_digits
	
	mov edx, dword ptr @k
	mov eax, dword ptr @i
	mov cl, byte ptr _szMat1[eax]
	mov byte ptr @tmp[edx], cl

	mov edx,dword ptr @k
	add edx, 1
	mov dword ptr @k, edx
	jmp _inc_i
_is_digits:
;if char is digits, this will copy strings to tmp
	cmp dword ptr @k,0
	jne short _not_digits
	mov eax, dword ptr @i
	add eax,1
	mov dword ptr @i, eax
	jmp _after_while
_not_digits:
;if char is not digits, convert temp string to integer and storging.
	lea ecx, dword ptr @tmp
	push ecx
	call crt_atoi
	add esp,4
	mov edx, dword ptr @_f
	mov dword ptr _result[edx*4], eax
	mov eax, dword ptr @_f
	add eax,1
	mov dword ptr @_f, eax
	mov dword ptr @k, 0
	
	push 16
	lea eax, @tmp
	push eax
	call RtlZeroMemory
_inc_i:
	mov edx, dword ptr @i
	add edx, 1
	mov dword ptr @i,edx
_after_while:
	mov eax, dword ptr @i
	movsx ecx, byte ptr @tmp[eax -1]
	test ecx,ecx
	jne _reading_string_loop
	;Reading string 1 end.



_normal_exit:
	mov @result,eax	;This will allowing access the result matrix
	popad
	ret
	
_exception_size:
	popad
	mov @result,0;This will create null pointer.
	ret
CalculateMatrix ENDP

main PROC
	local @_argc:DWORD

	local @szMatPath1: 	ptr BYTE
	local @szMatPath2: 	ptr BYTE
	local @szSavePath: 	ptr BYTE 
	local @szMat1: 		ptr BYTE
	local @szMat2: 		ptr BYTE
	local @szSav: 		ptr BYTE
	
	local @lpMatRes:		ptr DWORD

	local @lpFile1:DWORD
	local @lpFile2:DWORD
	local @lpSave:DWORD

	local @tmp:DWORD

	call GetArgc
	mov @_argc,eax
	cmp @_argc,4
	jnz _too_few_arguments
	
	push 1000h
	call AllocateAndZeroMemory
	mov @szMatPath1,eax

	push 1000h
	call AllocateAndZeroMemory
	mov @szMatPath2,eax

	push 1000h
	call AllocateAndZeroMemory
	mov @szSavePath,eax

	push 1000h
	call AllocateAndZeroMemory
	mov @szMat1,eax

	push 1000h
	call AllocateAndZeroMemory
	mov @szMat2,eax

	push 1000h
	call AllocateAndZeroMemory
	mov @szSav,eax
	
	push 100h
	push @szMatPath1
	push 1
	call GetArgv

	push 100h
	push @szMatPath2
	push 2
	call GetArgv

	push 100h
	push @szSavePath
	push 3
	call GetArgv

	;Open File1	
	push 0
	push FILE_ATTRIBUTE_ARCHIVE
	push OPEN_EXISTING
	push 0
	push FILE_SHARE_READ
	push GENERIC_READ
	push @szMatPath1
	call CreateFile

	mov hfMat1,eax

	push FILE_BEGIN
	push 0
	push 0
	push hfMat1
	call SetFilePointer
	;READ
	push NULL
	push 100h
	push @szMat1
	push hfMat1
	call ReadFile

	;Open File2
	push 0
	push FILE_ATTRIBUTE_ARCHIVE
	push OPEN_EXISTING
	push 0
	push FILE_SHARE_READ
	push GENERIC_READ
	push @szMatPath2
	call CreateFile

	mov hfMat2,eax

	push FILE_BEGIN
	push 0
	push 0
	push hfMat2
	call SetFilePointer
	;READ
	push NULL
	push 100h
	push @szMat2
	push hfMat2
	call ReadFile
	
	mov dword ptr @tmp,0 

	;
	;CalculateMatrix PROC,
	;_szMat1: ptr BYTE,
	;_szMat2: ptr BYTE,
	;_result: ptr DWORD
	;
	push @lpMatRes
	push @szMat2
	push @szMat1
	call CalculateMatrix
	cmp eax, 0
	je _exception_size
	int 21h
	jmp _normal_exit

	
_exception_size:
	push MB_ICONERROR
	push offset szError
	push offset szExceptionMatError
	push NULL
	call MessageBox

	mov esp,ebp
	pop ebp
	mov eax,-3
	ret
_too_few_arguments:
	push MB_ICONERROR
	push offset szError
	push offset szExceptionTooFewArguments
	push NULL
	call MessageBox
	
	mov esp,ebp
	pop ebp
	mov eax,-1
	ret
_normal_exit:

	mov esp,ebp
	pop ebp
	mov eax,0
	ret
main ENDP
END main

