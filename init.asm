;  Copyright 2021, David S. Madole <david@madole.net>
;
;  This program is free software: you can redistribute it and/or modify
;  it under the terms of the GNU General Public License as published by
;  the Free Software Foundation, either version 3 of the License, or
;  (at your option) any later version.
;
;  This program is distributed in the hope that it will be useful,
;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;  GNU General Public License for more details.
;
;  You should have received a copy of the GNU General Public License
;  along with this program.  If not, see <https://www.gnu.org/licenses/>.


           ; Include kernal API entry points

           include bios.inc
           include kernel.inc


           ; Executable program header

           org     2000h - 6
           dw      start
           dw      end-start
           dw      start

start:     org     2000h
           br      main


           ; Build information

           db      8+80h              ; month
           db      12                 ; day
           dw      2021               ; year
           dw      6                  ; build

           db      'See github.com/dmadole/Elfos-init for more info',0


           ; Main code starts here, check if EF4 signal is asserted, if so,
           ; just quickly exit. This is to allow bypassing of init at 
           ; start-up in case a file it is calling is crashing or similar.

main:      ldi     0                  ; clear flag for verbose output
           plo     rb

           bn4     checkopt           ; if ef4 not asserted, start normally

           sep     scall              ; otherwise set auto-baud and return
           dw      o_setbd

return:    sep     sret               ; return to elf/os


           ; Check for command-line arguments. Only one option is recognized
           ; which is -v for verbose output. Normally init avoids sending
           ; any output, especially not until after the first program has
           ; run, since at startup there is no good way to know if we even
           ; have a valid output device that is configured properly.
           ; The -v option enables error messages that would be suppressed
           ; otherwise, for help in troubleshooting.

checkopt:  lda     ra                  ; skip any whitespace
           lbz     rewindin
           smi     '!'
           lbnf    checkopt

           smi     '-'-'!'             ; if char is not dash, then not valid
           lbnz    rewindin

           lda     ra                  ; if option is not 'v' then not valid
           smi     'v'
           lbz     verbose

           sep     sret                ; ironically, we cant give an error

verbose:   inc     rb                  ; enable output

checkend:  lda     ra                  ; skip any whitespace
           lbz     rewindin
           smi     '!'
           lbnf    checkend

rewindin:  dec     ra                  ; backup to reverse inc of lda


           ; Check minimum kernel version we need before doing anything else,
           ; in particular we need support for the heap manager to allocate
           ; memory for the persistent module to use.

           ldi     high k_ver          ; get pointer to kernel version
           phi     r7
           ldi     low k_ver
           plo     r7

           lda     r7                  ; if major is non-zero we are good
           lbnz    findfile

           lda     r7                  ; if major is zero and minor is 4
           smi     4                   ;  or higher we are good
           lbdf    findfile

           glo     rb                  ; only output if verbose set
           lbz     return

           sep     scall               ; if not meeting minimum version
           dw      o_inmsg
           db      'ERROR: Needs kernel version 0.4.0 or higher',13,10,0
           sep     sret


           ; If no filename were provided on the command line, load pointer
           ;  to default list of input files to search for.

findfile:  ldi     high fd            ; get file descriptor
           phi     rd
           ldi     low fd
           plo     rd

           ldi     0                  ; no flags for open
           plo     r7

           ldn     ra                 ; are we at end of string
           lbnz    nextname

           ldi     high default       ; load pointer to default
           phi     ra                 ;  filename list
           ldi     low default
           plo     ra


           ; Process next filename. When o_open fails to open a file, it 
           ; loops back to here to search for next in list.

nextname:  lda     ra                 ; skip any spaces before name
           lbnz    notatend

           glo     rb                 ; only output if verbose set
           lbz     return

           sep     scall              ; reached the end of the list
           dw      o_inmsg
           db      'ERROR: Config file was not found',13,10,0
           sep     sret

notatend:  smi     '!'                ; skip any whitespace
           lbnf    nextname

           dec     ra                 ; under the inc of lda

markname:  glo     ra                 ; save pointer to start of name
           plo     rf                 ;  for o_open to use
           ghi     ra
           phi     rf

skipchar:  inc     ra                 ; advance to end or to space
           ldn     ra 
           lbz     openfile
           smi     '!'
           lbdf    skipchar

           ldi     0                  ; overwrite separating space with
           str     ra                 ;  null to terminate name
           inc     ra

openfile:  sep     scall              ; try to open this file
           dw      o_open

           lbdf    nextname           ; if unsuccessful, try next one


           ; Allocate memory from the heap for the resident part of init
           ; that runs the child processes. Address of block to copy that
           ; code into will be left in RF.

           ldi     high modend-module  ; size of permanent code module
           phi     rc
           ldi     low modend-module
           plo     rc

           ldi     255                 ; request page-aligned block
           phi     r7
           ldi     4
           plo     r7

           sep     scall               ; allocate block on heap
           dw      o_alloc

           lbnf    copycode            ; allocation succeeded, copy code

memerror:  glo     rb                  ; only output error if verbose set
           lbz     closeit

           sep     scall               ; if unable to get memory
           dw      o_inmsg
           db      'ERROR: Not enough memory available to load',13,10,0

closeit:   sep     scall               ; close input file
           dw      o_close
           sep     sret                ; return to elf/os


           ; Copy the code of the resident part of init to the memory block
           ; that was just allocated using RF for destination.

copycode:  ghi     rf                  ; save a copy of block pointer
           phi     ra
           glo     rf
           plo     ra

           ldi     high modend-module  ; get length of code to copy
           phi     rc
           ldi     low modend-module
           plo     rc

           ldi     high module         ; get source address to copy from
           phi     r7
           ldi     low module
           plo     r7

copyloop:  lda     r7                  ; copy code to destination address
           str     rf
           inc     rf
           dec     rc
           glo     rc
           lbnz    copyloop
           ghi     rc
           lbnz    copyloop


           ; Get size of the input file by seeking to end of file, which
           ; return the length as the new seek offset.

           ldi     0                   ; load zero to offset
           phi     r8
           plo     r8
           phi     r7
           plo     r7

           ldi     2                   ; seek relative to end
           plo     rc

           sep     scall               ; seek to end of file
           dw      o_seek

           ghi     r8                  ; if 64K or larger then impossible
           lbnz    memerror
           glo     r8
           lbnz    memerror


           ; Allocate a block of memory that is the size of the configuration
           ; file plus one byte to zero terminate it.

           ldi     55
           plo     r7

           ghi     r7                  ; get size of file for heap
           phi     rc                  ;  block request
           glo     r7
           plo     rc

           inc     rc                  ; one more for terminating null

           ldi     0                   ; no alignment needed
           phi     r7
           ldi     4
           plo     r7

           sep     scall               ; make allocation on heap,
           dw      o_alloc             ;  fail if can't be satisfied

           lbdf    memerror


           ; Seek to beginning of file and then read it into the heap
           ; block that was permanently allocated for it.

           ldi     0                   ; set offset to zero
           phi     r8
           plo     r8
           phi     r7
           plo     r7

           plo     rc                  ; from start of file

           sep     scall               ; seek to start
           dw      o_seek

           ghi     rf                  ; save copy of start of block
           phi     r9
           glo     rf
           plo     r9

           ldi     255                 ; read until end of file
           plo     rc
           phi     rc

           sep     scall               ; read from file
           dw      o_read

           ldi     0                   ; zero terminate input file
           str     rf

           sep     scall               ; close file when done
           dw      o_close


           ; Store address of data block into both dataptr and datablk.
           ; The dataptr copy points to the next line to be processed,
           ; the datablk copy always points to the beginning to use to
           ; deallocate the block when we are done.

           ghi     ra                  ; page address of module
           phi     rd

           ldi     low dataptr         ; point to dataptr
           plo     rd

           ghi     r9                  ; update dataptr
           str     rd
           inc     rd
           glo     r9
           str     rd

           ldi     low datablk         ; point to datablk
           plo     rd

           ghi     r9                  ; update datablk
           str     rd
           inc     rd
           glo     r9
           str     rd


           ; Hook the o_wrmboot vector so that we can cleanup our memory
           ; blocks if a program exits this way. Save the original value
           ; so we can jump to it to return, and to restore it at end.

           ldi     high o_wrmboot      ; get pointer to o_wrmboot
           phi     rb
           ldi     low o_wrmboot
           plo     rb

           inc     rb                  ; skip lbr opcode

           ldi     low wrmboot         ; move pointer to wrmboot variable
           plo     rd

           lda     rb                  ; copy o_wrmboot vector to wrmboot
           str     rd
           inc     rd
           ldn     rb
           str     rd

           ldi     low badexit         ; update o_wrmboot to point to badexit
           str     rb
           dec     rb
           ghi     ra
           str     rb


           ; Jump to the persistent code that has been copied into high
           ; memory. Since this address is in a register and not known, do
           ; the jump by switching P=F, then loading R3 and switching back.

           ldi     high jumpblck      ; temporarily switch pc to rf so we
           phi     rf                 ;  can load r3 for a jump
           ldi     low jumpblck
           plo     rf
           sep     rf

jumpblck:  ghi     ra                 ; load r3 with code block address
           phi     r3                 ;  and switch pc back to r3 to jump
           glo     ra
           plo     r3
           sep     r3


           ; Start the persistent module code on a new page so that it forms
           ; a block of page-relocatable code that will be copied to himem.

           org     (($ + 0ffh) & 0ff00h)

module:    ; Memory-resident module code starts here


           ; This processes the input file which has been read into memory
           ; one line at a time, executing each line as a command line
           ; including any arguments provided. This looks in the current
           ; directory and then in bin directory if not found.

           ; From here is where we repeatedly loop back for input lines and
           ; process each as a command line.

getline:   ghi     r3                  ; get a pointer to dataptr
           phi     rd 
           ldi     low dataptr
           plo     rd

           lda     rd                  ; get pointer into command file
           phi     rf
           ldn     rd
           plo     rf

skipspc:   lda     rf                  ; skip any leading whitespace
           bz      endfile
           smi     '!'
           bnf     skipspc

           dec     rf                  ; back up because of lda above

           ghi     rf                  ; make copy of pointer to continue
           phi     r9                  ;  scanning for end with
           glo     rf
           plo     r9

scanline:  lda     r9                  ; skip to first control character
           bz      endfile
           smi     ' '
           bdf     scanline

           dec     r9                  ; back up to first control character
           ldi     0                   ;  and overwrite with zero byte, then
           str     r9                  ;  advance again
           inc     r9

           glo     r9                  ; update pointer in memory so we can
           str     rd                  ;  retreive again at top of loop
           dec     rd                  ;  since exec wipes out registers
           ghi     r9
           str     rd
           dec     rd


           ; Try calling o_exec on the original command line

           glo     rf                  ; save pointer to command line
           str     rd
           dec     rd
           ghi     rf
           str     rd

           sep     scall               ; try executing it
           dw      o_exec

           bnf     execyes             ; if plain exec was good


           ; If the exec failed, try again with o_execbin, which needs RF
           ; reset to the beginning of the line because o_exec changed it,
           ; also RA needs to be the value that o_exec left when it failed.

           ghi     r3                  ; get pointer to lineptr
           phi     rd
           ldi     low lineptr
           plo     rd

           lda     rd                  ; get value of lineptr pointer
           phi     rf
           ldn     rd
           plo     rf

           sep     scall               ; try executing it
           dw      o_execbin

           bdf     getline             ; if second try failed just skip

execyes:   sep     scall               ; output a blank line if succeeded
           dw      o_inmsg
           db      10,13,0

           br      getline             ; go process next line


           ; We hook o_wrmboot so that we can clean up our memory block
           ; if a program exits that way. This is much easier than trying
           ; to properly resume because to just do this it doesn't matter
           ; if the kernel has reset the stack pointer and destroyed our
           ; return chain (or if the program has), so at least do this much.
           ;
           ; Also outputs a message so the users knows why init exited!
           ;
           ; What we do here is a little tricky... we setup R6 and the word
           ; on top of the stack (which isn't really that relevant) to look
           ; like o_wrmboot used SCALL to get to us instead of LBR. This
           ; lets us use the same exit mechanism at the end either way.

badexit:   sep     scall               ; let user know why
           dw      o_inmsg
           db      'ERROR: Init terminated by warm boot',13,10,0

           glo     r6                  ; push current value of r6
           stxd
           ghi     r6
           stxd

           ldi     high o_wrmboot      ; set o_wrmboot as the return address
           phi     r6
           ldi     low o_wrmboot
           plo     r6


           ; Restore original o_wrmboot vector and clean up our two remaining
           ; data blocks. The block we use for a copy of the command line
           ; was only a temporary block so it will get cleaned by the kernel.

endfile:   ghi     r3                  ; get pointer to saved wrmboot
           phi     rd
           ldi     low wrmboot
           plo     rd

           ldi     high o_wrmboot      ; get pointer to o_wrmboot vector
           phi     rf
           ldi     low o_wrmboot
           plo     rf

           inc     rf                  ; skip lbr instruction

           lda     rd                  ; get saved wrmboot address and
           str     rf                  ;  restore back into o_wrmboot
           inc     rf
           ldn     rd
           str     rf

           ldi     low datablk         ; repoint to datablk address
           plo     rd

           lda     rd                  ; get address of datablk block
           phi     rf
           ldn     rd
           plo     rf

           sep     scall               ; deallocate it
           dw      o_dealloc

           ghi     r3                  ; get pointer to block we are in
           phi     rf
           ldi     low module
           plo     rf


           ; This is a little tricky too... how do you safely delete the
           ; memory block you are executing from? What we do here is jump
           ; to o_dealloc and it runs as though it was code inline to us
           ; and the SRET at its end is just the same as if we did SRET.

           lbr     o_dealloc           ; deallocate it and sret

           ; The above is not really strictly necessary since deleting the
           ; block in itself doesn't overwrite the memory that was in it,
           ; but this way makes less assumptions about the internal working
           ; of the heap manager by not relying on that current fact.


           ; Variables that the resident module needs

lineptr:   dw      0                   ; pointer to current command line
dataptr:   dw      0                   ; pointer to next line of input
datablk:   dw      0                   ; pointer to block with input file
wrmboot:   dw      0                   ; saved original o_wrmboot vector


modend:    ; End load the resident module code


           ; Default list of filenames to search for

default:   db      '/cfg/init.rc init.rc',0


           ; Include file descriptor in program image so it is initialized.

fd:        db      0,0,0,0             ; file descriptor
           dw      dta
           db      0,0
           db      0
           db      0,0,0,0
           db      0,0
           db      0,0,0,0

dta:       ds      512                 ; space for dta


end:       ; Last address used at all by the program. This will be set in 
           ; the header for the executable length so that lowmem gets set
           ; here to prevent collision with static data.

