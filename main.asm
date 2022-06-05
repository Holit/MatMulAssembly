.386	;Using native 386 processor instructions sets
		;Using x86 processor architect.
.model flat, stdcall
option casemap:none

;includes
include		windows.inc ;allowing using windows API

include		user32.inc	;allowing UI interfaces
includelib	user32.lib

include		kernel32.inc
includelib	kernel32.lib

include		msvcrt.inc	;alloing C native runtime functions
includelib	msvcrt.lib

;constants
.const
 
;szError		db	'ERROR', 0
;szInfo		db 'Infomation', 0
szExceptionTooFewArguments	db "Invalid argument count(-1)", 09h, 0ah, 0
szExceptionAllcation		db "Unexpected allocation failure(-2)", 09h, 0ah, 0
szExceptionMatError			db "Unhandled math exception: Invalid matrix size(-3)", 09h, 0ah, 0

szd 	db "%d", 0
szs 	db "%s", 0
szCRLF 	db 09h, 0ah, 0	;Real CRLF

chBlank	db ' ', 0
chDeli 	db '"', 0

;datas
.data
;undefined datas
.data?
;prefix hf:
;	handle of file

.code
;Get input arguments count
;para: null
;retn: dword, arguments count
;--stable--
getArgc	PROC
		local	@dwArgc : dword
		pushad
		mov		dword ptr @dwArgc, 0
		invoke	GetCommandLine
		mov		esi, eax 
		cld			;operating direction: left to right
	_skip_blanks:
	;Initalizing
		lodsb		;load first string character into al (byte type eax)
		or		al, al ; = cmp al, EOF
		jz		_end 
		cmp		al, chBlank ;recognition of blank char
		jz		_skip_blanks ;skip blanks
		dec		esi 
		inc		dword ptr @dwArgc
		
	_get_argc_loop1:
	;try operating arguments
		lodsb
		or		al, al
		jz		_end
		cmp		al, chBlank
		jz		_skip_blanks
		cmp		al, chDeli
		jnz		_get_argc_loop1
	
	_praser_quotation_marks:
	;deprecated :
	;@@
	;praser quotation marks, which shall be always paired.
		lodsb
		or		al, al
		jz		_end
		cmp		al, chDeli
		jnz		_praser_quotation_marks	;if not quotation marks, continue scanning
		;deprecated:
		;jnz @B
		jmp		_get_argc_loop1 ;if paired
	_end:
		popad
		mov		eax,dword ptr @dwArgc
		ret
getArgc	ENDP

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
getArgv proc, 
		_dwArgv:		dword, 
		_lpReturn:		ptr byte, 
		_dwSize:		dword
		local	@dwArgv, @dwFlag
		
		pushad
		inc		_dwArgv ; make it convenient to determine by @dwArgv
		mov		dword ptr @dwArgv, 0
		mov		edi, _lpReturn 
 
		invoke	GetCommandLine
		mov		esi, eax
		cld 
 
	_skip_blanks: 
		lodsb
		or		al, al
		jz		_end
		cmp		al, chBlank
		jz		_skip_blanks
		
		dec		esi
		inc		dword ptr @dwArgv
		mov		dword ptr @dwFlag, FALSE; setting defalut value of @dwFlag
		mov		eax, _dwArgv 
		cmp		eax, dword ptr @dwArgv ; = cmp _dwArgv, @dwArgv
		jnz		@F
		mov		dword ptr @dwFlag, TRUE ; setting flag to true if it's correct
	@@:
	_core:
		lodsb
		or		al, al
		jz		_end
		cmp		al, chBlank
		jz		_skip_blanks 
		cmp		al, chDeli
		jz		_praser_quotation_marks
		cmp		_dwSize, 1
		jle		@F
		;If approached the maximum chars count and the pair failed, exit.
		;Do not contiune load stosb.
		cmp		dword ptr @dwFlag, TRUE
		jne		@F
		;If its not target, do not load.
		stosb
		dec		_dwSize
	@@:
		jmp		_core	
 
	_praser_quotation_marks:
		lodsb
		or		al, al
		jz		_end
		cmp		al, chDeli
		jz		_core
		cmp		_dwSize, 1 
		jle		@F 
		cmp		dword ptr @dwFlag, TRUE
		jne		@F 
		stosb
		dec		_dwSize
	@@:
		jmp		_praser_quotation_marks
 
	_end:
		xor		al, al 
		stosb		;storge 0 to the final chars
		popad
		ret
 
getArgv	endp
 
; deprecated
;--stable--
;ZeroMemory PROC, 
;	_source: ptr byte, 
;	_dwSize: dword
;	pushad
;	mov ecx, _dwSize
;	xor eax, eax
;	mov edi, [_source]
;	rep stos byte ptr [edi]
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
gzalloc PROC, 
		_dwSize:	dword
		local	@addr
		pushad

		allocation:
		push	_dwSize
		push	GPTR
		call	GlobalAlloc
		cmp		eax, 0
		jz		allocation	;allocation failure loop

		mov		dword ptr @addr, eax
		popad
		mov		eax,dword ptr @addr
		ret
gzalloc ENDP

;Parser string based input matrix and get its ROW number.
;para:
; _str: string pointer which are going to be parsered.
;local:
; @m: row counter.
;return:
; eax, row count.
;--stable--
getMatrixRow PROC, 
		_str: ptr byte
		local	@m:dword
		pushad
		mov		esi, _str
		mov		dword ptr @m, 0

	_get_matrix_row_LOOP:
		lodsb
		or		al, al
		jz		_get_matrix_row_END
		cmp		al, 0dh				;\r\n;
									;\r = 0dh
									;\n = 0ah
		jnz		_get_matrix_row_LOOP
		inc		dword ptr @m
		jmp		_get_matrix_row_LOOP

	_get_matrix_row_END:
		popad
		mov		eax, dword ptr @m
		add		eax, 1
		ret
getMatrixRow ENDP

;Parser string based input matrix and get its COLUMN number.
;para:
; _str: string pointer which are going to be parsered.
;local:
; @m: column counter.
;return:
; eax, column count.
;--stable--
getMatrixCol PROC, 
		_str:	ptr byte
		local	@m:dword
		pushad
		mov		esi, _str
		mov		dword ptr @m, 0

	_get_matrix_col_LOOP:
		lodsb
		cmp		al, 0dh
		jz		_get_matrix_col_END
		cmp		al, 20h					;' ' 
		jnz		_get_matrix_col_LOOP
		inc		@m
		jmp		_get_matrix_col_LOOP

	_get_matrix_col_END:
		popad
		mov		eax, @m
		add		eax, 1
		ret
getMatrixCol ENDP

;Entrypoint.
main PROC
		;used pseudo-instruction local, which make it easier than
		; ebp operations.
		local	@_argc:dword

		;pointers
		local	@szMatPath1: 	ptr byte
		local	@szMatPath2: 	ptr byte
		local	@szSavePath: 	ptr byte 
		local	@szMat1: 		ptr byte
		local	@szMat2: 		ptr byte
		local	@szSav: 		ptr byte
		local	@Mat1:			ptr dword
		local	@Mat2:			ptr dword
		local	@MatRes:		ptr dword
		local	@p:				ptr dword	;for temporary pointer calculate
		
		local	@_r1:	dword
		local	@_r2:	dword
		local	@_c1:	dword
		local	@_c2:	dword



		local	@i: dword
		local	@j: dword
		local	@k: dword
		local	@n: dword

		local	@tmp[16] :	byte

		local	@length:	dword
		
		;handles
		local	@hFileMat1:	dword
		local	@hFileMat2:	dword
		local	@hFileSave:	dword
	;for confusing deassembly 
	;ignore this, this code wont be executed.
	_anti_da1:
		jz		_rc_1
		jnz		_rc_1
		db		0E8h
		db		75h
		db		00h
	_rc_1:
		call	getArgc
		mov		dword ptr @_argc, eax
		cmp		dword ptr @_argc, 4
		jnz		_exception_invalid_arguments

		;Allocating memory space
		push	260				;setting to 260 because this is the max length of win32 path.
		call	gzalloc
		mov		dword ptr @szMatPath1, eax

		push	260
		call	gzalloc
		mov		dword ptr @szMatPath2, eax

		push	260
		call	gzalloc
		mov		dword ptr @szSavePath, eax

		push	1000h
		call	gzalloc
		mov		dword ptr @szMat1, eax

		push	1000h
		call	gzalloc
		mov		dword ptr @szMat2, eax

		push	1000h
		call	gzalloc
		mov		dword ptr @szSav, eax

		push	100h
		push	dword ptr @szMatPath1
		push	1
		call	getArgv

		push	100h
		push	dword ptr @szMatPath2
		push	2
		call	getArgv

		push	100h
		push	dword ptr @szSavePath
		push	3
		call	getArgv

		;Open File1	
		push	0
		push	FILE_ATTRIBUTE_ARCHIVE
		push	OPEN_EXISTING
		push	0
		push	FILE_SHARE_READ
		push	GENERIC_READ
		push	dword ptr @szMatPath1
		call	CreateFile
	_anti_da_2:
		push	ebx
        xor		ebx, ebx
        test	ebx, ebx
		jnz		_fc_2
		jz		_rc_2
	_fc_2:
		db		0E8h
		db		05h
		db		77h 
	_rc_2:
		mov		dword ptr @hFileMat1, eax

		push	FILE_BEGIN
		push	0
		push	0
		push	dword ptr @hFileMat1
		call	SetFilePointer
		;READ
		push	NULL
		push	100h
		push	dword ptr @szMat1
		push	dword ptr @hFileMat1
		call	ReadFile

		;Open File2
		push	0
		push	FILE_ATTRIBUTE_ARCHIVE
		push	OPEN_EXISTING
		push	0
		push	FILE_SHARE_READ
		push	GENERIC_READ
		push	dword ptr @szMatPath2
		call	CreateFile

		mov		dword ptr @hFileMat2, eax

		push	FILE_BEGIN
		push	0
		push	0
		push	dword ptr @hFileMat2
		call	SetFilePointer
		;READ
		push	NULL
		push	100h
		push	dword ptr @szMat2
		push	dword ptr @hFileMat2
		call	ReadFile

		mov		dword ptr @tmp, 0 

		mov		dword ptr @_r1, 0
		mov		dword ptr @_r2, 0
		mov		dword ptr @_c1, 0
		mov		dword ptr @_c2, 0
	;Getting information of string martix.
		push	dword ptr @szMat1
		call	getMatrixRow
		mov		dword ptr @_r1, eax

		push	dword ptr @szMat1
		call	getMatrixCol
		mov		dword ptr @_c1, eax

		push	dword ptr @szMat2
		call	getMatrixRow
		mov		dword ptr @_r2, eax

		push	dword ptr @szMat2
		call	getMatrixCol
		mov		dword ptr @_c2, eax
		
	;test if matrix is appropriate
		push	eax
		mov		eax, dword ptr @_c2
		cmp		eax, dword ptr @_r1
		jnz		_exception_size
		pop		eax

		push	eax
		mov		eax, dword ptr @_c1
		imul	eax, dword ptr @_r1
		imul	eax, 4
		push	eax
		call	gzalloc
		mov		dword ptr @Mat1, eax
		pop		eax		

		push	eax
		mov		eax, dword ptr @_c2
		imul	eax, dword ptr @_r2
		imul	eax, 4
		push	eax
		call	gzalloc
		mov		dword ptr @Mat2, eax
		pop		eax

		pushad
		;getiing first string data
		mov		dword ptr @i, 0
		mov		dword ptr @k, 0
		mov		dword ptr @j, 0

	_read_string_loop_1:
		mov		ecx, dword ptr @i
		push	ecx
		add		ecx, dword ptr @szMat1
		movsx	edx, byte ptr [ecx]
		pop		ecx
		; if ( [edx] < '0'
		cmp		edx, 30h	;'0'
		jl		short _is_not_digits_1
		; || > '9') goto _is_not_digits_1	
		cmp		edx, 39h	;'9'
		jg		short _is_not_digits_1

		mov		edx, dword ptr @k
		mov		eax, dword ptr @i
		push	eax
		add		eax, dword ptr @szMat1
		mov		cl, byte ptr [eax]
		pop		eax
		push	edx
		push	eax
		lea		eax, dword ptr @tmp
		add		edx, eax
		mov		[edx], ecx
		pop		eax
		pop		edx

		mov		edx, dword ptr @k
		add		edx, 1
		mov		dword ptr @k, edx
		jmp		_inc_i_1
	_is_digits_1:
	;if char is digits, this will copy strings to tmp
		cmp		dword ptr @k, 0
		jne		short _is_not_digits_1
		mov		eax, dword ptr @i
		add		eax, 1
		mov		dword ptr @i, eax
		jmp		_loop_end_1
	_is_not_digits_1:
	;if char is not digits, convert temp string to integer and storging.
		cmp		dword ptr @k, 0
		jz		_clear_tmp_1
		lea		ecx, dword ptr @tmp
		push	ecx
		call	crt_atoi
		add		esp, 4
		mov		edx, dword ptr @j
		push	edx
		imul	edx, 4
		add		edx, dword ptr @Mat1
		mov		[edx], eax
		pop		edx
		mov		dword ptr @p, eax
		mov		eax, dword ptr @j
		add		eax, 1
		mov		dword ptr @j, eax
		mov		dword ptr @k, 0
	_clear_tmp_1:
		push	16
		lea		eax, dword ptr @tmp
		push	eax
		call	RtlZeroMemory
	_inc_i_1:
		mov		edx, dword ptr @i
		add		edx, 1
		mov		dword ptr @i, edx
	_loop_end_1:
		mov		eax, dword ptr @i
		push	eax
		add		eax, dword ptr @szMat1
		sub		eax, 1
		movsx	ecx, byte ptr [eax]
		pop		eax
		test	ecx, ecx
		jne		_read_string_loop_1
		;Reading string 1 end.

	
		push	16
		lea		eax, dword ptr @tmp
		push	eax
		call	RtlZeroMemory
		mov		dword ptr @i, 0
		mov		dword ptr @k, 0
		mov		dword ptr @j, 0

	_read_string_loop_2:
		mov		ecx, dword ptr @i
		push	ecx
		add		ecx, dword ptr @szMat2
		movsx	edx, byte ptr [ecx]
		pop		ecx
		cmp		edx, 30h	;'0'
		jl		short _is_not_digits_2
		cmp		edx, 39h	;'9'
		jg		short _is_not_digits_2

		mov		edx, dword ptr @k
		mov		eax, dword ptr @i
		push	eax			;protect possible eax value.
		add		eax, dword ptr @szMat2
		mov		cl, byte ptr [eax]
		pop		eax
		push	edx
		push	eax
		lea		eax, dword ptr @tmp
		add		edx, eax
		mov		[edx], ecx
		pop		eax
		pop		edx

		mov		edx, dword ptr @k
		add		edx, 1
		mov		dword ptr @k, edx
		jmp		_inc_i_2
	_is_digits_2:
	;if char is digits, this will copy strings to tmp
		cmp		dword ptr @k, 0
		jne		short _is_not_digits_2
		mov		eax, dword ptr @i
		add		eax, 1
		mov		dword ptr @i, eax
		jmp		_loop_end_2
	_is_not_digits_2:
	;if char is not digits, convert temp string to integer and storging.
		cmp		dword ptr @k, 0
		jz		_clear_tmp_2
		lea		ecx, dword ptr @tmp
		push	ecx
		call	crt_atoi
		add		esp, 4
		mov		edx, dword ptr @j
		push	edx
		imul	edx, 4
		add		edx, dword ptr @Mat2
		mov		[edx], eax
		pop		edx
		mov		dword ptr @p, eax
		mov		eax, dword ptr @j
		add		eax, 1
		mov		dword ptr @j, eax
		mov		dword ptr @k, 0
	_clear_tmp_2:
		push	16
		lea		eax,dword ptr @tmp
		push	eax
		call	RtlZeroMemory
	_inc_i_2:
		mov		edx, dword ptr @i
		add		edx, 1
		mov		dword ptr @i, edx
	_loop_end_2:
		mov		eax, dword ptr @i
		push	eax
		add		eax, dword ptr @szMat2
		sub		eax, 1
		movsx	ecx, byte ptr [eax]
		pop		eax
		test	ecx, ecx
		jne		_read_string_loop_2
		;Reading string 2 end.
		;--reding digits stable--
		;simple calcuation:
		;index x, y to index i
		;row x, col y ( start from 0 )
		;x*c + y	
		;target matrix size: @_c2 * @_r1

		push	eax
		mov		eax, dword ptr @_c2
		imul	eax, dword ptr @_r1
		imul	eax, 4	;type dword
		push	eax
		call	gzalloc
		mov		dword ptr @MatRes, eax
		pop		eax
		mov		dword ptr @i, 0
		mov		dword ptr @j, 0
		mov		dword ptr @k, 0
		mov		dword ptr @n, 0
	
	;for (@i = 0; @i < @_c1; @i++)
	;{
	;	for (@j = 0; @j < @_r2; @j++)
	;	{
	;		@n = 0;
	;		for (@k = 0; @k < @_r2; @k++)
	;		{
	;			@n = @n + (@Mat1[@i][@k]) * (@Mat2[@k][@j]);
	;		}
	;		@MatRes[@i][@j] = @n;
	;	}
	;}
	_calc_multipy:
		mov		dword ptr @i, 0
		jmp		_calc_2
	_calc_1:
		mov		ecx, dword ptr @i
		add		ecx, 1
		mov		dword ptr @i, ecx
	_calc_2:
		mov		edx, dword ptr @i
		cmp		edx, dword ptr @_c1
		jge		_end_calc_matrix
		mov		dword ptr @j, 0
		jmp		_calc_4
	_calc_3:
		mov		eax, dword ptr @j
		add		eax, 1
		mov		dword ptr @j, eax
	_calc_4:
		mov		ecx, dword ptr @j
		cmp		ecx, dword ptr @_r2
		jge		_calc_8
		mov		dword ptr @n, 0
		mov		dword ptr @k, 0
		jmp		_calc_cell
	_calc_5:
		mov		edx, dword ptr @k
		add		edx, 1
		mov		dword ptr @k, edx
	_calc_cell:
		mov		eax, dword ptr @k
		cmp		eax, dword ptr @_r2
		jge		short _set_matrix_result_cell_value
		;n = n + (mat1[i][k]) * (mat2[k][j]);
		;[i][k] = i * _r1 + k
		mov		edx, dword ptr @Mat1
		mov		ecx, dword ptr @i
		imul	ecx, dword ptr @_r1
		add		ecx, dword ptr @k
		imul	ecx, 4
		add		ecx, edx
		mov		eax, dword ptr [ecx]
		;[k][j] = k * _r2 + j
		mov		edx, dword ptr @Mat2
		mov		ecx, dword ptr @k
		imul	ecx, dword ptr @_r2
		add		ecx, dword ptr @j
		imul	ecx , 4
		add		ecx, edx
		mov		ecx, dword ptr [ecx]

		imul	eax, ecx
		mov		ecx, dword ptr @n
		add		ecx, eax
		
		mov		dword ptr @n, ecx

		jmp		_calc_5
		
	_set_matrix_result_cell_value:
		;res[i][j] = sum;
		mov		edx, dword ptr @MatRes
		mov		ecx, dword ptr @i
		imul	ecx, dword ptr @_r2
		add		ecx, dword ptr @j
		imul	ecx, 4
		add		ecx, edx
		mov		eax , dword ptr @n
		mov		dword ptr [ecx] , dword ptr eax
		jmp		_calc_3
	_calc_8:
		jmp		_calc_1
	_end_calc_matrix:
		popad 
		
		push	1000h
		call	gzalloc
		mov		dword ptr @szSav, eax

		mov		dword ptr @length, 0

	_save_1:
		mov		dword ptr @i, 0
		jmp		_write_to_str
	_save_2:
		mov		eax, dword ptr @i
		add		eax, 1
		mov		dword ptr @i, eax
	_write_to_str:
		;ssprintf(@szSave + strlen(@szSav), offset "%d", @Mat[@i])
		mov		eax, dword ptr @_c2
		imul	eax, dword ptr @_r1
		cmp		dword ptr @i, eax
		jge		 _save_6
		mov		ecx, dword ptr @i
		push	ecx
		imul	ecx, 4
		add		ecx, dword ptr @MatRes
		mov		edx, dword ptr [ecx]
		pop		ecx
		push	edx
		push	offset szd
		mov		eax, dword ptr @szSav
		push	eax
		call	crt_strlen
		add		esp, 4
		add		eax, dword ptr @szSav
		push	eax
		call	crt_sprintf
		add		esp, 12
		;if( @i % @_c2 != 0) 
		mov		eax, dword ptr @i
		add		eax, 1
		cdq			;Convert Double to Quad, prepare for dividing
					;here we shall mod length (offset) to col number to determine
					; whether should postfix a blank or crlf
		idiv	dword ptr @_c2
		test	edx, edx
		jne		_write_blank
		;else ssprintf(@szSave + strlen(@szSav), offset "\r\n")
		push	offset szCRLF
		mov		ecx, dword ptr @szSav
		push	ecx
		call	crt_strlen
		add		esp, 4
		add		eax, dword ptr @szSav
		push	eax
		call	crt_sprintf
		add		esp, 8
		jmp		_save_5
	_write_blank:
		;ssprintf(@szSave + strlen(@szSav), offset " ")
		push	offset chBlank
		mov		edx, dword ptr @szSav
		push	edx
		call	crt_strlen
		add		esp, 4
		add		eax, dword ptr @szSav
		push	eax
		call	crt_sprintf
		add		esp, 8
	_save_5:
		jmp		_save_2
	_save_6:
		push	GPTR
		mov		eax, dword ptr @szSav
		push	eax
		call	crt_strlen
		add		esp, 4
		push	eax
		mov		ecx, dword ptr @szSav
		push	ecx
		call	GlobalReAlloc
		mov		dword ptr @szSav, eax
		;save to file
		
		push	0
		push	FILE_ATTRIBUTE_NORMAL
		push	CREATE_ALWAYS
		push	0
		push	FILE_SHARE_WRITE
		push	GENERIC_WRITE
		push	dword ptr @szSavePath
		call	CreateFile
		mov		dword ptr @hFileSave, eax

		push	NULL
		lea		eax, dword ptr @n
		push	eax
		push	dword ptr @szSav
		call	crt_strlen
		add		esp, 4
		push	eax
		push	dword ptr @szSav
		push	dword ptr @hFileSave
		call	WriteFile
		cmp		eax, 0
		jnz		_no_error
		call	GetLastError
		int		21h
		
	_no_error:
		push	dword ptr @szSav
		push	offset szs
		call	crt_printf
		add		esp , 8
		;free spaces
		push	dword ptr @szMatPath1
		call	GlobalFree
		push	dword ptr @szMatPath2
		call	GlobalFree
		push	dword ptr @szSavePath
		call	GlobalFree

		push	dword ptr @szMat1
		call	GlobalFree
		push	dword ptr @szMat2
		call	GlobalFree
		push	dword ptr @szSav
		call	GlobalFree

		push	dword ptr @Mat1
		call	GlobalFree
		push	dword ptr @Mat2
		call	GlobalFree
		push	dword ptr @MatRes
		call	GlobalFree
		;close handles
		push	dword ptr @hFileMat1
		call	CloseHandle
		push	dword ptr @hFileMat2
		call	CloseHandle
		push	dword ptr @hFileSave
		call	CloseHandle

		jmp		_normal_exit

	_exception_size:
		
		push	offset szExceptionMatError
		push	offset szs
		call	crt_printf
		add		esp, 8
		;push	MB_ICONERROR
		;push	offset szError
		;push	offset szExceptionMatError
		;push	NULL
		;call	MessageBox

		push	-3
		call	ExitProcess
	_exception_invalid_arguments:
		push	offset szExceptionTooFewArguments
		push	offset szs
		call	crt_printf
		add		esp, 8
		;push	MB_ICONERROR
		;push	offset szError
		;push	offset szExceptionTooFewArguments
		;push	NULL
		;call	MessageBox

		push	-1
		call	ExitProcess
	_normal_exit:
		push	0
		call	ExitProcess
main ENDP
END main

