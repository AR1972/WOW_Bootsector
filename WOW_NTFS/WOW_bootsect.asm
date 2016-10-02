use16
file 'VBS_part1.bin'
call wow
mov cx, 2000h - wow
mov di, wow
erace:
mov byte [di], byte 00h
inc di
loop erace
times 27Ah - ($-$$) db 90h
file 'VBS_part2.bin'
wow:
include 'WOW.asm'
times 2000h - ($ - $$)	db 0  ; pad to 8192b
