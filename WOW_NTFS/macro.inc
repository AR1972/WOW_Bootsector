;------------------------------------------------------------------------------
macro disp_dword_hex_crlf arg1
;------------------------------------------------------------------------------
{
	local ddwhc.loop_start
	local ddwhc.loop_display

		pushfd
		pushad

		mov edx,arg1
		mov ecx,8
	ddwhc.loop_start:
		rol edx,4
		mov eax,edx
		and eax,0xf
		;--
		add al,0x30
		cmp al,0x39
		jna ddwhc.loop_display
		add al,0x07
	ddwhc.loop_display:
		;--
		call DISPLAY_AL
		loop ddwhc.loop_start

		call DISPLAY_CRLF

		popad
		popfd
}
;------------------------------------------------------------------------------