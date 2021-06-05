This program for Elf/OS accepts a list of filenames as arguments, and looks for the first file in the list that exists. If a file is found, it is opened and treated as a series of commands (which can also have arguments), one per line, which are then run sequentially. 

The intent is to use this as an INIT program to allow multiple other programs to be run at boot time to setup the system. To use for this purpose, install as INIT in the root directory. When run with no arguments, at it will be at boot time, it will look for "init.rc" or "INIT.rc" as the input files.

For example, to load all of nitro, turbo, and hydro at boot time, create a text file named INIT.rc that contains the following:

nitro<br>
turbo<br>
hydro<br>

Due to some constraints of Elf/OS and it's intended use, there are some limitations. This program loads into memory at $5000 which means it cannot run a program that needs more than 12K of memory. Likewise, a programs that allocates from himem cannot allocate more than about 12K of memory in total.

Note that when Elf/OS finds an INIT program, it does not detect baud rate at startup like it normally does. This means that that either the first command in the input file should set the baud rate, or the baud rate should already be set before Elf/OS is booted. The former can be accomplished by using nitro as the first command, the latter will be accomplished if using a normal BIOS ROM that detects baud rate before loading Elf/OS.

Lastly, if EF4 is asserted, then this program acts as though it was not found, which is to say, it will call the normal BIOS routine to set the baud rate and then exit. This can be used to help recover from an error in the input file. On classic Elf machines, EF4 is asserted by holding down the INPUT button.

