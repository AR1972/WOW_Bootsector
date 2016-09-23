
;----------------------------------------------------------------------------------------------------
;||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
;----------------------------------------------------------------------------------------------------
decrypt:
;----------------------------------------------------------------------------------------------------

	pushad

	mov	esi, EncDataStart		; move start of our encrypted data to ESI

	cmp	word [esi],4241h		; check if Wow is encrypted
	jnz	isEncrypted
	cmp	word [esi+2],4443h
	jz	DecryptDone

isEncrypted:

	xor	ebx,ebx 			; zero EBX our loop counter
	mov	edi,EncKey			; move key to EDI
	mov	edx,EncKeyEnd			; compute key length
	sub	edx,EncKey			;

	push	edi
	mov	ecx,edx 			; decrypt key

DecryptKey:

	xor	byte [edi], 0FFh
	inc	edi
	loop	DecryptKey
	pop	edi

	mov	ecx, EncDataEnd 		; compute length to decrypt
	sub	ecx, EncDataStart		;

DecryptLoop:

	cmp	edx,ebx 			; compare loop count to key length
	je	ResetKey			; if loop count and key lenght = then reset to begining of key
	sub	byte [esi], byte 7Fh		; subtract 127, 127 was added durring encryption to help obfuscate the encryption key
	mov	al, byte [edi]			; move a byte of the encryption key to AL
	sub	byte [esi], al			; subtract key byte from SLIC byte
	inc	esi				; increment SLIC address
	inc	edi				; increment encryption key address
	inc	ebx				; increment loop counter
	loop	DecryptLoop			; loop
	jmp	DecryptDone			; loop is done

ResetKey:

	xor ebx,ebx				; zero the loop counter
	mov edi,EncKey				; move key to EDI
	jmp DecryptLoop 			; jump back in to the loop

DecryptDone:

	popad
	retn

;====================================================================================================
EncKey db 'KEYKEYKEYKEYKEYK'
EncKeyEnd:
;====================================================================================================
;
;