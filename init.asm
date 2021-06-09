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
           db      9                  ; day
           dw      2021               ; year
           dw      2                  ; build
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

           br      firstnam

skipspc1:  inc     ra
firstnam:  ldn     ra                 ; skip any spaces
           bz      usedeflt
           smi     '!'
           bnf     skipspc1

           br      markname

usedeflt:  ldi     default.1
           phi     ra
           ldi     default.0
           plo     ra

           br      markname

skipspc2:  inc     ra
nextname:  ldn     ra                 ; skip any spaces
           bz      notfound
           smi     '!'
           bnf     skipspc2

markname:  glo     ra                 ; remember start of name
           plo     rf
           ghi     ra
           phi     rf

skipchar:  inc     ra
           ldn     ra                 ; end at null or space
           bz      openfile
           smi     '!'
           bdf     skipchar

           glo     r7
           str     ra
           inc     ra

           ; Open file for input and read data

openfile:  sep     scall              ; open file
           dw      o_open
           bdf     nextname

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

           ldi     buffer.1           ; reset buffer to beginning
           phi     rf
           ldi     buffer.0
           plo     rf

           ghi     rc
           adi     1
           phi     rc

getline:   dec     rc
           ghi     rc
           bz      endfile

           lda     rf
           smi     '!'
           bnf     getline

           inc     rc
           dec     rf

           ghi     rf
           phi     ra
           phi     rb
           glo     rf
           plo     ra
           plo     rb

scanline:  dec     rc
           ghi     rc
           bz      endfile

           lda     ra
           smi     ' '
           bdf     scanline

           dec     ra
           ldi     0
           str     ra
           inc     ra

           dec     r2
           glo     ra
           stxd
           ghi     ra
           stxd
           glo     rc
           stxd
           ghi     rc
           stxd

           ldi     filepath.1
           phi     rd
           ldi     filepath.0
           plo     rd

strcpy:    lda     rb
           str     rd
           inc     rd
           bnz     strcpy

           sep     r4
           dw      o_exec
           bnf     execgood

           ldi     binpath.1
           phi     rf
           ldi     binpath.0
           plo     rf
 
           sep     r4
           dw      o_exec
           bdf     execfail

execgood:  ldi     crlf.1
           phi     rf
           ldi     crlf.0
           plo     rf

           sep     r4
           dw      f_msg

execfail:  inc     r2
           ldxa
           phi     rc
           ldxa
           plo     rc
           ldxa
           phi     rf
           ldxa
           plo     rf
           
           br      getline

endfile:   sep     r5

crlf:      db      13,10,0

           ; Error handling follows, mostly these just output a message and
           ; exit, but readfail also closes the input file first since it
           ; would be open at that point.

notfound:  ldi     openmesg.1   ; if unable to open input file
           phi     rf
           ldi     openmesg.0
           plo     rf
           br      failmsg

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


binpath:   db      '/BIN/'

end:       ; These buffers are not included in the executable image but will
           ; will be in memory immediately following the loaded image.

filepath:  ds      0
dta:       ds      512
buffer:    ds      2048

