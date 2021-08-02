
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


           ; Non-published kernel interfaces

d_reapheap equ 044dh


           ; Executable program header

           org     2000h - 6
           dw      start
           dw      end-start
           dw      start


start:     org     2000h
           br      main


           ; Build information

           db      8+80h              ; month
           db      2                  ; day
           dw      2021               ; year
           dw      6                  ; build
text:      db      'See github.com/dmadole/Elfos-init for more info',0


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
           ; code into will be leftin RF.

           ldi     high modend-module  ; size of permanent code module
           phi     rc
           ldi     low modend-module
           plo     rc

           ldi     255                 ; request page-aligned block
           phi     r7
           ldi     0
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
           ;  that was just allocated using RF for destination.

copycode:  ghi     rf                  ; save a copy of block pointer
           phi     ra
           glo     rf
           plo     ra

           ldi     high module         ; get source address to copy from
           phi     r7
           ldi     low module
           plo     r7

           ldi     high modend-module  ; get length of code to copy
           phi     rc
           ldi     low modend-module
           plo     rc

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

           ghi     r7                  ; get size of file for heap
           phi     rc                  ;  block request
           glo     r7
           plo     rc

           inc     rc                  ; one more for terminating null

           ldi     0                   ; no alignment needed
           phi     r7
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
           phi     rc
           plo     rc

           sep     scall               ; read from file
           dw      o_read

           ldi     0                   ; zero terminate input file
           str     rf

           sep     scall               ; close file when done
           dw      o_close


           ; Setup RF to point to input configuration in memory, and also
           ; push a copy to the stack that will be used to reference the
           ; block in the module to make it temporarily permanent so it
           ; doesn't get purged by d_reapheap.

           glo     r9                 ; save start of buffer, to stack
           plo     rf
           stxd                       ;  stack to use to delete at exit
           ghi     r9
           phi     rf
           stxd


           ; Jump to the persistent code that has been copied into high
           ; memory. Since this address is in a register and not known, do
           ; the jump by switching to RD, then loading R3 and switching back.

           ldi     high jumpblck      ; temporarily switch pc to rd so we
           phi     rd                 ;  can load r3 for a jump
           ldi     low jumpblck
           plo     rd
           sep     rd

jumpblck:  ghi     ra                 ; load r3 with code block address
           phi     r3                 ;  and switch pc back to r3 to jump
           glo     ra
           plo     r3
           sep     r3


;-------------------------------------------------------------------------

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

getline:   lda     rf                 ; skip any leading whitespace
           bz      endfile
           smi     '!'
           bnf     getline

           dec     rf                 ; back up because of lda above

           ghi     rf                 ; make three copies of pointer to
           phi     r9                 ;  command line for various copying
           phi     ra
           phi     rb
           glo     rf
           plo     r9
           plo     ra
           plo     rb

scanline:  lda     ra                 ; skip to first control character
           bz      endfile
           smi     ' '
           bdf     scanline

           dec     ra                 ; back up to first control character
           ldi     0                  ;  and overwrite with zero byte, then
           str     ra                 ;  advance again
           inc     ra

           ; Count length of command line string so we can copy it

           ldi     0                  ; prepare to count string length,
           phi     rc                 ;  start with length of /bin/
           ldi     5
           plo     rc

strlen:    lda     rf                 ; get length of command line
           inc     rc                 ;  including terminating null
           bnz     strlen

           ; Allocate block on heap for copy of string

           ldi     0                  ; no alignment needed, and only
           phi     r7                 ;  temporary block
           plo     r7

           sep     scall              ; get block, if fails, treat as eof
           dw      o_alloc

           bdf     endfile

           ; Save pointers that we will need preserved across o_exec

           glo     ra                 ; point to restart command scanning
           stxd
           ghi     ra
           stxd

           glo     rf                 ; pointer to /bin/ prefixed string
           stxd
           ghi     rf
           stxd

           ; Concatenate /bin/ + command into allocated block

           ghi     r3                 ; get pointer to /bin/ string
           phi     ra
           ldi     low binpath
           plo     ra

strcpy:    lda     ra                 ; copy into start of the block
           str     rf
           inc     rf
           bnz     strcpy

           dec     rf                 ; backup to terminating null

strcat:    lda     rb                 ; concatenate the command
           str     rf
           inc     rf
           bnz     strcat

           ; Try calling o_exec on the original command line

           ghi     r9                 ; get pointer to command line
           phi     rf
           glo     r9
           plo     rf

           sep     scall              ; try executing it
           dw      o_exec

           inc     r2                 ; pop pointer to the /bin/ prefixed
           lda     r2                 ;  string here to clear from stack
           phi     rf
           ldn     r2
           plo     rf

           bnf     execgood           ; if plain exec was good

           sep     scall              ; try executing it
           dw      o_exec

           bdf     execfail           ; if second try failed also

execgood:  sep     scall              ; output a blank line if succeeded
           dw      o_inmsg
           db      10,13,0

           ; Get ready for next loop around

execfail:  inc     r2                 ; restore input pointer from stack
           lda     r2                 ;  to restart line scanning from
           phi     ra
           ldn     r2
           plo     ra
           
           ; Clean up heap from exec'ed program. This marks the two blocks
           ; we use as permanent before calling reapheap so that they don't
           ; get removed, then unmarks them after. This is done this way
           ; so that the blocks are not marked permanent when the child
           ; program is so that they will get cleaned up in case the
           ; child process does not return to us, so they are not abandoned.

           inc     r2                 ; get pointer to data input block
           lda     r2                 ;  so we can mark it permanent
           phi     rb
           ldn     r2
           plo     rb

           dec     r2                 ; push pointer back on stack so
           ghi     rb                 ;  we can pop it again next time
           stxd
           
           ghi     r3                 ; get pointer to code block
           phi     rc
           ldi     low module
           plo     rc

           dec     rb                 ; move to header and mark permanent
           dec     rb
           dec     rb
           ldn     rb
           ori     4
           str     rb

           dec     rc                 ; move to header and mark permanent
           dec     rc
           dec     rc
           ldn     rc
           ori     4
           str     rc

           sep     scall              ; clean heap of temporary blocks
           dw      d_reapheap

           ldn     rb                 ; unmark permanent
           xri     4
           str     rb

           ldn     rc                 ; unmark permanent
           xri     4
           str     rc

           ghi     ra                 ; when this was written, o_reapheap
           phi     rf                 ;  destroys rf, otherwise this would
           glo     ra                 ;  have gone directly into rf
           plo     rf

           br      getline            ; go find next line to process


           ; At end of file (or an unlikely out of memory condition),
           ; just drop up the data block pointer on the stack and
           ; return. Since the heap blocks we allocated are marked
           ; temporary, they will be cleaned up by Elf/OS.

endfile:   inc     r2                 ; remove pointer to data block
           inc     r2

           sep     sret               ; return to caller


           ; This buffer with prepended /bin/ is used to build a copy of
           ; the command line to look in bin directory if not found in cwd.

binpath:   db      '/bin/',0          ; for prefixing command line
datafile:  dw      0

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

