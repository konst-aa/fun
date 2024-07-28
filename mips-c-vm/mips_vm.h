#ifndef MIPS_RUNTIME_
#define MIPS_RUNTIME_

/* int registers[32]; */
/* char addrs[1000]; */
/* char data[10000]; */
/* char stack[1000]; */
/* int pc; */

enum FUNC_CODES {
    SRL = 0x02,
    SYSCALL = 0x0C,
    ADD = 0x20,
    ADDU = 0x21,
    SUB = 0x22,
    SLT = 0x2A,
    OR = 0x25,
    AND = 0x24,
    XOR = 0x26,
    JR = 0x08,
    SLL = 0x00,
    SLLV = 0x04
};
enum OPCODES {
    J = 0x02,
    JAL = 0x03,
    ADDI = 0x08,
    BEQ = 0x04,
    BNE = 0x05,
    SLTI = 0x0A,
    ANDI = 0x0C,
    ORI = 0x0D,
    LB = 0x20,
    LW = 0x23,
    LUI = 0x0F,
    SB = 0x28,
    SW = 0x2B,
    ADDIU = 0x09,
};

enum REGISTERS {
    ZERO,
    AT,
    V0,
    V2,
    A0,
    A1,
    A2,
    A3,
    T0,
    T1,
    T2,
    SP = 29,
    FP = 30,
    RA = 31
};

enum SYSCALLS { INVALID, PRINT_INT };

#endif
