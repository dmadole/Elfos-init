This program for Elf/OS accepts a list of filenames as arguments, and looks for the first file in the list that exists. If a file is found, it is opened and treated as a series of commands (which can also have arguments), one per line, which are then run sequentially. 

The intent is to use this as an init program to allow multiple other programs to be run at boot time to setup the system. To use for this purpose, install as init in the /bin/ directory. When run with no arguments, at it will be at boot time, it will look for "/cfg/init.rc" or "init.rc" as the input file.

For example, to load all of nitro, turbo, and hydro at boot time, create a text file named /cfg/init.rc that contains the following:

nitro  
turbo  
hydro  

Builds 6 and later are only compatible with Elf/OS kernel 0.4.0 and later and use the new heap manager to allocate memory and manage memory allocated by progams it invokes. This program also no longer interferes with other programs that are written to warm boot the operating system. When a program does so, however, that will forcably terminate init and remove it from memory, so any further programs specified in the input file will not be able to be executed.

Builds 4 and 5 were special interim releases that made minimal changes to work with kernel 0.4.0 but do not take advantage of the memory manager feature. As such, they have the potential to conflict with heap or program memory usage and so their use is no longer recommended or supported.

Note that when Elf/OS finds an init program, it does not detect baud rate at startup like it normally does. This means that that either the first command in the input file should set the baud rate, or the baud rate should already be set before Elf/OS is booted. The former can be accomplished by using nitro as the first command, the latter will be accomplished if using a normal BIOS ROM that detects baud rate before loading Elf/OS.

Lastly, if EF4 is asserted, then this program acts as though it was not found, which is to say, it will call the normal BIOS routine to set the baud rate and then exit. This can be used to help recover from an error in the input file. On classic Elf machines, EF4 is asserted by holding down the INPUT button.

