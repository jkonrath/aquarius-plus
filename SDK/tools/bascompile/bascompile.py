#!/usr/bin/env python3

import argparse
import sys
import struct
from lib.defs import Statements, Tokens, Operation, Variable, StringLiteral
from lib.tokenizer import tokenize
from lib.parser import parse
from enum import Enum

parser = argparse.ArgumentParser(description="Convert BASIC text file to executable")
parser.add_argument("input", help="Input file")
parser.add_argument("output", help="Output file")
args = parser.parse_args()

lines, variableNames = parse(args.input)


f = open(args.output, "wt")

# String descriptor: four bytes: Length, ignored, Text Address


print(
    """
; RST
START:   equ $00     ; 0 Start/Reboot
SYNCHR:  equ $08     ; 1 SN Error if next character does not match
CHRGET:  equ $10     ; 2 Get Next Character
OUTCHR:  equ $18     ; 3 Output Character
COMPAR:  equ $20     ; 4 Compare HL with DE
FSIGN:   equ $28     ; 5 Get sign of Floating Point Argument
HOOKDO:  equ $30     ; 6 Extended BASIC Hook Dispatch
INTRPT:  equ $38     ; 7 (S3BASIC) Execute Interrupt Routine
    
; Floating point routines in system ROM
FADDH:   equ $1250      ; FAC = 0.5 + FAC
FADDS:   equ $1253      ; FAC = (hl) + FAC
FSUBS:   equ $1258      ; FAC = (hl) - FAC
FSUBT:   equ $125C      ; FAC = ARG_from_stack - FAC 
FSUB:    equ $125E      ; FAC = ARG - FAC
FADD:    equ $1261      ; FAC = ARG + FAC
ZERO:    equ $12C3      ; FAC = 0
ROUND:   equ $12F1      ; FAC = round(ARG)
NEGR:    equ $131C      ; ARG = -ARG
LOG:     equ $1385      ; FAC = log(ARG)
LOG2:    equ $1395      ; FAC = log2(ARG)
FMULTT:  equ $13C9      ; FAC = ARG_from_stack * FAC
FMULT:   equ $13CB      ; FAC = ARG * FAC
FDIVT:   equ $142D      ; FAC = ARG_from_stack / FAC
FDIV:    equ $142F      ; FAC = ARG / FAC
SGN:     equ $14F5      ; FAC = ARG < 0 ? -1 : ARG > 0 ? 1 : 0
FLOAT:   equ $14F6      ; FAC = float(A)
FLOATR:  equ $14FB      ;
ABS:     equ $1509      ; FAC = abs(FAC)
NEG:     equ $150B      ; FAC = -FAC
PUSHF:   equ $1513      ; Push FAC to stack
MOVFM:   equ $1520      ; FAC = (hl)
MOVFR:   equ $1523      ; FAC = ARG
MOVRF:   equ $152E      ; ARG = FAC
MOVRM:   equ $1531      ; ARG = (hl)
MOVMF:   equ $153A      ; (hl) = FAC
FCOMP:   equ $155B      ; A=1 when ARG<FAC, A=0 when ARG==FAC, A=-1 when ARG>FAC
QINT:    equ $1586      ;
INT:     equ $15B1      ; FAC = int(FAC)
FIN:     equ $15E5      ;
FADDT:   equ $165C      ; FAC = ARG_from_stack + FAC 
FOUT:    equ $1680      ; Convert number in FAC to string in FBUFFR+1
SQR:     equ $1775      ; FAC = sqrt(FAC)  (FAC = FAC ^ 0.5)
FPWRT:   equ $177E      ; FAC = ARG_from_stack ^ FAC
FPWR:    equ $1780      ; FAC = ARG ^ FAC
EXP:     equ $17CD      ; FAC = exp(FAC)
RND:     equ $1866      ; FAC = rnd(ARG)
COS:     equ $18D7      ; FAC = cos(FAC)
SIN:     equ $18DD      ; FAC = sin(FAC)
TAN:     equ $1970      ; FAC = tan(FAC)
ATN:     equ $1985      ; FAC = atan(FAC) - not implemented 8K BASIC

FRCINT:  equ $0682      ; de = (int)FAC
GIVINT:  equ $0B21      ; FAC = float(MSB:a LSB:c)
FLOATB:  equ $0B22      ; FAC = float(MSB:a LSB:b)
FLOATD:  equ $0B23      ; FAC = float(MSB:a LSB:d)
STROUT:  equ $0E9D
CRDO:    equ $19EA

FACLO:   equ $38E4      ; FAC low order of mantissa
FACMO:   equ $38E5      ; FAC middle order of mantissa
FACHO:   equ $38E6      ; FAC high order of mantissa
FAC:     equ $38E7      ; FAC exponent
FBUFFR:  equ $38E8

    org $38E1

    ; Header and BASIC stub
    db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00
    db "AQPLUS"
    db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00
    db $0E,$39,$0A,$00,$DA,"14608",':',$80,$00,$00,$00
    jp main

main:
    push hl

""",
    file=f,
)


# Info from https://community.embarcadero.com/index.php/article/technical-articles/162-programming/14799-converting-between-microsoft-binary-and-ieee-forma
def float_to_mbf32(value):
    ieee_val = struct.unpack("I", struct.pack("f", value))[0]
    if ieee_val == 0:
        return 0

    mbf_exp = (((ieee_val >> 23) & 0xFF) + 2) & 0xFF
    sign = ieee_val >> 31
    mbf_val = (mbf_exp << 24) | (sign << 23) | (ieee_val & 0x7FFFFF)
    return mbf_val


def assign_float_to_arg(val):
    mbf_val = float_to_mbf32(val)
    print(f"    ld   bc, ${mbf_val >> 16:04x}", file=f)
    print(f"    ld   de, ${mbf_val & 0xFFFF:04x}", file=f)


def assign_float_to_fac(val):
    assign_float_to_arg(val)
    print(f"    call MOVFR", file=f)


def save_arg(varName):
    print(f"    ld   (v{varName}+2), bc", file=f)
    print(f"    ld   (v{varName}), de", file=f)


def save_fac(varName):
    print(f"    ld   hl, v{varName}", file=f)
    print(f"    call MOVMF", file=f)


def load_fac(varName):
    print(f"    ld   hl, v{varName}", file=f)
    print(f"    call MOVFM", file=f)


def load_arg(varName):
    print(f"    ld   hl, v{varName}", file=f)
    print(f"    call MOVRM", file=f)


def print_fac():
    # This destructs the value of FAC
    print(f"    call FOUT", file=f)
    print(f"    ld   hl, FBUFFR+1", file=f)
    print(f"    call STROUT", file=f)


def push_fac():
    print(f"    call PUSHF", file=f)


def pop_arg():
    print(f"    pop bc", file=f)
    print(f"    pop de", file=f)


def emit_unary_op(expr, func):
    emit_expr(expr[1])
    print(f"    call {func}", file=f)


def emit_binary_op(expr, func):
    emit_expr(expr[1])
    push_fac()
    emit_expr(expr[2])
    pop_arg()
    print(f"    call {func}", file=f)


def emit_compare(expr):
    emit_expr(expr[1])
    print(f"    push de", file=f)
    emit_expr(expr[2])
    print(f"    pop  hl", file=f)
    print(f"    rst  COMPAR", file=f)


def emit_expr(expr):
    if isinstance(expr, float):
        assign_float_to_fac(expr)

    elif isinstance(expr, Variable):
        load_fac(expr.name)

    elif isinstance(expr, tuple):
        if expr[0] == Operation.NEGATE:
            emit_unary_op(expr, "NEG")
        elif expr[0] == Operation.MULT:
            emit_binary_op(expr, "FMULT")
        elif expr[0] == Operation.DIV:
            emit_binary_op(expr, "FDIV")
        elif expr[0] == Operation.ADD:
            emit_binary_op(expr, "FADD")
        elif expr[0] == Operation.SUB:
            emit_binary_op(expr, "FSUB")
        elif expr[0] == Operation.POW:
            emit_binary_op(expr, "FPWR")
        elif expr[0] == Operation.SIN:
            emit_unary_op(expr, "SIN")
        elif expr[0] == Operation.COS:
            emit_unary_op(expr, "COS")
        elif expr[0] == Operation.TAN:
            emit_unary_op(expr, "TAN")
        elif expr[0] == Operation.ATN:
            emit_unary_op(expr, "ATN")
        elif expr[0] == Operation.LOG:
            emit_unary_op(expr, "LOG")
        elif expr[0] == Operation.EXP:
            emit_unary_op(expr, "EXP")
        elif expr[0] == Operation.RND:
            emit_unary_op(expr, "RND")
        elif expr[0] == Operation.SQR:
            emit_unary_op(expr, "SQR")
        elif expr[0] == Operation.ABS:
            emit_unary_op(expr, "ABS")
        elif expr[0] == Operation.SGN:
            emit_unary_op(expr, "SGN")
        elif expr[0] == Operation.INT:
            emit_unary_op(expr, "INT")
        elif expr[0] == Operation.NOT:
            emit_expr(expr[1])
            print(f"    call FRCINT", file=f)
            # Should we check Z flag here for out of range?
            print(f"    ld   a, $FF", file=f)
            print(f"    xor  e", file=f)
            print(f"    ld   b, a", file=f)
            print(f"    ld   a, $FF", file=f)
            print(f"    xor  d", file=f)
            print(f"    call FLOATB", file=f)

        elif expr[0] == Operation.AND:
            emit_expr(expr[1])
            print(f"    call FRCINT", file=f)
            print(f"    push de", file=f)
            emit_expr(expr[2])
            print(f"    call FRCINT", file=f)
            print(f"    pop  bc", file=f)
            print(f"    ld   a,c", file=f)
            print(f"    and  e", file=f)
            print(f"    ld   c,a", file=f)
            print(f"    ld   a,b", file=f)
            print(f"    and  d", file=f)
            print(f"    call GIVINT", file=f)

        elif expr[0] == Operation.OR:
            emit_expr(expr[1])
            print(f"    call FRCINT", file=f)
            print(f"    push de", file=f)
            emit_expr(expr[2])
            print(f"    call FRCINT", file=f)
            print(f"    pop  bc", file=f)
            print(f"    ld   a,c", file=f)
            print(f"    or   e", file=f)
            print(f"    ld   c,a", file=f)
            print(f"    ld   a,b", file=f)
            print(f"    or   d", file=f)
            print(f"    call GIVINT", file=f)

        elif expr[0] == Operation.EQ:
            emit_compare(expr)
            print(f"    ld   a, -1", file=f)
            print(f"    jp   Z, .l", file=f)
            print(f"    xor  a", file=f)
            print(f".l: call FLOAT", file=f)

        elif expr[0] == Operation.NE:
            emit_compare(expr)
            print(f"    ld   a, 0", file=f)
            print(f"    jp   Z, .l", file=f)
            print(f"    ld   a, -1", file=f)
            print(f".l: call FLOAT", file=f)

        elif expr[0] == Operation.LT:
            emit_compare(expr)
            print(f"    ld   a, -1", file=f)
            print(f"    jp   C, .l", file=f)
            print(f"    xor  a", file=f)
            print(f".l: call FLOAT", file=f)

        elif expr[0] == Operation.LE:
            emit_compare(expr)
            print(f"    ld   a, -1", file=f)
            print(f"    jp   C, .l", file=f)
            print(f"    jp   Z, .l", file=f)
            print(f"    xor  a", file=f)
            print(f".l: call FLOAT", file=f)

        elif expr[0] == Operation.GE:
            emit_compare(expr)
            print(f"    ld   a, 0", file=f)
            print(f"    jp   C, .l", file=f)
            print(f"    ld   a, -1", file=f)
            print(f".l: call FLOAT", file=f)

        elif expr[0] == Operation.GT:
            emit_compare(expr)
            print(f"    ld   a, 0", file=f)
            print(f"    jp   C, .l", file=f)
            print(f"    jp   Z, .l", file=f)
            print(f"    ld   a, -1", file=f)
            print(f".l: call FLOAT", file=f)

        else:
            print(f"Unhandled expression {expr}")
            exit(1)
    else:
        print(f"Unhandled expression {expr}")
        exit(1)


for line in lines:
    print(f"l{line[0]}:", file=f)

    for stmt in line[1]:
        print(f"    ; {stmt}", file=f)
        if stmt[0] == Statements.LET:
            varName = stmt[1].name
            expr = stmt[2]
            emit_expr(expr)
            save_fac(varName)

        elif stmt[0] == Statements.GOTO:
            print(f"    jp   l{stmt[1]:.0f}", file=f)
        elif stmt[0] == Statements.END:
            print(f"    jp   end", file=f)
        elif stmt[0] == Statements.PRINT:
            for expr in stmt[1]:
                emit_expr(expr)
                print_fac()

            print(f"    call CRDO", file=f)

        else:
            print(f"Unhandled statement {stmt}")

print(
    """
end:
    pop hl
    ret
""",
    file=f,
)

for name in variableNames:
    print(f"v{name}: defd 0", file=f)


print(
    """
    ; A valid CAQ file needs 15 zeros at the end of the file
    db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
""",
    file=f,
    end="",
)