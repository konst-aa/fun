#include "mips_vm.h"
#include "stdarg.h"
#include "stdio.h"
#include "SDL2/SDL.h"
#include "signal.h"
#include "getopt.h"

typedef struct {
    SDL_Window * win;
    SDL_Renderer * ren;
    SDL_Surface * surf;
} Graphics_Context;

/* typedef struct { */
/*     int rgb; */
/*     short i; */
/*     short j; */
/* } Buffered_Pixel; */

int pc;
int registers[32];
char graphical = 0;
char addrs[1000];
char data[0x100000];
char stack[1000];
int BASE_DISPLAY_ADDR = 0x10010000;
/* Buffered_Pixel[0x20000]; */

Graphics_Context * ctx;


// how
#pragma pack(1)
typedef struct {
    unsigned short garbage : 8;
    unsigned short g : 8;
    unsigned short r : 8;
    unsigned short b : 8;
} Pixel;

// reversed bc x86 is little endian?

// opcode | rs | rt | rd | shamt | func
// 6b     | 5b | 5b | 5b | 5b    | 6b
#pragma pack(1)
typedef struct {
    unsigned short func : 6;
    unsigned short shamt : 5;
    unsigned short rd : 5;
    unsigned short rt : 5;
    unsigned short rs : 5;
    unsigned short opcode : 6;
} R_Type;

// opcode | pseudo_addr
// 6b     | 32
#pragma pack(1)
typedef struct {
    int pseudo_addr : 26;
    unsigned short opcode : 6;
} J_Type;

// opcode | rs | rt | immediate
// 6b     | 5b | 5b | 16b
#pragma pack(1)
typedef struct {
    signed short imm : 16;
    unsigned short rt : 5;
    unsigned short rs : 5;
    unsigned short opcode : 6;
} I_Type;

typedef union {
    R_Type r;
    J_Type j;
    I_Type i;
} All_Type;

void (*r_types[200])(short, short, short);
void (*i_types[200])(short, short, short);

int abs(int n) {
    if (n < 0) {
        n *= -1;
    }
    return n;
}

int min(int stuffs, ...) {
    va_list args;
    va_start(args, stuffs);
    int best = 0x7FFFFFFF;
    int t;
    for (int i = 0; i < stuffs; i++) {
        t = va_arg(args, int);
        if (t < best) {
            best = t;
        }
    }
    va_end(args);
    return best;
}

char *normalize_addr(int addr) {
    /* printf("normalizing: %x \n", addr); */
    int stack_dist = 0x7FFFEFFC - addr;      // stack start
    int prog_dist = addr - 0x00400000;       // program data start
    int data_dist = abs(addr - 0x10010000);  // data start
    int smallest = min(3, stack_dist, prog_dist, data_dist);
    if (smallest == stack_dist) {
        return &stack[stack_dist];
    }
    if (smallest == prog_dist) {
        return &addrs[prog_dist];
    } else {
        /* printf("loading from data: %x\n", data[data_dist]); */
        /* printf("loading from data: %x\n",data_dist); */
        return &data[data_dist];
    }
}

int _srl(int a, int b) {
    return (int)(((unsigned)a) >> b);
}

void jump(int ps);

void add(short rs, short rt, short rd) {
    registers[rd] = registers[rs] + registers[rt];
}

void addu(short rs, short rt, short rd) {
    registers[rd] = (unsigned)registers[rs] + (unsigned)registers[rt];
}

void sub(short rs, short rt, short rd) {
    registers[rd] = registers[rs] - registers[rt];
}

void _and(short rs, short rt, short rd) {
    registers[rd] = registers[rs] & registers[rt];
}
void _or(short rs, short rt, short rd) {
    registers[rd] = registers[rs] | registers[rt];
}

void _xor(short rs, short rt, short rd) {
    registers[rd] = registers[rs] ^ registers[rt];
}

void slt(short rs, short rt, short rd) {
    /* printf("rd: %d, rs: %d, rt: %d\n", rd, rs, rt); */
    registers[rd] = registers[rs] < registers[rt];
}

void srl(short shamt, short rt, short rd) {
    registers[rd] = _srl(registers[rt], shamt);
}

void sll(short shamt, short rt, short rd) {
    /* printf("SLL %.2x\n", shamt); */
    registers[rd] = registers[rt] << shamt;
}

void sllv(short rs, short rt, short rd) {
    registers[rd] = registers[rt] << registers[rt];
}

void syscall(short rs, short rt, short rd) {
    switch (registers[V0]) {
        case PRINT_INT:
            printf("%d", registers[A0]);
            break;
        case PRINT_CHAR:
            printf("%c", registers[A0]);
            break;
    }
}

void jr(short rs, short _rt, short _rd) {
    pc = registers[rs] - 0x00400000;
}

void jump(int ps) {
    pc = (ps << 2);  // + (0xF0000000 & (pc + 0x00400000)); // 4 MSBs of pc
    pc -= 0x00400000;
}

void jal(int ps) {
    /* printf("JAL\n"); */
    registers[RA] = 0x00400000 + pc + 4;
    jump(ps);
}

int sxtll(short imm, short n) {
    if (imm < 0) {
        return -abs(imm << n);
    }
    return abs(imm << n);
    /* if (imm < 0) { */
    /*     return imm | 0xFFFF0000; */
    /* } */
    /* return imm; */
}
void addi(short rs, short rt, short imm) {
    /* printf("addi: %d\n", imm); */
    registers[rt] = registers[rs] + imm;
    /* printf("updated: %d\n", registers[rt]); */
}

void addiu(short rs, short rt, short imm) {
    registers[rt] = (unsigned)registers[rs] + (unsigned)imm;
}

void andi(short rs, short rt, short imm) {
    registers[rt] = registers[rs] & imm;
}
void ori(short rs, short rt, short imm) {
    /* printf("imm: %x\n", (unsigned short) imm); */
    registers[rt] = registers[rs] | (unsigned short) imm;
}

void slti(short rs, short rt, short imm) {
    registers[rt] = registers[rs] < imm;
}

void lui(short rs, short rt, short imm) {
    registers[rt] = sxtll(imm, 16);
}

void lb(short rs, short rt, short imm) {
    registers[rt] = *normalize_addr(registers[rs] + imm);
}

void sb(short rs, short rt, short imm) {
    *normalize_addr(registers[rs] + imm) = (char)registers[rt];
}

void lw(short rs, short rt, short imm) {
    /* printf("loading from: %x\n", registers[rs] + imm); */
    registers[rt] = *(int *)normalize_addr(registers[rs] + imm);
    /* printf("huh %x\n", registers[rt]); */
    /* printf("huh %d\n", rt); */
}

void sw(short rs, short rt, short imm) {
    char* normal = normalize_addr(registers[rs] + imm);
    *((int*)normal) = (int)registers[rt];
    /* printf("stored: %x\n", *(int*)normal); */
    /* *((int *)normalize_addr(registers[rs] + imm)) = (int)registers[rt]; */
}

void beq(short rs, short rt, short imm) {
    // AS THIS IS TREATED AS AN I TYPE
    // AND NOT AS A JUMP, 4 IS ALWAYS ADDED
    // AFTER EXECUTION. SEE END OF WHILE LOOP.
    // NO NEED TO ADD 4 TO PC HERE
    if (registers[rs] == registers[rt]) {
        /* printf("beq? %x\n", imm); */
        pc += sxtll(imm, 2);
    }
}

void bne(short rs, short rt, short imm) {
    // SEE BEQ COMMENT
    /* printf("RS: %d\n", rs); */
    /* printf("RT: %d\n", rt); */
    if (registers[rs] != registers[rt]) {
        /* printf("boing: %x\n", imm); */
        pc += sxtll(imm, 2);
        /* pc -= 4; */
    }
}


void setup() {
    registers[SP] = 0x7FFFEFFC;
    // add beq, bne, sub
    // or, ori, and, andi, xor

    r_types[ADD] = add;
    r_types[ADDU] = addu;
    r_types[SUB] = sub;
    r_types[OR] = _or;
    r_types[AND] = _and;
    r_types[XOR] = _xor;
    r_types[SLT] = slt;
    r_types[SYSCALL] = syscall;
    r_types[JR] = jr;
    r_types[SLL] = sll;
    r_types[SRL] = srl;
    r_types[SLLV] = sllv;

    i_types[ADDI] = addi;
    i_types[ADDIU] = addiu;
    i_types[ANDI] = andi;
    i_types[ORI] = ori;
    i_types[SLTI] = slti;
    i_types[LUI] = lui;
    i_types[LB] = lb;
    i_types[SB] = sb;
    i_types[LW] = lw;
    i_types[SW] = sw;
    i_types[BEQ] = beq;
    i_types[BNE] = bne;

    i_types[J] = (void (*)(short, short, short))jump;
    i_types[JAL] = (void (*)(short, short, short))jal;
}


Graphics_Context * setup_bitmap() {
    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        printf("Couldn't init window, Exiting\n");
        return NULL;
    }
    Graphics_Context *ctx = malloc(sizeof(Graphics_Context));
    ctx->win = SDL_CreateWindow("SDL2 Demo", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
            512, 256, SDL_WINDOW_SHOWN);
    ctx->surf = SDL_GetWindowSurface(ctx->win);
    ctx->ren = SDL_CreateRenderer(ctx->win, -1, SDL_RENDERER_ACCELERATED);
    ctx->ren = SDL_GetRenderer(ctx->win);
    return ctx;
}

void update_screen() {
    SDL_RenderClear(ctx->ren);
    /* printf("addr stuff: %x, %x, %x\n", *(int* )(data + 12)); */
    /* SDL_Point points[512 * 256]; */
    int c = 0;
    for (int i = 0; i < 256; i++) {
        for (int j = 0; j < 512 ; j++) {
            /* printf("addr: %x\n", *(int *)(data + (j * 4))); */
            // go down i rows, add j, turn to bytes
            /* int offset = (((i << 8) + (j * 4))); */ 
            /* int current = (int *)(addrs + ((i))) */
            int to_parse = *(int *)(data + ((i * 2048) + j * 4));
            int r, g, b;
            /* g = b = 0; */
            r = _srl(to_parse << 8, 24);
            g = _srl(to_parse << 16, 24);
            b = _srl(to_parse << 24, 24);
            /* printf("r: %x %x %x\n", r, g, b); */
            Pixel *px = (Pixel *)(data + ((i * 2048) + j * 4));
            /* printf("r: %x %x %x\n", px->r, px->g, px->b); */
            /* printf("offset: %x\n", offset); */
            /* printf("sizeof: %d", sizeof(Pixel)); */
            /* Pixel *px = (Pixel *)(addrs + ((i * 2048) + j * 4)); */
            /* printf("px: %x\n", *(int *)(normalize_addr(BASE_DISPLAY_ADDR + offset))); */
            /* SDL_SetRenderDrawColor(ctx->ren, px->r, px->g, px->b, 0xFF); */
            SDL_SetRenderDrawColor(ctx->ren, r, g, b, 0xFF);
            /* printf("i: %d, j: %d\n", i, j); */
            SDL_RenderDrawPoint(ctx->ren, j, i);
        }
    }
    SDL_RenderPresent(ctx->ren);
}

int main(int argc, char ** argv) {
    setup();
    ctx = setup_bitmap();
    /* SDL_RenderClear(ctx->ren); */
    /* SDL_RenderDrawPoint(ctx->ren, 10, 10); */
    /* SDL_RenderPresent(ctx->ren); */
    /* SDL_Delay(2000); */

    FILE *code;
    FILE *data_file;

    int buff[1];
    char data_buff[4];
    int c;

    signal(SIGINT, exit);

    while (c != -1) {
        // https://www.gnu.org/software/libc/manual/html_node/Getopt-Long-Option-Example.html
        static struct option long_options[] = {
            /* These options don’t set a flag.
               We distinguish them by their indices. */
            {"help",  no_argument,  0, 'h'},
            {"data",  required_argument, 0, 'd'},
            {"graphical",  no_argument, 0, 'g'},
            /* {0, 0} */
        };
        /* getopt_long stores the option index here. */
        int option_index = 0;

        c = getopt_long (argc, argv, "hd:",
                long_options, &option_index);

        if (c == -1) {
            break;
        }
        switch (c) {
            case 'd':
                data_file = fopen(optarg, "rb");
                break;
            case 'h':
                printf("Usage: mips-vm [options] [mips-file]\n");
                printf("       leave mips-file empty to read from stdin\n");
                printf("       -d, --data <file>  Load .data from file\n");
                printf("       -g, --graphical Treat the next 256x512 words from address 0x10010000 as a display buffer\n");
                return 0;
            case 'g':
                graphical = 1;
            default:
                break;
        }
    }


    if (argc == optind) {
        freopen(NULL, "rb", stdin);
        code = stdin;
    } else {
        code = fopen(argv[optind], "rb");
    }



    int i = 0;
    while (fread(buff, sizeof(buff), 1, code)) {
        *((int *)(addrs + i)) = *buff;
        i += 4;
    }
    int MAX_ADDR = i;
    i = 0;

    if (data_file != NULL) {
        while (fread(buff, sizeof(buff), 1, data_file)) {
            *((int *)(data + i)) = *buff;
            i += 4;
        }
    }
    /* printf("last i: %x\n", i); */
    fclose(code);
    /* fclose(data_file); */

    /* int MAX_DATA = i; */
    i = 0;
    long prev = 0;
    while (pc < MAX_ADDR) {
        registers[ZERO] = 0;
        if (graphical && SDL_GetTicks64() - prev > 1000 / 1000) {
            /* printf("pc: %d\n", pc); */
            update_screen();
            prev = SDL_GetTicks64();
        }
        short opcode, func;
        All_Type curr = *((All_Type *)(addrs + pc));

        /* if (i > 23) { */
        /*     return 0; */
        /* } */
        /* printf("pc: %d\n", pc); */
        /* i += 1; */

        /* printf("OPCODE: %.2x\n", opcode); */
        /* printf("OPCODE: %.2x\n", ((J_Type *)(addrs + pc))->opcode); */
        /* printf("T1: %.2x\n", registers[T1]); */
        /* printf("%.8x\n", addrs[pc] << 2); */
        opcode = curr.j.opcode;

        if (opcode == J || opcode == JAL) {
            ((void (*)(int))i_types[opcode])(curr.j.pseudo_addr);
            continue;
        }

        // opcode | rs | rt | mystery
        // 6b     | 5b | 5b | 16b

        if (opcode != 0) {
            // opcode | rs | rt | immediate
            // 6b     | 5b | 5b | 16b
            i_types[opcode](curr.i.rs, curr.i.rt, curr.i.imm);
            pc += 4;
            continue;
        }
        // Otherwise we're R type
        func = curr.r.func;

        // opcode | rs | rt | rd | shamt | func
        // 6b     | 5b | 5b | 5b | 5b    | 6b
        /* printf("FUNC_CODE: %.2x\n", func); */

        if (func == SLL | func == SRL) {
            r_types[func](curr.r.shamt, curr.r.rt, curr.r.rd);
        } else {
            r_types[func](curr.r.rs, curr.r.rt, curr.r.rd);
        }
        if (func != JR) {
            pc += 4;
        }
    }
    /* printf("ADDR: %.8x\n", pc + 0x00400000); */
    printf("\n");
    if (graphical) {
        update_screen();
        SDL_Delay(4000);
    }
}
