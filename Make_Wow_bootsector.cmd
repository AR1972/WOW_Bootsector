@echo OFF
"%~dp0bin\FASM.EXE"  "%~dp0Wow_bootsector.asm"
"%~dp0bin\PatchBootsect.exe" "%~dp0Wow_bootsector.bin" "%~dp0Wow_bootsect.exe"
DEL "%~dp0Wow_bootsector.bin"
pause
