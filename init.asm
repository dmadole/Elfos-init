; This software is copyright 2021 by David S. Madole.
; You have permission to use, modify, copy, and distribute
; this software so long as this copyright notice is retained.
; This software may not be used in commercial applications
; without express written permission from the author.
;
; The author grants a license to Michael H. Riley to use this
; code for any purpose he sees fit, including commercial use,
; and without any need to include the above notice.


           ; Include kernal API entry points

           include bios.inc
           include kernel.inc

           ; Executable program header

           org     5000h - 6
           dw      start
           dw      end-start
           dw      start

start:     org     5000h
           br      main

           ; Build information

           db      6+80h              ; month
           db      16                 ; day
           dw      2021               ; year
           dw      3                  ; build
text:      db      'Written by David S. Madole',0

           ; Default file name

default:   db      'init.rc INIT.rc',0

           ; Main code starts here , check provided argument

main:      bn4     prepare

           sep     r4
           dw      f_setbd
           sep     r5

prepare:   ldi     fd.1               ; get file descriptor
           phi     rd
           ldi     fd.0
           plo     rd

           ldi     0                  ; no flags for open
           plo     r7

           lbr     firstnam

skipspc1:  inc     ra
firstnam:  ldn     ra                 ; skip any spaces
           lbz     usedeflt
           smi     '!'
           lbnf    skipspc1

           lbr     markname

usedeflt:  ldi     default.1
           phi     ra
           ldi     default.0
           plo     ra

           lbr     markname

skipspc2:  inc     ra
nextname:  ldn     ra                 ; skip any spaces
           lbz     notfound
           smi     '!'
           lbnf    skipspc2

markname:  glo     ra                 ; remember start of name
           plo     rf
           ghi     ra
           phi     rf

skipchar:  inc     ra
           ldn     ra                 ; end at null or space
           lbz     openfile
           smi     '!'
           lbdf    skipchar

           glo     r7
           str     ra
           inc     ra

           ; Open file for input and read data

openfile:  sep     scall              ; open file
           dw      o_open
           lbdf    nextname

           ldi     buffer.1           ; pointer to data buffer
           phi     rf
           ldi     buffer.0
           plo     rf

           ldi     2048.1             ; file length to read
           phi     rc
           ldi     2048.0
           plo     rc

           sep     scall              ; read from file
           dw      o_read

           sep     scall              ; close file when done
           dw      o_close

           ; We need to intercept the kernel o_wrmboot jump vector because,
           ; believe it or not, that is the recommended way for programs to
           ; return to Elf/OS, and apparently many do so. So we save what's
           ; there now, replace it with our own handler, then restore later.

           ldi     o_wrmboot.1        ; pointer to o_wrmboot jump vector
           phi     rd
           ldi     o_wrmboot.0
           plo     rd

           inc     rd                 ; skip lbr instruction

           ldi     warmsave.1         ; pointer to save o_wrmboot into
           phi     rf
           ldi     warmsave.0
           plo     rf

           ldn     rd                 ; save o_wrmboot high byte
           str     rf

           ldi     warmretn.1         ; replace o_wrmboot high byte
           str     rd

           inc     rd                 ; switch to low bytes
           inc     rf

           ldn     rd                 ; save o_wrmboot low byte
           str     rf

           ldi     warmretn.0         ; replace o_wrmboot high byte
           str     rd

           ; Now process the input file which has been read into memory
           ; one line at a time, executing each line as a command line
           ; including any arguments provided. This looks in the current
           ; directory and then in BIN directory if not found.

           ldi     buffer.1           ; reset buffer to beginning of input
           phi     rf
           ldi     buffer.0
           plo     rf

           ghi     rc                 ; has the length of data to process,
           adi     1                  ; adjust it so that we can just test
           phi     rc                 ; the high byte for end of input

           ; From here is where we repeatedly loop back for input lines and
           ; process each as a command line.

getline:   dec     rc                 ; if at end of input, then quit
           ghi     rc
           lbz     endfile

           lda     rf                 ; otherwise, skip any whitespace
           smi     '!'                ; leading the command line
           lbnf    getline

           inc     rc                 ; back up to first non-whitespace
           dec     rf                 ; characters of command

           ghi     rf                 ; make two copies of pointer to
           phi     ra                 ; command line
           phi     rb
           glo     rf
           plo     ra
           plo     rb

scanline:  dec     rc                 ; if at end of input, then quit
           ghi     rc
           lbz     endfile

           lda     ra                 ; otherwise, skip to first control
           smi     ' '                ; characters after command
           lbdf    scanline

           dec     ra                 ; back up to first control character
           ldi     0                  ; and overwrite with zero byte, then
           str     ra                 ; advance again
           inc     ra

           dec     r2                 ; save pointer to next input to process
           glo     ra                 ; as well as length of input remaining
           stxd                       ; since executing the program may wipe
           ghi     ra                 ; out all register contents as o_exec
           stxd                       ; does not preserve register values as
           glo     rc                 ; most elf/os calls do
           stxd
           ghi     rc
           stxd

           ldi     filepath.1         ; make a copy of the command line
           phi     rd                 ; concatenated to the static string
           ldi     filepath.0         ; /BIN/ so that we can try that if
           plo     rd                 ; program not found in current directory

strcpy:    lda     rb                 ; the copy is needed not just to prepend
           str     rd                 ; /BIN/ but also because o_exec modifies
           inc     rd                 ; the string it is passed in-place so
           lbnz    strcpy             ; we can't reuse it

           ldi     stcksave.1         ; pointer to save stack register to
           phi     rd
           ldi     stcksave.0
           plo     rd

           ghi     r2                 ; save stack pointer so that we can
           str     rd                 ; restore after o_exec in case called
           inc     rd                 ; program exits using o_wrmboot instead
           glo     r2                 ; of using sep sret
           str     rd

           sep     r4                 ; try executing the plain command line
           dw      o_exec
           lbnf    execgood

           ldi     binpath.1          ; if unsuccessful, reset pointer to the
           phi     rf                 ; copy with /BIN/ prepended
           ldi     binpath.0
           plo     rf
 
           sep     r4                 ; and then try that one
           dw      o_exec
           lbdf    execfail

execgood:  ldi     crlf.1             ; if exec is succesful, output a blank
           phi     rf                 ; line to separate output
           ldi     crlf.0
           plo     rf

           sep     r4
           dw      f_msg

execfail:  inc     r2                 ; if return is directly here, then
           ldxa                       ; execed program used sep sret and stack
           phi     rc                 ; is set correctly, restore the pointer
           ldxa                       ; to the input and length of input
           plo     rc
           ldxa
           phi     rf
           ldxa
           plo     rf
           
           lbr      getline            ; go find next line to process

           ; If the execed program ends with lbr o_wrmboot instead of sep sret
           ; then control will come here. Restore the saved stack pointer and
           ; jump to the normal return point.

warmretn:  ldi     stcksave.1         ; pointer to saved stack pointer value
           phi     rf
           ldi     stcksave.0
           plo     rf

           lda     rf                 ; copy saved value back into r2
           phi     r2
           ldn     rf
           plo     r2
           sex     r2             

           lbr     execgood           ; jump to normal return code

           ; Before we exit, we need to restore the original value of 
           ; o_wrmboot which we replaced earlier to point to our own
           ; return handling code.

endfile:   ldi     o_wrmboot.1        ; pointer to o_wrmboot jump vector
           phi     rd
           ldi     o_wrmboot.0
           plo     rd
           inc     rd                 ; skip lbr instruction

           ldi     warmsave.1         ; pointer to saved original o_wrmboot
           phi     rf
           ldi     warmsave.0
           plo     rf

           lda     rf                 ; restore saved o_wrmboot value
           str     rd
           inc     rd
           ldn     rf
           str     rd

           sep     r5                 ; return to elf/os

crlf:      db      13,10,0

           ; Error handling follows, mostly these just output a message and
           ; exit, but readfail also closes the input file first since it
           ; would be open at that point.

notfound:  ldi     openmesg.1   ; if unable to open input file
           phi     rf
           ldi     openmesg.0
           plo     rf
           lbr     failmsg

readfail:  sep     scall        ; if read on input file fails
           dw      o_close

           ldi     readmesg.1
           phi     rf
           ldi     readmesg.0
           plo     rf

failmsg:   sep     scall       ; output the message and return
           dw      o_msg
           sep     sret

openmesg:  db      'Input file not found',13,10,0
readmesg:  db      'Read file failed',13,10,0

           ; Include file descriptor in program image so it is initialized.

fd:        db      0,0,0,0
           dw      dta
           db      0,0
           db      0
           db      0,0,0,0
           dw      0,0
           db      0,0,0,0

           ; This is used to prefix a copy of the path to pass to exec
           ; a second time if the first time fails to find the command in
           ; the current directory.

binpath:   db      '/BIN/'    ; needs to be immediately prior to filepath

end:       ; These buffers are not included in the executable image but will
           ; will be in memory immediately following the loaded image.

filepath:  ds      0          ; overlay over dta, not used at same time
dta:       ds      512-2-2    ; likewise, overlay dta and next two variables
stcksave:  ds      2          ; place to save the stack while execing
warmsave:  ds      2          ; place to save the o_wrmboot vector
buffer:    ds      2048       ; load the input file to memory here

