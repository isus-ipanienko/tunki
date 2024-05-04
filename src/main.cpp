#include <array>
#include <memory.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

#define READ_U16(_pos)                                                         \
  ((((uint16_t)read_u8(_pos + 1)) << 8) | ((uint16_t)read_u8(_pos)))

typedef std::array<uint8_t, 0x8000> cartridge_t;

typedef enum op_t : uint8_t {
  /* clang-format off */
  RET       = 0x00,
  STA_IX    = 0x81,
  STA_ZP    = 0x85,
  STX_ZP    = 0x86,
  STA_A     = 0x8D,
  STX_A     = 0x8E,
  STA_IY    = 0x91,
  STA_ZPX   = 0x95,
  STX_ZPY   = 0x96,
  STA_AX    = 0x9D,
  STA_AY    = 0x99,
  LDA_IX    = 0xA1,
  LDA_ZP    = 0xA5,
  LDA_I     = 0xA9,
  TAX       = 0xAA,
  LDA_A     = 0xAD,
  LDA_IY    = 0xB1,
  LDA_ZPX   = 0xB5,
  LDA_AX    = 0xBD,
  LDA_AY    = 0xB9,
  INX       = 0xE8,
  /* clang-format on */
} op_t;

typedef struct registers_t {
  uint16_t pc;
  uint8_t sp;
  uint8_t a;
  uint8_t x;
  uint8_t y;
  bool n;
  bool v;
  bool b;
  bool d;
  bool i;
  bool z;
  bool c;
} registers_t;

typedef struct cpu_t {
private:
  registers_t reg;
  uint8_t mem[0xFFFF];

  constexpr uint8_t read_u8(uint16_t pos) const {
    // TODO: add logging
    return mem[pos];
  }
  constexpr void write_u8(uint16_t pos, uint8_t data) {
    // TODO: add logging
    mem[pos] = data;
  }

  constexpr uint16_t read_u16(uint16_t pos) const { return READ_U16(pos); }
  constexpr void write_u16(uint16_t pos, uint16_t data) {
    write_u8(pos, (data & 0xFF));
    write_u8(pos + 1, (data >> 8));
  }

  constexpr uint16_t addr_immediate() { return reg.pc++; }
  constexpr uint16_t addr_zero_page() { return read_u8(reg.pc++); }
  constexpr uint16_t addr_zero_page_x() {
    return (uint8_t)(read_u8(reg.pc++) + reg.x);
  }
  constexpr uint16_t addr_zero_page_y() {
    return (uint8_t)(read_u8(reg.pc++) + reg.y);
  }
  constexpr uint16_t addr_absolute() {
    const uint16_t pc = reg.pc;
    reg.pc += 2;
    return read_u16(pc);
  }
  constexpr uint16_t addr_absolute_x() {
    const uint16_t pc = reg.pc;
    reg.pc += 2;
    return read_u16(pc) + reg.x;
  }
  constexpr uint16_t addr_absolute_y() {
    const uint16_t pc = reg.pc;
    reg.pc += 2;
    return read_u16(pc) + reg.y;
  }
  constexpr uint16_t addr_indirect_x() {
    const uint8_t ptr = read_u8(reg.pc) + reg.x;
    return READ_U16(ptr);
  }
  constexpr uint16_t addr_indirect_y() {
    const uint8_t ptr = read_u8(reg.pc);
    return READ_U16(ptr) + reg.y;
  }

  constexpr void sta(uint16_t addr) { write_u8(addr, reg.a); }
  constexpr void lda(uint16_t addr) {
    reg.a = read_u8(addr);
    reg.z = reg.a == 0;
    reg.n = reg.a & (1 << 7);
  }
  constexpr void stx(uint16_t addr) { write_u8(addr, reg.x); }
  constexpr void ldx(uint16_t addr) {
    reg.x = read_u8(addr);
    reg.z = reg.x == 0;
    reg.n = reg.x & (1 << 7);
  }
  constexpr void tax() {
    reg.x = reg.a;
    reg.z = reg.x == 0;
    reg.n = reg.x & (1 << 7);
  }
  constexpr void inx() {
    reg.x++;
    reg.z = reg.x == 0;
    reg.n = reg.x & (1 << 7);
  }

public:
  constexpr void exec() {
    op_t opcode;
    while (true) {
      opcode = (op_t)read_u8(reg.pc++);
      switch (opcode) {
        /* clang-format off */
      case STA_ZP:     sta(addr_zero_page());      break;
      case STA_ZPX:    sta(addr_zero_page_x());    break;
      case STA_A:      sta(addr_absolute());       break;
      case STA_AX:     sta(addr_absolute_x());     break;
      case STA_AY:     sta(addr_absolute_y());     break;
      case STA_IX:     sta(addr_indirect_x());     break;
      case STA_IY:     sta(addr_indirect_y());     break;
      case LDA_I:      lda(addr_immediate());      break;
      case LDA_ZP:     lda(addr_zero_page());      break;
      case LDA_ZPX:    lda(addr_zero_page_x());    break;
      case LDA_A:      lda(addr_absolute());       break;
      case LDA_AX:     lda(addr_absolute_x());     break;
      case LDA_AY:     lda(addr_absolute_y());     break;
      case LDA_IX:     lda(addr_indirect_x());     break;
      case LDA_IY:     lda(addr_indirect_y());     break;
      case STX_ZP:     stx(addr_zero_page());      break;
      case STX_ZPY:    stx(addr_zero_page_y());    break;
      case STX_A:      stx(addr_absolute());       break;
      case TAX:        tax();                      break;
      case INX:        inx();                      break;
      case RET:                                    return;
      default:                                     return;
        /* clang-format on */
      }
    }
  }

  constexpr void reset() {
    reg.sp = 0;
    reg.a = 0;
    reg.x = 0;
    reg.y = 0;
    reg.n = false;
    reg.v = false;
    reg.b = false;
    reg.d = false;
    reg.i = false;
    reg.z = false;
    reg.c = false;
    reg.pc = read_u16(0xFFFC);
  }

  void insert(cartridge_t cartridge) {
    memcpy(&mem[0x8000], &cartridge[0], cartridge.size());
    reset();
  }

  friend class cpu_test;
} cpu_t;

class cpu_test {
  cpu_t cpu;

public:
  bool test() {
    cartridge_t cartridge = {LDA_I, 0x69, TAX, INX, STA_ZPX, 0xF0, RET};
    cartridge[0x7FFC] = 0x00;
    cartridge[0x7FFD] = 0x80;
    cpu.insert(cartridge);
    cpu.exec();
    for (size_t i = 0; i < 0xFFFF; i++) {
      if (cpu.mem[i]) {
        printf("0x%zx: 0x%x\n", i, cpu.mem[i]);
      }
    }
    return cpu.mem[0x5A] == 0x69;
  }
};

int main(int argc, char **argv) {
  cpu_test test;
  printf("Test passed: %b\n", test.test());
  return 0;
}
