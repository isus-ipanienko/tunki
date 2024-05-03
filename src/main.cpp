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
  STA_ZP    = 0x85,
  STA_ZPX   = 0x95,
  LDA_ZPY   = 0xA5,
  LDA_I     = 0xA9,
  TAX       = 0xAA,
  LDA_A     = 0xAD,
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

  constexpr uint8_t read_immediate() { return read_u8(reg.pc++); }
  constexpr uint8_t read_zero_page() { return read_u8(read_u8(reg.pc++)); }
  constexpr uint8_t read_zero_page_x() {
    return read_u8(read_u8(reg.pc++) + reg.x);
  }
  constexpr uint8_t read_zero_page_y() {
    return read_u8(read_u8(reg.pc++) + reg.y);
  }
  constexpr uint8_t read_absolute() {
    const uint16_t pc = reg.pc;
    reg.pc += 2;
    return read_u8(read_u16(pc));
  }
  constexpr uint8_t read_absolute_x() {
    const uint16_t pc = reg.pc;
    reg.pc += 2;
    return read_u8(read_u16(pc) + reg.x);
  }
  constexpr uint8_t read_absolute_y() {
    const uint16_t pc = reg.pc;
    reg.pc += 2;
    return read_u8(read_u16(pc) + reg.y);
  }
  constexpr uint8_t read_indirect_x() {
    const uint8_t ptr = read_u8(reg.pc) + reg.x;
    return read_u8(READ_U16(ptr));
  }
  constexpr uint8_t read_indirect_y() {
    const uint8_t ptr = read_u8(reg.pc);
    return read_u8(READ_U16(ptr) + reg.y);
  }

  constexpr void lda(uint8_t param) {
    reg.a = param;
    reg.z = reg.a == 0;
    reg.n = reg.a & (1 << 7);
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
  constexpr void sta(uint16_t addr) { write_u8(addr, reg.a); }

public:
  constexpr void exec() {
    op_t opcode;
    while (true) {
      opcode = (op_t)read_u8(reg.pc++);
      switch (opcode) {
        /* clang-format off */
      case STA_ZP:     sta(read_zero_page());      break;
      case STA_ZPX:    sta(read_zero_page_x());    break;
      case LDA_I:      lda(read_immediate());      break;
      case LDA_ZPY:    lda(read_zero_page_y());    break;
      case LDA_A:      lda(read_absolute());       break;
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

  void load(cartridge_t cartridge) {
    memcpy(&mem[0x8000], &cartridge[0], cartridge.size());
    write_u16(0xFFFC, 0x8000);
    reset();
  }

  friend class cpu_test;
} cpu_t;

class cpu_test {
  cpu_t cpu;

public:
  bool test() {
    cartridge_t program = {LDA_I, 0x69, TAX, INX};
    cpu.load(program);
    cpu.exec();
    return cpu.reg.x == 0x6A;
  }
};

int main(int argc, char **argv) {
  cpu_test test;
  printf("Test passed: %b\n", test.test());
  return 0;
}
