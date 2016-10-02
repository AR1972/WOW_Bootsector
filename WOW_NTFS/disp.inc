;------------------------------------------------------------------------------
DISPLAY_CRLF:
	pushfd
	pushad
	mov al,0x0D
	call DISPLAY_AL
	mov al,0x0A
	call DISPLAY_AL
	popad
	popfd
	retn
;------------------------------------------------------------------------------
DISPLAY_AL:
	pushfd
	pushad
	mov ah,0Eh
	xor bl,bl
	int 10h
	popad
	popfd
	retn
;------------------------------------------------------------------------------
WaitForKB:
	pushad
	mov ah,00h
	int 16h
	popad
	retn
;------------------------------------------------------------------------------