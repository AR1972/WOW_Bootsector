use16
;
DEBUG = 0
;
;==============================================================================
;||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
;==============================================================================
;
; Wow - SLIC injector, originaly written for DOS environment
; original authors: Flagmax & Yen
; reversed and modified for bootsector by untermensch 5-28-2010
;
; notes:
;
;  changed to low memory scan starting at 800h
;  changed OEMID is copied from SLIC, originaly stored as a seprate string
;  changed protected mode code, was unrelaible outside of DOS environment
;  added patch RSDT, XDST sub tables if existing SLIC is found, allows
;        use of SLIC from same OEM but diffrent table ID.
;
;==============================================================================
;||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
;==============================================================================

start:
		push ss 			 ; save everything
		push gs 			 ;
		push fs 			 ;
		push es 			 ;
		push ds 			 ;
		pushfd				 ;
		pushad				 ;

		mov ah,01h			 ; recovery
		int 16h
		cmp ah, 3Fh			 ; test for F5 key
		je  Quit

		push	cs
		pop	ds
		call	FindRSDP
		jb	Quit
		call	GetTablePointers
		call	UnRealMode
		jb	Quit
		push	cs
		pop	ds

		lea	bx, [XSDTPointer]	 ; is XSDT null
		mov	eax, [cs:bx]
		cmp	eax, 0
		jz	NoXSDT

		lea	bx, [RSDTPointer]	 ; is RSDT lower in memory than XSDT
		mov	esi, [cs:bx]
		cmp	esi, eax
		jl	XSDTLow

		lea	bx, [TableToModify]	 ; table to modify XSDT
		mov	[cs:bx], eax
		jmp	XSDTExists
XSDTLow:
		lea	bx, [TableToModify]	 ; table to modify RSDT
		mov	[cs:bx], esi
		jmp	XSDTExists
NoXSDT:
		lea	bx, [RSDTPointer]
		mov	esi, [cs:bx]
		lea	bx, [TableToModify]	 ; table to modify RSDT
		mov	[cs:bx], esi
		jmp	XSDTNotExists
XSDTExists:
		call	FindExsistingSLICXSDT
		cmp	eax, 1
		jnz	NoExistingSLICXSDT	 ; no existing SLIC
		call	MoveSLIC
		call	GetRSDTTableEnd
		call	PatchSubTablesOEMID	      ;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
		call	GetXSDTTableEnd
		call	PatchSubTablesOEMID	      ;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
		call	GetXSDTTableEnd
		call	AddOEMIDToTable
		call	GetXSDTTableEnd
		call	CheckSumTable
		call	GetRSDTTableEnd
		call	AddOEMIDToTable
		call	GetRSDTTableEnd
		call	CheckSumTable
		jmp	Quit
NoExistingSLICXSDT:
		call	GetXSDTTableEnd
		mov	ecx, [gs:edi]		; check if there is room at end of XSDT
		cmp	ecx, 0			; for SLIC pointer
		jnz	MoveNextTableXSDT
		mov	ecx, [gs:edi+4]
		cmp	ecx, 0
		jnz	MoveNextTableXSDT
CopySLICReadyXSDT:
		call	FindSLICSpace
		cmp	eax, 0
		jz	Quit
		call	MoveSLIC
		call	GetXSDTTableEnd
		lea	bx, [SLICEntry]
		mov	eax, [cs:bx]
		mov	[gs:edi], eax
		xor	eax, eax
		mov	[gs:edi+4], eax
		mov	eax, [gs:esi+4]
		add	eax, 8
		mov	[gs:esi+4], eax
		call	GetXSDTTableEnd
		call	AddOEMIDToTable
		call	GetXSDTTableEnd
		call	CheckSumTable
		call	GetRSDTTableEnd
		call	AddOEMIDToTable
		call	GetRSDTTableEnd
		call	CheckSumTable
		jmp	Quit
MoveNextTableXSDT:
		call	GetXSDTTableEnd
		mov	eax, edi		 ; move XSDT end to EAX
		call	FindNextTableXSDT
		cmp	eax, 1
		jnz	FindNextTableXSDTFail
		lea	bx, [TableToMove]
		mov	[cs:bx], esi
		call	GetXSDTTableEnd
		mov	eax, [gs:edi+4]
		lea	bx, [TableToModify]
		mov	esi, [cs:bx]
		call	ScanMemory
		cmp	eax, 0
		jz	Quit
		lea	bx, [TableToModify]
		mov	[cs:bx], esi
		call	GetXSDTTableEnd
		lea	bx, [TableToModify]
		mov	esi, [cs:bx]
		mov	ebx, eax
		call	MoveDSDT
		lea	bx, [TableToModify]
		mov	esi, [cs:bx]
		lea	bx, [TableToMove]
		mov	eax, [cs:bx]
		mov	[gs:eax], esi
		call	GetXSDTTableEnd
		mov	eax, edi
		call	GetRSDTTableEnd
		call	FindNextTableRSDT
		cmp	eax, 1
		jnz	CopySLICReadyXSDT
		lea	bx, [TableToModify]
		mov	eax, [cs:bx]
		mov	[gs:esi], eax
		jmp	CopySLICReadyXSDT
FindNextTableXSDTFail:
		call	FindMCFGinXSDT
		cmp	eax, 1
		jz	OverwritePointerXSDT
		call	FindBOOTinXSDT
		cmp	eax, 1
		jnz	Quit
OverwritePointerXSDT:
		lea	bx, [OverWriteEntry]
		mov	[cs:bx], esi
		call	FindSLICSpace
		cmp	eax, 0
		jz	Quit
		call	MoveSLIC
		lea	bx, [OverWriteEntry]
		mov	eax, [cs:bx]
		lea	bx, [SLICEntry]
		mov	esi, [cs:bx]
		mov	[gs:eax], esi
		call	GetXSDTTableEnd
		call	AddOEMIDToTable
		call	GetXSDTTableEnd
		call	CheckSumTable
		call	GetRSDTTableEnd
		call	AddOEMIDToTable
		call	GetRSDTTableEnd
		call	CheckSumTable
		jmp	Quit
XSDTNotExists:					 ; not ACPI 2.0 work on RSDT
		call	FindExistingSLICRSDT
		cmp	eax, 1
		jnz	NoExistingSLICRSDT
		call	MoveSLIC
		call	GetRSDTTableEnd
		call	PatchSubTablesOEMID	      ;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
		call	GetRSDTTableEnd
		call	AddOEMIDToTable
		call	GetRSDTTableEnd
		call	CheckSumTable
		jmp	Quit
NoExistingSLICRSDT:				 ; check for null dword at end of RSDT
		call	GetRSDTTableEnd
		mov	ecx, [gs:edi]
		cmp	ecx, 0
		jnz	MoveNextTableRSDT
CopySLICReadyRSDT:
		call	FindSLICSpace
		cmp	eax, 0			 ; 0 = find SLIC space fail
		jz	Quit
		call	MoveSLIC
		call	GetRSDTTableEnd
		lea	bx, [SLICEntry]
		mov	eax, [cs:bx]
		mov	[gs:edi], eax
		mov	eax, [gs:esi+4]
		add	eax, 4
		mov	[gs:esi+4], eax
		call	GetRSDTTableEnd
		call	AddOEMIDToTable
		call	GetRSDTTableEnd
		call	CheckSumTable
		jmp	Quit
MoveNextTableRSDT:
		call	GetRSDTTableEnd
		mov	eax, edi
		call	FindNextTableRSDT
		cmp	eax, 1
		jnz	FindNextTableRSDTFail
		lea	bx, [TableToMove]
		mov	[cs:bx], esi
		call	GetRSDTTableEnd
		mov	eax, [gs:edi+4]
		lea	bx, [TableToModify]
		mov	esi, [cs:bx]
		call	ScanMemory		 ; returns with free area addr in ESI
		cmp	eax, 0
		jz	Quit
		lea	bx, [TableToModify]
		mov	[cs:bx], esi
		call	GetRSDTTableEnd
		lea	bx, [TableToModify]
		mov	esi, [cs:bx]
		mov	ebx, eax
		call	MoveDSDT
		lea	bx, [TableToModify]
		mov	esi, [cs:bx]
		lea	bx, [TableToMove]
		mov	eax, [cs:bx]
		mov	[gs:eax], esi
		jmp	CopySLICReadyRSDT
FindNextTableRSDTFail:
		call	FindMCFGinRSDT
		cmp	eax, 1
		jz	OverwritePointerRSDT
		call	FindBOOTinRSDT
		cmp	eax, 1
		jnz	RelocateDSDT
OverwritePointerRSDT:
		lea	bx, [OverWriteEntry]
		mov	[cs:bx], esi
		call	FindSLICSpace
		cmp	eax, 0
		jz	Quit
		call	MoveSLIC
		lea	bx, [OverWriteEntry]
		mov	eax, [cs:bx]
		lea	bx, [SLICEntry]
		mov	esi, [cs:bx]
		mov	[gs:eax], esi
		call	GetRSDTTableEnd
		call	AddOEMIDToTable
		call	GetRSDTTableEnd
		call	CheckSumTable
		jmp	Quit

;==============================================================================
; checks if the table blocking our SLIC pointer is the DSDT then moves it
;==============================================================================

RelocateDSDT:
		call	FindFACPinRSDT
		cmp	eax, 1
		jnz	Quit
		lea	bx, [FACPEntry]        ; move FACP addr to ESI
		mov	[cs:bx], esi
		mov	eax, [gs:esi+28h]	 ; get DSDT addr from FACP table to EAX
		lea	bx, [DSDTEntry]
		mov	[cs:bx], eax		 ; save DSDT addr to [DSDTEntry]
		call	GetRSDTTableEnd 	 ; returns with ESI = RSDT start, EDI = RSDT end
		mov	ecx, [gs:edi]		 ; if the last table is not the DSDT
		cmp	ecx, 'DSDT'		 ; fail
		jnz	Quit
		lea	bx, [TableToModify]	 ; move RSDT addr to ESI
		mov	esi, [cs:bx]
		lea	bx, [DSDTEntry]        ; move DSDT addr to EDI
		mov	edi, [cs:bx]
		mov	eax, [gs:edi+4] 	 ; move DSDT len to EAX
		call	ScanMemory
		cmp	eax, 0			 ; 0 = failed to find space for DSDT
		jz	Quit
		lea	bx, [TableToModify]	 ; move free space addr to
		mov	[cs:bx], esi		 ; [TableToModify]
		lea	bx, [DSDTEntry]        ; move DSDT addr to EDI
		mov	edi, [cs:bx]
		mov	ebx, eax		 ; move DSDT len to EBX
		call	MoveDSDT		 ; move DSDT
		lea	bx, [TableToModify]	 ; move DSDT copy to addr ESI
		mov	esi, [cs:bx]
		lea	bx, [DSDTEntry]        ; move DSDT copy from addr to EDI
		mov	edi, [cs:bx]
		call	DSDTCopyVerify		 ; verify byte for byte copy
		cmp	ecx, 1			 ; 1 = fail
		jnz	Quit
		lea	bx, [FACPEntry]        ; get FACP addr to ESI
		mov	esi, [cs:bx]
		lea	bx, [DSDTEntry]        ; get DSDT addr to EDI
		mov	edi, [cs:bx]
		cmp	[gs:esi+28h], edi	 ; check DSDT addr with FACP
		jnz	Quit
		lea	bx, [FACPEntry]
		mov	esi, [cs:bx]		 ; get FACP addr to ESI
		lea	bx, [TableToModify]
		mov	eax, [cs:bx]		 ; get DSDT copy to addr to EAX
		mov	[gs:esi+28h], eax	 ; patch FACP with DSDT's new location
		lea	bx, [FACPEntry]
		mov	esi, [cs:bx]		 ; get FACP to ESI
		call	CheckSumTable		 ; checksum FACP
		jmp	CopySLICReadyRSDT

;==============================================================================
ScanMemory:
;------------------------------------------------------------------------------
; some chipsets dont zero memory (Intel X58 for example) which will cause
; this function to fail to find space for the ACPI table.
;
; entry:
;  EAX has length to find
;  ESI has RSDT or XSDT address
; return:
;  ESI has beggining of free space
;  EAX = 0 if fail
;------------------------------------------------------------------------------

		xor	edx, edx
		mov	esi, 800h
		mov	ebx, 0A0000h
ScanLowMemoryLoop:
		cmp	edx, eax
		jz	ScanLowMemoryEnd
		inc	edx
		inc	esi
		cmp	esi, ebx
		je	ScanLowMemoryFail
		cmp	byte [gs:esi], 0
		jz	WriteTest
		mov	edx, 0
		jmp	ScanLowMemoryLoop
WriteTest:
		mov	byte [gs:esi], 0FFh
		cmp	byte [gs:esi], 0FFh
		jnz	WriteFail
		mov	byte [gs:esi], 0
		jmp	ScanLowMemoryLoop
WriteFail:
		mov	edx, 0
		jmp	ScanLowMemoryLoop
ScanLowMemoryFail:
		xor	edx, edx
		mov	ebx, esi
		add	ebx, 400000h
ScanHiMemoryLoop:
		cmp	edx, eax
		jz	ScanHiMemoryEnd
		inc	edx			 ; incriment found len counter
		inc	esi
		cmp	esi, ebx
		je	ScanHiMemoryFail
		cmp	byte [gs:esi], 0
		jz	ScanHiMemoryLoop
		mov	edx, 0			 ; reset found len counter to 0
		jmp	ScanHiMemoryLoop
ScanHiMemoryFail:
		mov	eax, 0
ScanLowMemoryEnd:
ScanHiMemoryEnd:
		sub	esi, eax
		retn

;==============================================================================
CheckSumTable:
;------------------------------------------------------------------------------
; checksums table
; entry:
;  ESI has table to checksum
;------------------------------------------------------------------------------

		mov	al, 0
		mov	[gs:esi+9], al
		mov	edi, [gs:esi+4]
		add	edi, esi
		xor	eax, eax
		xor	ecx, ecx
		push	esi
CheckSumTableLoop:
		mov	al, [gs:esi]
		add	cl, al
		inc	esi
		cmp	esi, edi
		jnz	CheckSumTableLoop
		pop	esi
		xor	cl, 0FFh
		inc	cl
		mov	[gs:esi+9], cl
		retn

;==============================================================================
FindNextTableRSDT:
;------------------------------------------------------------------------------
; entry:
;  ESI has RSDT addr
;  EAX has RSDT end
;------------------------------------------------------------------------------

		mov	edi, [gs:esi+4]
		add	edi, esi
		add	esi, 24h
		sub	esi, 4
		sub	edi, 4
FindNextTableRSDTLoop:
		add	esi, 4
		cmp	[gs:esi], eax
		jz	FindNextTableRSDTSuccess
		cmp	esi, edi
		jle	FindNextTableRSDTLoop
		jmp	FindNextTableRSDTFailed
FindNextTableRSDTSuccess:
		mov	eax, 1
FindNextTableRSDTFailed:
		retn

;==============================================================================
FindNextTableXSDT:
;------------------------------------------------------------------------------
; entry:
;  ESI has XSDT addr
;  EAX has XSDT end
;------------------------------------------------------------------------------

		mov	edi, [gs:esi+4] 	 ; move XSDT len to EDI
		add	edi, esi		 ; add XSDT addr to XSDT len
		add	esi, 24h		 ; move ESI past XSDT table header
		sub	esi, 8
		sub	esi, 8
FindNextTableXSDTLoop:
		add	esi, 8
		cmp	[gs:esi], eax		 ;
		jz	FindNextTableXSDTSuccess
		cmp	esi, edi
		jle	FindNextTableXSDTLoop
		jmp	FindNextTableXSDTFailed
FindNextTableXSDTSuccess:
		mov	eax, 1
FindNextTableXSDTFailed:
		retn

;==============================================================================
MoveDSDT:
;------------------------------------------------------------------------------
; entry:
;  EDI has DSDT copy from location
;  ESI has DSDT copy to location
;  EBX has DSDT len
;------------------------------------------------------------------------------

		xor	eax, eax		 ; zero EAX
		mov	al, [gs:edi]		 ; move byte from copy from location
		mov	[gs:esi], al		 ; to copy to location
		inc	esi
		inc	edi
		dec	ebx
		cmp	ebx, 0
		jnz	MoveDSDT
		retn

;==============================================================================
GetRSDTTableEnd:
;------------------------------------------------------------------------------
; return:
;  ESI has RSDT pointer
;  EDI has RSDT end
;------------------------------------------------------------------------------

		lea	bx, [RSDTPointer]	 ; get RSDT addr into ESI
		mov	esi, [cs:bx]
		mov	edi, [gs:esi+4] 	 ; get RSDT len into EDI
		add	edi, esi		 ; add RSDT len to RSDT addr
		retn

;==============================================================================
GetXSDTTableEnd:
;------------------------------------------------------------------------------
; return:
;  ESI has XSDT pointer
;  EDI has XSDT end
;------------------------------------------------------------------------------

		lea	bx, [XSDTPointer]	 ; get XSDT addr into ESI
		mov	esi, [cs:bx]
		mov	edi, [gs:esi+4] 	 ; get XSDT len into EDI
		add	edi, esi		 ; add XSDT len to XSDT addr
		retn

;==============================================================================
FindSLICSpace:
;------------------------------------------------------------------------------
; finds unused memory for SLIC table
; return:
;  ESI has address of free memory
;  [SLICEntry] has address of free memory
;  [TableToModify] has address of free memory
;------------------------------------------------------------------------------

		lea	bx, [TableToModify]
		mov	esi, [cs:bx]
		mov	eax, 176h
		call	ScanMemory
		cmp	eax, 0
		jz	FindSLICSpaceFail
		lea	bx, [SLICEntry]
		mov	[cs:bx], esi
		lea	bx, [TableToModify]
		mov	[cs:bx], esi
FindSLICSpaceFail:
		retn

;==============================================================================
FindExsistingSLICXSDT:
;------------------------------------------------------------------------------
; searches XSDT for SLIC sub table
; return:
;  ESI has SLIC position in XSDT
; [SLICEntry] has SLIC position in XSDT
;------------------------------------------------------------------------------

		xor	eax, eax
		call	GetXSDTTableEnd
		add	esi, 24h
		sub	esi, 8
		sub	edi, 8
FindExsistingSLICXSDTLoop:
		add	esi, 8
		mov	ecx, [gs:esi]		      ; move pointer from XSDT to ECX
		cmp	dword [gs:ecx], 'SLIC'	      ; compare [ECX] to SLIC
		jz	ExistingSLICXSDTFound
		cmp	esi, edi
		jnz	FindExsistingSLICXSDTLoop
		retn
ExistingSLICXSDTFound:
		mov	eax, 1
		mov	esi, ecx
		lea	bx, [SLICEntry]
		mov	[cs:bx], esi
		retn

;==============================================================================
FindExistingSLICRSDT:
;------------------------------------------------------------------------------
; searches RSDT for SLIC sub table
; return:
;  ESI has SLIC position in RSDT
;  [SLICEntry] has SLIC position in RSDT
;------------------------------------------------------------------------------

		xor	eax, eax
		call	GetRSDTTableEnd
		add	esi, 24h
		sub	esi, 4
		sub	edi, 4
FindExistingSLICRSDTLoop:
		add	esi, 4
		mov	ecx, [gs:esi]
		cmp	dword [gs:ecx], 'SLIC'
		jz	ExistingSLICRSDTFound
		cmp	esi, edi
		jnz	FindExistingSLICRSDTLoop
		retn
ExistingSLICRSDTFound:
		mov	eax, 1
		mov	esi, ecx
		lea	bx, [SLICEntry]
		mov	[cs:bx], esi
		retn

;==============================================================================
FindMCFGinRSDT:
;------------------------------------------------------------------------------
; searches RSDT for MCFG sub table
; return:
;  ESI has MCFG position in RSDT
;------------------------------------------------------------------------------

		xor	eax, eax
		call	GetRSDTTableEnd
		add	esi, 24h
		sub	esi, 4
		sub	edi, 4
FindMCFGinRSDTLoop:
		add	esi, 4
		mov	ecx, [gs:esi]
		cmp	dword [gs:ecx], 'MCFG'
		jz	FindMCFGinRSDTEnd
		cmp	esi, edi
		jnz	FindMCFGinRSDTLoop
		retn
FindMCFGinRSDTEnd:
		mov	eax, 1
		retn

;==============================================================================
FindBOOTinRSDT:
;------------------------------------------------------------------------------
; searches RSDT for BOOT sub table
; return:
;  ESI has BOOT position in RSDT
;------------------------------------------------------------------------------

		xor	eax, eax
		call	GetRSDTTableEnd
		add	esi, 24h
		sub	esi, 4
		sub	edi, 4
FindBOOTinRSDTLoop:
		add	esi, 4
		mov	ecx, [gs:esi]
		cmp	dword [gs:ecx], 'BOOT'
		jz	FindBOOTinRSDTEnd
		cmp	esi, edi
		jnz	FindBOOTinRSDTLoop
		retn
FindBOOTinRSDTEnd:
		mov	eax, 1
		retn

;==============================================================================
FindMCFGinXSDT:
;------------------------------------------------------------------------------
; searches XSDT for MCFG sub table
; return:
;  ESI has MCFG position in XSDT
;------------------------------------------------------------------------------

		xor	eax, eax
		call	GetXSDTTableEnd
		add	esi, 24h
		sub	esi, 8
		sub	edi, 8
FindMCFGinXSDTLoop:
		add	esi, 8
		mov	ecx, [gs:esi]
		cmp	dword [gs:ecx], 'MCFG'
		jz	FindMCFGinXSDTEnd
		cmp	esi, edi
		jnz	FindMCFGinXSDTLoop
		retn
FindMCFGinXSDTEnd:
		mov	eax, 1
		retn

;==============================================================================
FindBOOTinXSDT:
;------------------------------------------------------------------------------
; searches XSDT for BOOT sub table
; return:
;  ESI has BOOT position in XSDT
;------------------------------------------------------------------------------

		xor	eax, eax
		call	GetXSDTTableEnd
		add	esi, 24h
		sub	esi, 8
		sub	edi, 8
FindBOOTinXSDTLoop:
		add	esi, 8
		mov	ecx, [gs:esi]
		cmp	dword [gs:ecx], 'BOOT'
		jz	FindBOOTinXSDTEnd
		cmp	esi, edi
		jnz	FindBOOTinXSDTLoop
		retn
FindBOOTinXSDTEnd:
		mov	eax, 1
		retn

;==============================================================================
FindFACPinRSDT:
;------------------------------------------------------------------------------
; searches RSDT for FACP sub table
; return:
;  ESI had FACP position in RSDT
;------------------------------------------------------------------------------

		xor	eax, eax
		call	GetRSDTTableEnd
		add	esi, 24h
		sub	esi, 4
		sub	edi, 4
FindFACPinRSDTLoop:
		add	esi, 4
		mov	ecx, [gs:esi]
		cmp	dword [gs:ecx], 'FACP'
		jz	FindFACPinRSDTEnd
		cmp	esi, edi
		jnz	FindFACPinRSDTLoop
		retn
FindFACPinRSDTEnd:
		mov	eax, 1
		mov	esi, ecx
		retn

;==============================================================================
GetTablePointers:
;------------------------------------------------------------------------------
; saves RSDP OEMID, RSDT pointer, XSDT pointer
; entry:
;  DI has RSDP pointer
;------------------------------------------------------------------------------

		lea	bx, [RSDPOEMID] 	 ; save OEMID from RSDP
		mov	eax, [es:di+9h]
		mov	[cs:bx], eax

		mov	eax, [es:di+10h]	 ; move RSDT address to EAX
		lea	bx, [RSDTPointer]
		mov	[cs:bx], eax		 ; move RSDT to mem loc RSDTPointer

		mov	al, [es:di+0Fh] 	 ; revision byte to AL
		cmp	al, 2			 ; compare revision byte to 2
		jnz	GetTablePointerEnd	 ; if not revision 2 end
		mov	eax, [es:di+18h]	 ; move XSDT address to EAX
		cmp	eax, 0			 ; compare XSDT address to 0
		jz	GetTablePointerEnd	 ; if XSDT null end
		lea	bx, [XSDTPointer]	 ; move XSDT address to XSDTPointer
		mov	[cs:bx], eax
GetTablePointerEnd:
		retn

;==============================================================================
AddOEMIDToTable:
;------------------------------------------------------------------------------
; adds OEMID & TableID to RSDT and XSDT
; entry:
;  ESI has address of table to patch
;------------------------------------------------------------------------------

		add	esi, 0Ah
		mov	edi, 0Eh
		add	edi, esi
		lea	 ebx, [SLIC+0Ah]
AddOEMIDToTableLoop:
		xor	eax, eax
		mov	eax, [cs:ebx]
		mov	[gs:esi], al
		inc	esi
		inc	ebx
		cmp	esi, edi
		jnz	AddOEMIDToTableLoop
		retn

;==============================================================================
MoveSLIC:
;------------------------------------------------------------------------------
; moves SLIC table to found free memory location
;------------------------------------------------------------------------------

		lea	bx, [SLICEntry]        ; SLIC pointer to ESI
		mov	esi, [cs:bx]
		mov	edi, 176h
		add	edi, esi		 ; add SLIC len to SLIC pointer
		lea	ebx, [SLIC]
		mov	edx, 0
MoveSLICLoop:
		xor	eax, eax
		mov	eax, [cs:edx+ebx]
		mov	[gs:esi], al
		inc	esi
		inc	edx
		cmp	esi, edi
		jnz	MoveSLICLoop

;==============================================================================
; checksum SLIC table
;==============================================================================

		lea	bx, [SLICEntry]
		mov	esi, [cs:bx]
		mov	al, 0
		mov	[gs:esi+9], al		 ; zero SLIC checksum
		mov	edi, 176h
		add	edi, esi
		xor	eax, eax
		xor	ecx, ecx
CheckSumSLICLoop:				 ; compute slic checksum loop
		mov	al, [gs:esi]
		add	cl, al
		inc	esi
		cmp	esi, edi
		jnz	CheckSumSLICLoop

		lea	bx, [SLICEntry]
		mov	esi, [cs:bx]
		xor	cl, 0FFh
		inc	cl
		mov	[gs:esi+9], cl		 ; move checksum to SLIC
		retn

;==============================================================================
DSDTCopyVerify:
;------------------------------------------------------------------------------
; entry:
;  EDI has DSDT copy from addr
;  ESI has DSDT copy to addr
;------------------------------------------------------------------------------

		mov	ecx, [gs:edi+4] 	; get DSDT len into ECX
		add	ecx, edi		; add DSDT addr to DSDT len
DSDTCopyVerifyLoop:
		xor	eax, eax		; zero EAX
		xor	ebx, ebx		; zero EBX
		mov	al, [gs:esi]
		mov	bl, [gs:edi]
		cmp	al, bl
		jnz	DSDTCopyVerifyFail
		inc	esi
		inc	edi
		cmp	edi, ecx
		jnz	DSDTCopyVerifyLoop
		mov	ecx, 1
DSDTCopyVerifyFail:
		retn

;------------------------------------------------------------------------------
; data section
;------------------------------------------------------------------------------
RSDPOEMID	     dd 0
RSDTPointer	     dd 0
XSDTPointer	     dd 0
FACPEntry	     dd 0
DSDTEntry	     dd 0
OverWriteEntry	     dd 0
TableToMove	     dd 0
TableToModify	     dd 0
SLICEntry	     dd 0
StringRSDP	     db 'RSD PTR ',0
		     db 'FLAGMAX',0
SLIC file '..\SLIC\dummy.bin'
;------------------------------------------------------------------------------
;
;==============================================================================
UnRealMode:
;------------------------------------------------------------------------------
; changes machine to unreal mode state
;------------------------------------------------------------------------------

		push	esi
		call	ProtectedMode
		jb	UnRealModeEnd
		call	A20Gate
		jb	UnRealModeEnd
		push	ax
		mov	ax, cs
		xor	ax, ax
		mov	gs, ax
		pop	ax
		clc
UnRealModeEnd:
		pop	esi
		retn

;==============================================================================
A20Gate:
;------------------------------------------------------------------------------
; enables the A20 gate to allow access to high memory
;------------------------------------------------------------------------------

		push	ax
		mov	al, 0D1h
		out	64h, al
		call	A20ReadyLoop
		mov	al, 0DFh
		out	60h, al
		call	A20ReadyLoop
		mov	al, 0FFh
		out	64h, al
		call	A20ReadyLoop
		clc
		pop	ax
		retn

;==============================================================================
A20ReadyLoop:
;------------------------------------------------------------------------------
; A20 sub function
;------------------------------------------------------------------------------

		in	al, 64h
		jmp	$+2
		and	al, 2
		jnz	A20ReadyLoop
		retn

;==============================================================================
GDT1:
;------------------------------------------------------------------------------

		dw    0 	; limit
		dw    0 	; base
		db    0 	; hibase
		db    0 	; access
		db    0 	; hilimit
		db    0 	; msbase

		dw    0FFFFh	; limit
		dw    0 	; base
		db    0 	; hibase
		db    93h	; access
		db    0 	; hilimit
		db    0 	; msbase

		dw    0FFFFh	; limit
		dw    0 	; base
		db    0 	; hibase
		db    93h	; access
		db    8Fh	; hilimit (4GB)
		db    0 	; msbase
GDT1_END:
GDTR		dw    GDT1_END - GDT1 - 1h
GDT		dd    0

;==============================================================================
ProtectedMode:
;------------------------------------------------------------------------------
; switches processor to protected mode
;------------------------------------------------------------------------------

		mov	eax, cr0
		ror	eax, 1
		jb	ProtectedModeEnd
		mov	eax, cs
		shl	eax, 4
		add	eax, GDT1
		mov	[ds:GDT], eax
		cli
		lgdt	fword [ds:GDTR]
		mov	eax, cr0
		or	al, 1
		mov	dx, 10h
		mov	cr0, eax
		jmp	short $+2
		mov	fs, dx
		mov	gs, dx
		mov	es, dx
		mov	ds, dx
		and	al, 0FEh
		mov	cr0, eax
		jmp	short $+2
		clc
		sti
ProtectedModeEnd:
		retn

;==============================================================================
Quit:
;------------------------------------------------------------------------------

		popad
		popfd
		pop ds
		pop es
		pop fs
		pop gs
		pop ss
		retn

;==============================================================================
GetRSDPStringEnd:
;------------------------------------------------------------------------------

		push	si
		push	ax
		mov	cx, 0FFFFh
GetRSDPStringEndLoop:
		inc	cx
		lodsb
		cmp	al, 0
		jnz	GetRSDPStringEndLoop
		pop	ax
		pop	si
		retn

;==============================================================================
ScanLowMemoryRSDP:
;------------------------------------------------------------------------------
; sub function of FindRSDP does the string compare
;------------------------------------------------------------------------------

		push	si
		push	dx
		push	cx
		push	bx
		push	ax
		push	cx
		call	GetRSDPStringEnd
		mov	dx, cx
		pop	cx
		lodsb
ScanLowMemoryRSDPLoop:
		repne scasb
		stc
		jcxz	ScanLowMemoryRSDPEnd
		push	si
		push	di
		repe cmpsb
		mov	bx, si
		pop	di
		pop	si
		sub	bx, si
		cmp	bx, dx
		jl	ScanLowMemoryRSDPLoop
		dec	di
		clc
ScanLowMemoryRSDPEnd:
		pop	ax
		pop	bx
		pop	cx
		pop	dx
		pop	si
		retn

;==============================================================================
FindRSDP:
;------------------------------------------------------------------------------
; scans low memory for RSDP string
;------------------------------------------------------------------------------

		lea	si, [cs:StringRSDP]
		mov	ax, 0E000h
		mov	es, ax
		mov	cx, 0FFFFh
		xor	di, di
		call	ScanLowMemoryRSDP
		jnb	FindRSDPEnd

		lea	si, [cs:StringRSDP]
		mov	ax, 0F000h
		mov	es, ax
		mov	cx, 0FFFFh
		xor	di, di
		call	ScanLowMemoryRSDP
		jnb	FindRSDPEnd

		lea	si, [cs:StringRSDP]
		mov	ax, 9F00h
		mov	es, ax
		mov	cx, 1000h
		xor	di, di
		call	ScanLowMemoryRSDP
FindRSDPEnd:
		retn

;==============================================================================
PatchSubTablesOEMID:
;------------------------------------------------------------------------------
; patches and  checksums RSDT, XSDT sub tables
; entry:
;  ESI has RSDT/XSDT start addr
;  EDI has RSDT/XSDT end addr
; note:
;  call GetRSDTTableEnd/GetXSDTTableEnd before calling this function
;------------------------------------------------------------------------------

		add	esi, 24h
		sub	esi, 4
		lea	bx, [RSDPOEMID]
		mov	eax, [cs:bx]
PatchSubTablesOEMIDLoop:
		cmp	esi, edi
		jz	PatchSubTablesOEMIDEnd
		add	esi, 4
		mov	ecx, [gs:esi]
		cmp	ecx, 0
		jz	PatchSubTablesOEMIDLoop
		cmp	dword [gs:ecx+0Ah], eax
		jnz	PatchSubTablesOEMIDLoop
		pushad
		mov	esi, ecx
		push	esi
		call	AddOEMIDToTable
		pop	esi
		call	CheckSumTable
		popad
		jmp	PatchSubTablesOEMIDLoop
PatchSubTablesOEMIDEnd:
		retn

;==============================================================================
; Wow end
;
if (DEBUG = 1)
   include 'disp.inc'
end if
