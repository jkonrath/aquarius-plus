;-----------------------------------------------------------------------------
; Aquarius+ system ROM
;-----------------------------------------------------------------------------
; By Frank van den Hoef
;
; Based on AQUBASIC source code by Bruce Abbott:
; http://bhabbott.net.nz/micro_expander.html
;
; Useful links:
; - Excellent Aquarius S2 ROM disassembly by Curtis F Kaylor:
; https://github.com/RevCurtisP/Aquarius/blob/main/disassembly/aquarius-rom.lst
;
;-----------------------------------------------------------------------------

;-----------------------------------------------------------------------------
; Extra BASIC commands
;-----------------------------------------------------------------------------
; CLS    - Clear screen
; LOCATE - Position on screen
; SCR    - Scroll screen
; OUT    - Output data to I/O port
; PSG    - Program PSG register, value
; CALL   - Call machine code subroutine
; LOAD   - Load file from USB disk
; SAVE   - Save file to USB disk
; DIR    - Display USB disk directory with wildcard
; CD     - Change directory
; DEL    - Delete file

;-----------------------------------------------------------------------------
; Extra BASIC functions
;-----------------------------------------------------------------------------
; IN()   - Get data from I/O port
; JOY()  - Read joystick
; HEX$() - Convert number to hexadecimal string

;-----------------------------------------------------------------------------
; System Variables
;-----------------------------------------------------------------------------
; Name   Location  Alt name  Description
CURCOL   = $3800 ; TTYPOS    Current cursor column
CURRAM   = $3801 ; CHRPOS    Position in CHARACTER RAM of cursor
USRJMP   = $3803 ; USRGO     JMP instruction for USR.
USRADDR  = $3804 ; USRAL     Address of USR() function
;          $3805 ; USRAH     "
UDFADDR  = $3806 ; HOKDSP    RST $30 vector, hooks into various system routines
;          $3807 ;
LISTCNT  = $3808 ; ROWCOUNT  Counter for lines listed (pause every 23 lines)
LASTFF   = $3809 ; PTOLD     Last protection code sent to port($FF)
LSTASCI  = $380A ; CHARQ     ASCII value of last key pressed.
KWADDR   = $380B ; SKEY      Address of keyword in the keyword table.
;          $380C ;           "
CURHOLD  = $380D ; BUFO      Holds character under the cursor.
LASTKEY  = $380E ;           SCAN CODE of last key pressed
SCANCNT  = $380F ;           Number of SCANS key has been down for
FDIV     = $3810 ;           Subroutine for division ???
                 ;
RANDOM   = $381F ;           Used by random number generator
                 ;
LPTLST   = $3845 ;           Last printer operation status
PRNCOL   = $3846 ; LPTPOS    The current printer column (0-131).
CHANNEL  = $3847 ; PRTFLG    Channel: 0=screen, 1=printer.
LINLEN   = $3848 ;           Line length (initially set to 40 ???)
CLMLST   = $3849 ;           Position of last comma column
RUBSW    = $384A ;           Rubout switch
STKTOP   = $384B ;           High address of stack. followed by string storage space
                 ;
CURLIN   = $384D ;           Current BASIC line number (-1 in direct mode)
                 ;
BASTART  = $384F ; TXTTAB    Pointer to start of BASIC program
                 ;
CASNAM   = $3851 ;           Tape filename (6 chars)
CASNM2   = $3857 ;           Tape read filename (6 chars)
CASFL2   = $385D ;           Tape flag
CASFL3   = $385E ;           Tape flag (break key check)
BUFMIN   = $385F ;           Buffer used by INPUT statement
LINBUF   = $3860 ; BUF       Line input buffer (73 bytes).
                 ;
BUFEND   = $38A9 ;           end of line unput buffer
DIMFLG   = $38AA ;           dimension flag 1 = array
VALTYP   = $38AB ;           type: 0 = number, 1 = string
DORES    = $38AC ;           flag for crunch
RAMTOP   = $38AD ; MEMSIZ    Address of top of physical RAM.
;          $38AE ;
STRBUF   = $38AF ;           18 bytes used by string functions
                 ;
FRETOP   = $38C1 ;           Pointer to top of string space
;          $38C2 ;
SYSTEMP  = $38C3 ; TEMP      Temp space used by FOR etc.
                 ;
DATLIN   = $38C9 ;           Address of current DATA line
;          $38CA ;
FORFLG   = $38CB ;           Flag FOR:, GETVAR: 0=variable, 1=array
                 ;      
TMPSTAT  = $38CE ;           Temp holder of next statement address
                 ;
CONTLIN  = $38D2 ;           Line number to CONTinue from.
CONTPOS  = $38D4 ;           Address of line to CONTinue from.
BASEND   = $38D6 ; VARTAB    Variable table (end of BASIC program)
                 ;
ARYTAB   = $38D8 ;           Start of array table
                 ;
ARYEND   = $38DA ;           End of array table
                 ;
RESTORE  = $38DC ;           Address of line last RESTORE'd
                 ;
;          $38DE ;           Pointer and flag for arrays
                 ;
FPREG    = $38E4 ; FPNUM     Floating point number
                 ;
FPSTR    = $38E9 ;           Floating point string
                 ;
;          $38F9 ;           Used by keyboard routine
                 ;
PROGST   = $3900 ;           NULL before start of BASIC program

; end of system variables = start of BASIC program in stock Aquarius
;          $3901 ; 14593

; buffer lengths
LINBUFLEN   = DIMFLG - LINBUF
STRBUFLEN   = FRETOP - STRBUF
SYSTEMPLEN  = DATLIN - SYSTEMP
TMPSTATLEN  = CONTLIN - TMPSTAT
FPREGLEN    = FPSTR - FPREG
FPSTRLEN    = $38F9 - FPSTR

;-----------------------------------------------------------------------------
; System routines
;-----------------------------------------------------------------------------
PRNCHR      = $1D94  ; Print character in A
PRNCHR1     = $1D72  ; Print character in A with pause/break at end of page
PRNCRLF     = $19EA  ; Print CR+LF
PRINTSTR    = $0E9D  ; Print null-terminated string
SCROLLUP    = $1DFE  ; Scroll the screen up 1 line
EVAL        = $0985  ; Evaluate expression
EVLPAR      = $0A37  ; Evaluate expression in brackets
GETINT      = $0B54  ; Evaluate numeric expression (integer 0-255)
GETNUM      = $0972  ; Evaluate numeric expression
PUTVAR8     = $0B36  ; Store variable 8 bit (out: B = value)
GETVAR      = $10D1  ; Get variable (out: BC = addr, DE = len)
GETLEN      = $0FF7  ; Get string length (in: (FPREG) = string block, out: HL = string block, A = length)
TSTNUM      = $0975  ; Error if evaluated expression not a number
TSTSTR      = $0976  ; Error if evaluated expression not string
DEINT       = $0682  ; Convert fp number to 16 bit signed integer in DE
INT2STR     = $1679  ; Convert 16 bit integer in HL to text at FPSTR (starts with ' ')

FINLPT = $19BE
CRDONZ = $19DE
READY = $0402

ERROR_FC    = $0697  ; Function code error
DO_ERROR    = $03DB  ; Process error code, E = code (offset to 2 char error name)

STKINI = $0BE5
WRMCON = $1A40
TTYCHR = $1D72

;----------------------------------------------------------------------------
;                         BASIC Error Codes
;----------------------------------------------------------------------------
; code is offset to error name (2 characters)
;
;name        code            description
FC_ERR  =    $08             ; Function Call error

; alternative system variable names
VARTAB      = BASEND     ; $38D6 variables table (at end of BASIC program)

PathSize = 37

PathName = $BFC8    ; (37 chars) file path eg. "/root/subdir1/subdir2",0
FileName = $BFED    ; USB file name 1-11 chars + '.', NULL
FileType = $BFFA    ; file type BASIC/array/binary/etc.
BinStart = $BFFB    ; binary file load/save address
BinLen   = $BFFD    ; 16-bit binary file length
DosFlags = $BFFF
RAMEND   = $C000    ; we are in ROM, 32k expansion RAM available

SysVars = PathName

; system flags
SF_RETYP = 1       ; 1 = CTRL-O is retype

;=================================================================
;                     AquBASIC BOOT ROM
;=================================================================
    org $2000
    jp _coldboot    ; Called from main ROM for cold boot
    jp _warmboot    ; Called from main ROM for warm boot

;-----------------------------------------------------------------------------
; Warm boot entry point (CTRL-C pressed in boot menu)
;-----------------------------------------------------------------------------
_warmboot:
    call    usb_init

    ; Clear screen
    ld      a, $0b
    call    TTYCHR

    ; Continue in ROM code
    jp      $00F2

;-----------------------------------------------------------------------------
; Cold boot entry point
;-----------------------------------------------------------------------------
_coldboot:
    call    usb_init

    ; Test the memory (only testing 1st byte in each 256 byte page!)
    ld      hl, $3A00           ; First page of free RAM
    ld      a, $55              ; Pattern = 01010101
.memtest:
    ld      c, (hl)             ; Save original RAM contents in C
    ld      (hl), a             ; Write pattern
    cp      (hl)                ; Compare read to write
    jr      nz, .memready       ; If not equal then end of RAM
    cpl                         ; Invert pattern
    ld      (hl), a             ; Write inverted pattern
    cp      (hl)                ; Compare read to write
    jr      nz, .memready       ; If not equal then end of RAM
    ld      (hl), c             ; Restore original RAM contents
    cpl                         ; Uninvert pattern
    inc     h                   ; Advance to next page
    jr      nz, .memtest        ; Continue testing RAM until end of memory
.memready:

    ; Check that we have enough RAM
    ld      a, h
    cp      $C0                 ; 32k expansion
    jp      c, $0BB7            ; OM error if expansion RAM missing
    dec     hl                  ; Last good RAM addresss
    ld      hl, SysVars - 1     ; Top of public RAM

    ; Set memory size
    ld      (RAMTOP), hl        ; MEMSIZ, Contains the highest RAM location
    ld      de, -50             ; Subtract 50 for strings space
    add     hl, de
    ld      (STKTOP), hl        ; STKTOP, Top location to be used for stack
    ld      hl, PROGST
    ld      (hl), $00           ; NULL at start of BASIC program
    inc     hl
    ld      (BASTART), hl       ; Beginning of BASIC program text
    call    $0BBE               ; ST_NEW2 - NEW without syntax check

    ; Install BASIC HOOK
    ld      hl, udf_handler     ; RST $30 Vector (our UDF service routine)
    ld      (UDFADDR), hl       ; store in UDF vector

    ; Show our copyright message
    call    $1FF2               ; Print copyright string in ROM
    ld      hl, .str_basic      ; "USB BASIC"
    call    PRINTSTR

    jp      $0153               ; Continue in ROM

.str_basic:
    db      $0D, $0A, "Aquarius+ System ROM V1.0", $0D, $0A, $0D, $0A, 0

;-----------------------------------------------------------------------------
; USB Disk Driver
;-----------------------------------------------------------------------------
    include "ch376.asm"

;-----------------------------------------------------------------------------
; UDF Hook Service Routine
;
; This address is stored at $3806-7, and is called by every RST $30.
; It allows us to hook into the system ROM in several places (anywhere a 
; RST $30 is located).
;-----------------------------------------------------------------------------
udf_handler:
    ex      (sp), hl            ; Save HL and get address of byte after RST $30
    push    af                  ; Save AF
    ld      a, (hl)             ; A = byte (RST $30 parameter)
    inc     hl                  ; Skip over byte after RST $30
    push    hl                  ; Push return address (code after RST $30,xx)

    ld      hl, _udf_list       ; HL = RST 30 parameter table
    push    bc
    ld      bc, _udf_jmp - _udf_list + 1 ; Number of UDF parameters
    cpir                        ; Find parameter in list
    ld      a, c                ; A = parameter number in list
    pop     bc
    add     a, a                ; A * 2 to index WORD size vectors
    ld      hl, _udf_jmp        ; HL = Jump vector table
do_jump:
    add     a, l
    ld      l, a
    xor     a
    adc     a, h
    ld      h, a                ; HL += vector number
    ld      a, (hl)
    inc     hl
    ld      h, (hl)             ; Get vector address
    ld      l, a
    jp      (hl)                ; And jump to it will return to udf_exit

; End of UDF handler
udf_exit:
    pop     hl                  ; Get return address
    pop     af                  ; Restore AF
    ex      (sp), hl            ; Restore HL and set return address
    ret                         ; Return to code after RST $30,xx

; UDF parameter table
; List of RST $30,xx hooks that we are monitoring.
; NOTE: order is reverse of UDF jumps!
_udf_list:  ; xx      index caller            @addr  performing function:
    db      24      ; 5   RUN                 $06BE  starting BASIC program
    db      23      ; 4   exec_next_statement $0658  interpreting next BASIC statement
    db      22      ; 3   token_to_keyword    $05A0  expanding token to keyword
    db      10      ; 2   keyword_to_token    $0536  converting keyword to token
    db      27      ; 1   FUNCTIONS           $0A5F  executing a function

; UDF parameter Jump table
_udf_jmp:
    dw      udf_exit            ; 0 parameter not found in list
    dw      execute_function    ; 1 executing a function
    dw      keyword_to_token    ; 2 converting keyword to token
    dw      token_to_keyword    ; 3 expanding token to keyword
    dw      exec_next_statement ; 4 execute next BASIC statement
    dw      run_cmd             ; 5 run program

;-----------------------------------------------------------------------------
; Our commands and functions
;-----------------------------------------------------------------------------
BTOKEN:     equ $D4             ; Our first token number

TBLCMDS:
    db $80 + 'E', "DIT"
    db $80 + 'C', "LS"
    db $80 + 'L', "OCATE"
    db $80 + 'O', "UT"
    db $80 + 'P', "SG"
    db $80 + 'D', "EBUG"
    db $80 + 'C', "ALL"
    db $80 + 'L', "OAD"
    db $80 + 'S', "AVE"
    db $80 + 'D', "IR"
    db $80 + 'C', "AT"
    db $80 + 'D', "EL"
    db $80 + 'C', "D"

    ; Functions
    db $80 + 'I', "N"
    db $80 + 'J', "OY"
    db $80 + 'H', "EX$"
    db $80             ; End of table marker

TBLJMPS:
    dw ST_reserved     ; Previously EDIT
    dw ST_CLS
    dw ST_LOCATE
    dw ST_OUT
    dw ST_PSG
    dw ST_reserved     ; Previously DEBUG
    dw ST_CALL
    dw ST_LOAD
    dw ST_SAVE
    dw ST_DIR
    dw ST_reserved
    dw ST_DEL          ; Previously KILL
    dw ST_CD
TBLJEND:

BCOUNT: equ (TBLJEND - TBLJMPS) / 2     ; Number of commands

TBLFNJP:
    dw      FN_IN
    dw      FN_JOY
    dw      FN_HEX
TBLFEND:

FCOUNT: equ (TBLFEND - TBLFNJP) / 2  ; Number of functions

firstf: equ BTOKEN + BCOUNT          ; Token number of first function in table
lastf:  equ firstf + FCOUNT - 1      ; Token number of last function in table

;-----------------------------------------------------------------------------
; BASIC Function handler
;-----------------------------------------------------------------------------
; called from $0a5f by RST $30,$1b
;
execute_function:
    pop     bc                  ; Get return address
    pop     af
    pop     hl
    push    bc                  ; Push return address back on stack
    cp      (firstf - $B2)      ; ($B2 = first system BASIC function token)
    ret     c                   ; Return if function number below ours
    cp      (lastf - $B2 + 1)
    ret     nc                  ; Return if function number above ours
    sub     (firstf - $B2)
    add     a, a                ; Index = A * 2
    push    hl
    ld      hl, TBLFNJP         ; Function address table
    jp      do_jump             ; JP to our function

;-----------------------------------------------------------------------------
; Convert keyword to token
;-----------------------------------------------------------------------------
keyword_to_token:
    ld      a, b               ; A = current index

    cp      $CB                ; If < $CB then keyword was found in BASIC table
    jp      nz, udf_exit       ;    so return

    pop     bc                 ; Get return address from stack
    pop     af                 ; Restore AF
    pop     hl                 ; Restore HL
    push    bc                 ; Put return address back onto stack

    ; Set our own keyword table and let BASIC code use that instead
    ex      de, hl             ; HL = Line buffer
    ld      de, TBLCMDS - 1    ; DE = our keyword table
    ld      b, BTOKEN - 1      ; B = our first token
    jp      $04F9              ; Continue searching using our keyword table

;-----------------------------------------------------------------------------
; Convert token to keyword
;
; This function will check if the passed token is one of the stock BASIC or
; our extra commands. If it one of our commands, we pass our command table
; to the ROM code.
;-----------------------------------------------------------------------------
token_to_keyword:
    pop     de
    pop     af                  ; Restore AF (token)
    pop     hl                  ; Restore HL (BASIC text)
    cp      BTOKEN              ; Is it one of our tokens?
    jr      nc, .expand_token   ; Yes, expand it
    push    de
    ret                         ; No, return to system for expansion

.expand_token:
    sub     BTOKEN - 1
    ld      c, a                ; C = offset to AquBASIC command
    ld      de, TBLCMDS         ; DE = table of AquBASIC command names
    jp      $05A8               ; Print keyword indexed by C

;-----------------------------------------------------------------------------
; exec_next_statement
;-----------------------------------------------------------------------------
exec_next_statement:
    pop     bc                  ; BC = return address
    pop     af                  ; AF = token, flags
    pop     hl                  ; HL = text
    jr      nc, .process        ; if NC then process BASIC statement
    push    bc
    ret                         ; else return to system

.process:
    ; Check if the token is own of our own, otherwise give syntax error
    sub     (BTOKEN) - $80
    jp      c, $03C4            ; SN error if < our 1st BASIC command token
    cp      BCOUNT              ; Count number of commands
    jp      nc, $03C4           ; SN error if > out last BASIC command token

    ; Execute handler 
    rlca                        ; A*2 indexing WORDs
    ld      c, a
    ld      b, $00              ; BC = index
    ex      de, hl
    ld      hl, TBLJMPS         ; HL = our command jump table
    jp      $0665               ; Continue with exec_next_statement

;-----------------------------------------------------------------------------
; RUN command
;-----------------------------------------------------------------------------
run_cmd:
    pop     af                 ; Clean up stack
    pop     af                 ; Restore AF
    pop     hl                 ; Restore HL
    jp      z, $0BCB           ; If no argument then RUN from 1st line

    push    hl
    call    EVAL               ; Get argument type
    pop     hl

    ld      a, (VALTYP)
    dec     a                  ; 0 = string
    jr      z, .run_file

    ; RUN with line number
    call    $0BCF              ; Init BASIC run environment
    ld      bc, $062C
    jp      $06DB              ; GOTO line number

    ; RUN with string argument
.run_file:
    call    dos__getfilename   ; Convert filename, store in FileName
    push    hl                 ; Save BASIC text pointer

    ld      hl, FileName
    call    usb__open_read     ; Try to open file
    jr      z, .load_run
    cp      CH376_ERR_MISS_FILE ; error = file not found?
    jp      nz, .nofile        ; No, break

    ld      b, 9               ; Max 9 chars in name (including '.' or NULL)
.instr:
    ld      a,(hl)             ; get next name char
    inc     hl
    cp      '.'                ; if already has '.' then cannot extend
    jp      z, .nofile
    cp      ' '
    jr      z, .extend          ; until SPACE or NULL
    or      a
    jr      z, .extend
    djnz    .instr

.nofile:
    ld      hl, .nofile_msg
    call    PRINTSTR
    pop     hl                 ; Restore BASIC text pointer
.error:
    ld      e, FC_ERR          ; Function code error
    jp      DO_ERROR           ; Return to BASIC

.extend:
    dec     hl

    ; Try to open file appending .BAS extension
    push    hl                 ; Save extension address
    ld      de, .bas_extn
    call    strcat             ; Append ".BAS"
    ld      hl, FileName
    call    usb__open_read     ; Try to open file
    pop     hl                 ; Restore extension address
    jr      z, .load_run

    cp      CH376_ERR_MISS_FILE ; Error = file not found?
    jp      nz, .nofile         ; No, break

    ; Try to open file appending .BIN extension
    ld      de, .bin_extn
    ld      (hl), 0            ; Remove extn
    call    strcat             ; Append ".BIN"

.load_run:
    pop     hl                 ; Restore BASIC text pointer
    call    ST_LOADFILE        ; Load file from disk, name in FileName
    jp      nz, .error         ; If load failed then return to command prompt
    cp      FT_BAS             ; Filetype is BASIC?
    jp      z, $0BCB           ; Yes, run loaded BASIC program

    cp      FT_BIN             ; BINARY?
    jp      nz, .done          ; No, return to command line prompt
    ld      de, .done
    push    de                 ; Set return address
    ld      de, (BINSTART)
    push    de                 ; Set jump address
    ret                        ; Jump into binary

.done:
    xor     a
    jp      READY

.bas_extn:   db ".BAS", 0
.bin_extn:   db ".BIN", 0
.nofile_msg: db "File not found", $0D, $0A, 0

;-----------------------------------------------------------------------------
; Not implemented statement - do nothing
;-----------------------------------------------------------------------------
ST_reserved:
    ret

;-----------------------------------------------------------------------------
; CLS statement
;-----------------------------------------------------------------------------
ST_CLS:
    ; Clear screen
    ld      a, $0b
    rst     $18
    ret

;-----------------------------------------------------------------------------
; OUT statement
; syntax: OUT port, data
;-----------------------------------------------------------------------------
ST_OUT:
    call    GETNUM              ; Get/evaluate port
    call    DEINT               ; Convert number to 16 bit integer (result in DE)
    push    de                  ; Stored to be used in BC

    ; Expect comma
    rst     $08                 ; Compare RAM byte with following byte
    db      ','                 ; Character ',' byte used by RST 08

    call    GETINT              ; Get/evaluate data
    pop     bc                  ; BC = port
    out     (c), a              ; Out data to port
    ret

;-----------------------------------------------------------------------------
; LOCATE statement
; Syntax: LOCATE col, row
;-----------------------------------------------------------------------------
ST_LOCATE:
    call    GETINT              ; Read number from command line (column). Stored in A and E
    push    af                  ; Column store on stack for later use
    dec     a
    cp      38                  ; Compare with 38 decimal (max cols on screen)
    jp      nc, ERROR_FC        ; If higher then 38 goto FC error

    ; Expect comma
    rst     $08                 ; Compare RAM byte with following byte
    db      ','                 ; Character ',' byte used by RST 08

    call    GETINT              ; Read number from command line (row). Stored in A and E
    cp      $18                 ; Compare with 24 decimal (max rows on screen)
    jp      nc,ERROR_FC         ; If higher then 24 goto FC error

    inc     e
    pop     af                  ; Restore column from store
    ld      d, a                ; Column in register D, row in register E
    ex      de, hl              ; Switch DE with HL
    call    .goto_hl            ; Cursor to screen location HL (H=col, L=row)
    ex      de, hl
    ret

.goto_hl:
    push    af

    ; Restore character behind cursor
    push    hl
    exx
    ld      hl, ($3801)         ; CHRPOS - address of cursor within matrix
    ld      a, ($380D)          ; BUFO - storage of the character behind the cursor
    ld      (hl), a             ; Put original character on screen
    pop     hl

    ; Calculate new cursor location
    ld      a, l
    add     a, a
    add     a, a
    add     a, l
    ex      de, hl
    ld      e, d
    ld      d, $00
    ld      h, d
    ld      l, a
    ld      a, e
    dec     a
    add     hl, hl
    add     hl, hl
    add     hl, hl              ; HL is now 40 * rows
    add     hl, de              ; Added the columns
    ld      de, $3000           ; Screen character-matrix (= 12288 dec)
    add     hl, de              ; Putting it al together
    jp      $1DE7               ; Save cursor position and return

;-----------------------------------------------------------------------------
; PSG statement
; syntax: PSG register, value [, ... ]
;-----------------------------------------------------------------------------
ST_PSG:
    cp      $00
    jp      z, $03D6         ; MO error if no args

.psgloop:
    ; Get PSG register to write to
    call    GETINT           ; Get/evaluate register
    out     ($F7), a         ; Set the PSG register

    ; Expect comma
    rst     $08              ; Next character must be ','
    db      ','              ; ','

    ; Get value to write to PSG register
    call    GETINT           ; Get/evaluate value
    out     ($F6), a         ; Send data to the selected PSG register
    ld      a, (hl)          ; Get next character on command line
    cp      ','              ; Compare with ','
    ret     nz               ; No comma = no more parameters -> return

    inc     hl               ; next character on command line
    jr      .psgloop         ; parse next register & value

;-----------------------------------------------------------------------------
; IN() function
; syntax: var = IN(port)
;-----------------------------------------------------------------------------
FN_IN:
    pop     hl
    inc     hl

    call    EVLPAR           ; Read number from line - ending with a ')'
    ex      (sp), hl
    ld      de, $0A49        ; Return address
    push    de               ; On stack
    call    DEINT            ; Evaluate formula pointed by HL, result in DE
    ld      b, d
    ld      c, e             ; BC = port

    ; Read from port
    in      a, (c)           ; A = in(port)
    jp      PUTVAR8          ; Return with 8 bit input value in variable var

;-----------------------------------------------------------------------------
; JOY() function
; syntax: var = JOY(stick)
;    stick - 0 will read left or right
;          - 1 will read left joystick only
;          - 2 will read right joystick only
;-----------------------------------------------------------------------------
FN_JOY:
    pop     hl             ; Return address
    inc     hl             ; skip rst parameter
    call    $0A37          ; Read number from line - ending with a ')'
    ex      (sp), hl
    ld      de, $0A49      ; set return address
    push    de
    call    DEINT          ; DEINT - evalute formula pointed by HL result in DE

    ld      a, e
    or      a
    jr      nz, .joy01
    ld      a, $03

.joy01:
    ld      e, a
    ld      bc, $00F7
    ld      a, $FF
    bit     0, e
    jr      z, .joy03
    ld      a, $0e
    out     (c), a
    dec     c
    ld      b, $FF

.joy02:
    in      a,(c)
    djnz    .joy02
    cp      $FF
    jr      nz, .joy05

.joy03:
    bit     1,e
    jr      z, .joy05
    ld      bc, $00F7
    ld      a, $0F
    out     (c), a
    dec     c
    ld      b, $FF

.joy04:
    in      a, (c)
    djnz    .joy04

.joy05:
    cpl
    jp      $0B36

;-----------------------------------------------------------------------------
; HEX$() function
; eg. A$=HEX$(B)
;-----------------------------------------------------------------------------
FN_HEX:
    pop     hl
    inc     hl
    call    EVLPAR          ; Evaluate parameter in brackets
    ex      (sp), hl
    ld      de, $0A49       ; Return address
    push    de              ; On stack
    call    DEINT           ; Evaluate formula @HL, result in DE
    ld      hl, $38E9       ; HL = temp string
    ld      a, d
    or      a               ; > zero ?
    jr      z, .lower_byte
    ld      a, d
    call    .hexbyte        ; Yes, convert byte in D to hex string
.lower_byte:
    ld      a, e
    call    .hexbyte        ; Convert byte in E to hex string
    ld      (hl), 0         ; Null-terminate string
    ld      hl, $38E9
.create_string:
    jp      $0E2F           ; Create BASIC string

.hexbyte:
    ld      b, a
    rra
    rra
    rra
    rra
    call    .hex
    ld      a, b
.hex:
    and     $0F
    cp      10
    jr      c, .chr
    add     7
.chr:
    add     '0'
    ld      (hl), a
    inc     hl
    ret

;-----------------------------------------------------------------------------
; ST_CALL
;
; syntax: CALL address
; address is signed integer, 0 to 32767   = $0000-$7FFF
;                            -32768 to -1 = $8000-$FFFF
;
; on entry to user code, HL = text after address
; on exit from user code, HL should point to end of statement
;-----------------------------------------------------------------------------
ST_CALL:
    call    GETNUM           ; Get number from BASIC text
    call    DEINT            ; Convert to 16 bit integer
    push    de
    ret                      ; Jump to user code, HL = BASIC text pointer

;-----------------------------------------------------------------------------
; DOS commands
;-----------------------------------------------------------------------------
    include "dos.asm"

;-----------------------------------------------------------------------------
; Convert lower-case to upper-case
; in-out; A = char
;-----------------------------------------------------------------------------
to_upper:
    cp      'a'             ; >='a'?
    ret     c
    cp      'z'+1           ; <='z'?
    ret     nc
    sub     $20             ; a-z -> A-Z
    ret

;-----------------------------------------------------------------------------
; String concatenate
; in: hl = string being added to (must have sufficient space at end!)
;     de = string to add
;-----------------------------------------------------------------------------
strcat:
    xor     a
.find_end:
    cp      (hl)            ; End of string?
    jr      z, .append
    inc     hl              ; No, continue looking for it
    jr      .find_end
.append:                    ; Yes, append string
    ld      a, (de)
    inc     de
    ld      (hl), a
    inc     hl
    or      a
    jr      nz, .append
    ret

;-----------------------------------------------------------------------------
; Fill with $FF to end of ROM
;-----------------------------------------------------------------------------
    assert !($2FFF<$)   ; ROM full!
    dc $2FFF-$+1,$FF

    end