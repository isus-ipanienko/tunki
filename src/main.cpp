#include <memory.h>
#include <stdbool.h>
#include <stdint.h>
#include <vector>

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
  registers_t reg;
  uint8_t mem[0xFFFF];

  uint8_t read_u8(uint16_t pos) { return mem[pos]; }
  uint16_t read_u16(uint16_t pos) {
    return (((uint16_t)read_u8(pos + 1)) << 8) | ((uint16_t)read_u8(pos));
  }

  void write_u8(uint16_t pos, uint8_t data) { mem[pos] = data; }
  void write_u16(uint16_t pos, uint16_t data) {
    write_u8(pos, (data >> 8));
    write_u8(pos + 1, (data & 0xFF));
  }

  void lda(uint8_t param) {
    reg.a = param;
    reg.z = reg.a == 0;
    reg.n = reg.a & (1 << 7);
  }

  void sta(uint16_t addr) { write_u8(addr, reg.a); }

  void tax() {
    reg.x = reg.a;
    reg.z = reg.x == 0;
    reg.n = reg.x & (1 << 7);
  }

  void inx() {
    reg.x++;
    reg.z = reg.x == 0;
    reg.n = reg.x & (1 << 7);
  }

  uint16_t indirect_x() {
    const uint8_t ptr = read_u8(reg.pc) + reg.x;
    return (((uint16_t)read_u8(ptr + 1)) << 8) | ((uint16_t)read_u8(ptr));
  }

  uint16_t indirect_y() {
    const uint8_t ptr = read_u8(reg.pc);
    return ((((uint16_t)read_u8(ptr + 1)) << 8) | ((uint16_t)read_u8(ptr))) +
           reg.y;
  }

#define READ_IMMEDIATE() mem[reg.pc]
#define READ_ZERO_PAGE() mem[read_u8(reg.pc)]
#define READ_ZERO_PAGE_X() mem[read_u8(reg.pc) + reg.x]
#define READ_ZERO_PAGE_Y() mem[read_u8(reg.pc) + reg.y]
#define READ_ABSOLUTE() mem[read_u16(reg.pc)]
#define READ_ABSOLUTE_X() mem[read_u16(reg.pc) + reg.x]
#define READ_ABSOLUTE_Y() mem[read_u16(reg.pc) + reg.y]
#define READ_INDIRECT_X() mem[indirect_x()]
#define READ_INDIRECT_Y() mem[indirect_y()]
  void exec() {
    reg.pc = 0;
    while (true) {
      uint8_t opcode = mem[reg.pc++];
      switch (opcode) {
      case 0x00:
        return;
      case 0x85:
        sta(READ_ZERO_PAGE());
        reg.pc++;
        break;
      case 0x95: {
        sta(READ_ZERO_PAGE_X());
        reg.pc++;
      }
      case 0xA5:
        lda(READ_ZERO_PAGE());
        reg.pc++;
        break;
      case 0xA9:
        lda(READ_IMMEDIATE());
        reg.pc++;
        break;
      case 0xAA:
        tax();
        break;
      case 0xAD:
        lda(READ_ABSOLUTE());
        reg.pc += 2;
        break;
      case 0xE8:
        inx();
        break;
      default:
        break;
      }
    }
  }
#undef READ_IMMEDIATE
#undef READ_ZERO_PAGE
#undef READ_ZERO_PAGE_X
#undef READ_ZERO_PAGE_Y
#undef READ_ABSOLUTE
#undef READ_ABSOLUTE_X
#undef READ_ABSOLUTE_Y
#undef READ_INDIRECT_X
#undef READ_INDIRECT_Y

  void reset() {
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

  bool load(std::vector<uint8_t> cartridge) {
    if (cartridge.size() > 0x8000) {
      return false;
    }
    memcpy(&mem[0x8000], &cartridge[0], cartridge.size());
    write_u16(0xFFFC, 0x8000);
    return true;
  }
} cpu_t;

int main(int argc, char **argv) {
  cpu_t cpu;
  return 0;
}
