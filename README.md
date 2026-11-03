# RV32I Pipelined RISC-V Core

A small educational RISC-V processor written in synthesizable Verilog. The
design implements a simple five-stage pipeline, loads instructions from a
hexadecimal memory image, executes a factorial program, and exposes the low
eight bits of data memory word zero on `led`.

This project is intended to show how a basic RISC-V processor works at RTL:
instruction fetch, decode, execute, memory access, writeback, forwarding,
hazard detection, branch redirection, and simulation verification are all
visible in separate source files.

## Project demonstration

The design and simulation are demonstrated in this YouTube video:

[Watch the RISC-V processor demonstration](https://youtu.be/ga93fR30WEw)

## Project Documentation

[Click here to view the complete PDF documentation](https://github.com/sujithvarmap/riscv-base/blob/main/riscv%20%281%29.pdf)

## Processor overview

The top-level module is `riscv_top`. It has a clock, an active-high reset, and
an eight-bit LED output:

```text
clk  - processor clock
rst  - active-high reset
led  - dmem[0][7:0]
```

The processor uses a 32-bit program counter and 32-bit data paths. Instructions
are 32-bit words and are fetched on four-byte boundaries. Instruction memory
and data memory are modeled as 256-word arrays inside `riscv_top`.

### Five pipeline stages

Each instruction moves through these stages:

1. **Instruction Fetch (IF)**  
   The program counter selects an instruction from `imem`. Normally the PC
   advances by four bytes.
2. **Instruction Decode (ID)**  
   The opcode is decoded, register operands are read, and the immediate value
   is generated.
3. **Execute (EX)**  
   The ALU performs arithmetic, logical, comparison, address-generation, and
   branch-comparison operations.
4. **Memory (MEM)**  
   Load and store instructions access `dmem`. Store data is carried through the
   EX/MEM pipeline register.
5. **Writeback (WB)**  
   An ALU result or load result is written back to the register file.

The `pipeline_regs` module contains the IF/ID, ID/EX, EX/MEM, and MEM/WB
registers that separate these stages.

## Supported instruction groups

The current control and ALU logic supports the following instruction groups:

- **R-type register operations:** `ADD`, `SUB`, `AND`, `OR`, `XOR`, `SLL`,
  `SRL`, `SRA`, `SLT`, and `SLTU`
- **I-type arithmetic:** `ADDI` and the other ALU operations selected by the
  I-type `funct3` field
- **Loads and stores:** `LW` and `SW`
- **Conditional branches:** `BEQ` and `BNE`

The immediate generator also contains formats for `LUI`, `AUIPC`, `JAL`, and
`JALR`; additional control and datapath work may be required before those
instructions are fully usable in a complete program.

Register `x0` is hard-wired to zero. Writes to register zero are ignored, and
reads of register zero always return zero.

## Pipeline hazards

### Data forwarding

The `forwarding_unit` reduces data hazards by selecting a newer value from:

- the EX/MEM stage, or
- the MEM/WB stage.

This allows dependent arithmetic instructions to use a result without waiting
for it to be written to and read from the register file.

### Load-use stalls

Forwarding cannot immediately solve a load-use dependency because load data is
available later than an ALU result. The `hazard_unit` detects when an
instruction in ID depends on a load in EX and asserts `stall`.

During a stall:

- the PC does not advance;
- the IF/ID instruction remains in place;
- a bubble is inserted into the ID/EX stage.

### Branch flushing

Branches are resolved in the EX stage. When `BEQ` or `BNE` is taken, the
target is calculated from the branch instruction's PC and immediate. The
pipeline is flushed so instructions fetched from the wrong path do not update
architectural state.

## Memory and output behavior

### Instruction memory

`riscv_top.v` initializes every instruction-memory entry to the RISC-V NOP
encoding (`32'h00000013`) and then loads `program.mem` with `$readmemh`.
Therefore, the simulator must be run from the project directory, or the
memory-file path must be adjusted.

### Data memory

Data memory is a 256-entry array of 32-bit words. Word addresses are derived
from the ALU address using bits `[9:2]`. For the supplied program:

```text
dmem[0] = result storage location
```

The `led` output is continuously assigned to `dmem[0][7:0]`. A stored result
of decimal 120 therefore appears as `8'h78` on the LED output.

## Factorial demonstration program

`program.mem` contains the machine-code instructions for the factorial
demonstration. The program computes:

```text
5! = 5 x 4 x 3 x 2 x 1 = 120
```

At a high level, the program:

1. initializes a register with `5`;
2. initializes an accumulator with `1`;
3. checks whether the loop counter has reached the terminating condition;
4. multiplies through repeated addition;
5. decrements the counter;
6. repeats until the factorial is complete;
7. stores the result to `dmem[0]`.

The machine-code image is loaded in word order starting at address zero. The
testbench waits for the pipeline to finish, reads `dut.dmem[0]`, and reports
`PASS` only when the value is decimal 120.

## Source files

- `riscv_top.v` - top-level processor, instruction memory, and data memory
- `pipeline_regs.v` - pipeline registers between all five stages
- `alu.v` - 32-bit arithmetic and logical unit
- `reg_file.v` - 32-register integer register file with read bypassing
- `imm_gen.v` - I, S, B, U, and J immediate generation
- `control_unit.v` - opcode-based control-signal generation
- `forwarding_unit.v` - EX-stage forwarding selection
- `hazard_unit.v` - load-use hazard detection
- `program.mem` - hexadecimal instruction image for the factorial program
- `tb_riscv.v` - simulation-only testbench
- `.gitignore` - excludes generated simulator output

The testbench is intentionally separate from the processor RTL. This keeps
simulation-only code out of the synthesizable design and makes it easier to
replace the test program or add additional testbenches.

## Simulation with Icarus Verilog

Install Icarus Verilog, open a terminal in this directory, and run:

```text
iverilog -g2012 -s tb_riscv -o sim.vvp *.v
vvp sim.vvp
```

Expected output:

```text
result = 120
PASS
```

The testbench generates a 10 ns clock, releases reset after 20 ns, waits for
the processor to execute the program, checks `dut.dmem[0]`, and finishes the
simulation.

## Simulation with Verilator

The Verilog source can also be linted with Verilator:

```text
verilator --lint-only --language 1800 --top-module tb_riscv *.v
```

The exact command may vary with the installed Verilator version and simulator
setup.

## GitHub workflow

From this directory, create a local Git repository and publish it to a new,
empty GitHub repository:

```text
git init
git branch -M main
git add .
git commit -m "Add pipelined RV32I core"
git remote add origin https://github.com/<your-user>/<your-repository>.git
git push -u origin main
```

For later changes:

```text
git add .
git commit -m "Describe the change"
git push
```

Do not commit generated files such as `*.vvp`, `*.vcd`, or simulator logs;
they are excluded by `.gitignore`.

## Future improvements

Possible next steps include adding more RV32I instructions, implementing a
complete `JAL`/`JALR` datapath, adding byte and halfword memory operations,
parameterizing memory sizes, adding assertions, and creating automated
regression tests for arithmetic, branches, loads, stores, hazards, and reset
behavior.


