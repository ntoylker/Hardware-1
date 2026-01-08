# Hardware 1 Project: AI Accelerator in Verilog

> A university project for the course **"Digital HW Systems at Low Logic Levels I" (Hardware 1)** at Aristotle University of Thessaloniki (AUTh).

**Author:** Nikos Toulkeridis

---

## Table of Contents

1.  [Project Overview](#project-overview)
2.  [Project Goals](#project-goals)
3.  [Architecture & Design](#architecture--design)
    *   [Exercise 1: ALU](#exercise-1-arithmetic-logic-unit-alu)
    *   [Exercise 2: Calculator](#exercise-2-16-bit-calculator)
    *   [Exercise 3: Register File](#exercise-3-register-file)
    *   [Exercise 4: AI Accelerator (Neural Network)](#exercise-4-ai-accelerator-neural-network)
4.  [Repository Structure](#repository-structure)
5.  [Testing & Simulation Results](#testing--simulation-results)
6.  [How to Run](#how-to-run)

---

## Project Overview

This project involves the design, implementation in Verilog HDL, and simulation of four distinct digital circuits that combine to form a complete, simple AI accelerator system. The work is structured into four main exercises:

1.  **ALU (Arithmetic Logic Unit):** A 32-bit combinational unit capable of 12 arithmetic, logical, and shift operations.
2.  **Calculator:** A 16-bit sequential calculator using the ALU and an accumulator register.
3.  **Register File:** A 16x32-bit multi-ported register file (4 read ports, 2 write ports) with bypass logic.
4.  **AI Accelerator:** A simple neural network accelerator that uses the ALU (via a MAC unit) and the Register File to perform computations, controlled by a Finite State Machine (FSM).

## Project Goals

The primary goals of this project, as outlined in the course instructions, are:

1.  **Design a 32-bit ALU** that supports signed addition, subtraction, multiplication, logical operations (AND, OR, NOR, NAND, XOR), and shift operations (logical and arithmetic, left and right). The ALU must also output `zero` and `overflow` flags.

2.  **Design a 16-bit Calculator** that uses the ALU to perform operations on a value stored in a 16-bit accumulator. The operation is selected by button inputs, and the result is displayed on LEDs. An encoder module (`calc_enc.v`) must be implemented in **structural Verilog**.

3.  **Design a Register File** with 16 registers, each 32 bits wide. It should have 4 read ports and 2 write ports, an active-low asynchronous reset, and prioritize write operations on read/write collisions (bypass logic).

4.  **Design an AI Accelerator (Neural Network)** that models a simple 3-neuron network. This system uses:
    *   A ROM to store initial weights and biases.
    *   The Register File to hold the loaded values.
    *   Two MAC (Multiply-Accumulate) units built from ALUs.
    *   Two standalone ALUs for shift operations.
    *   A 7-state **Finite State Machine (FSM)** to control the datapath, handling loading, pre-processing, input layer, output layer, post-processing, and idle states. Overflow handling (saturating to max positive value) is required.

## Architecture & Design

### Exercise 1: Arithmetic Logic Unit (ALU)

*   **File:** [alu.v](final_files/alu.v)
*   **Type:** Purely combinational circuit.
*   **Inputs:** `op1` (32-bit signed), `op2` (32-bit signed), `alu_op` (4-bit operation selector).
*   **Outputs:** `result` (32-bit), `zero` (1-bit flag), `ovf` (1-bit overflow flag).
*   **Supported Operations (12 total):**
    | `alu_op` | Operation                     |
    | :------- | :---------------------------- |
    | `0000`   | Logical Shift Right           |
    | `0001`   | Logical Shift Left            |
    | `0010`   | Arithmetic Shift Right        |
    | `0011`   | Arithmetic Shift Left         |
    | `0100`   | Signed Addition               |
    | `0101`   | Signed Subtraction            |
    | `0110`   | Signed Multiplication         |
    | `1000`   | Logical AND                   |
    | `1001`   | Logical OR                    |
    | `1010`   | Logical NOR                   |
    | `1011`   | Logical NAND                  |
    | `1100`   | Logical XOR                   |

### Exercise 2: 16-bit Calculator

*   **Files:** [calc.v](final_files/calc.v), [calc_enc.v](final_files/calc_enc.v)
*   **Type:** Sequential circuit with a synchronous 16-bit accumulator.
*   **Design:** The calculator uses **sign extension** to interface the 16-bit accumulator and switch inputs with the 32-bit ALU. The `calc_enc.v` module is a gate-level (structural Verilog) encoder that maps button presses to `alu_op` codes.
*   **Control:**
    *   `btnac`: Synchronous reset (clears accumulator).
    *   `btnc`: Loads the ALU result into the accumulator.
    *   `btnl`, `btnr`, `btnd`: Select the ALU operation via the encoder.
    *   `sw[15:0]`: 16-bit data input (operand 2).
    *   `led[15:0]`: 16-bit output (accumulator value).

### Exercise 3: Register File

*   **File:** [regfile.v](final_files/regfile.v)
*   **Type:** Parameterized (`DATAWIDTH=32`), multi-ported memory.
*   **Ports:** 4 asynchronous read ports, 2 synchronous write ports.
*   **Features:**
    *   Active-low asynchronous reset (`resetn`).
    *   **Write Collision Handling:** When both write ports target the same register, `writeData2` takes priority.
    *   **Combinational Bypass Logic:** When a read address matches a write address in the same cycle, the data being written is forwarded directly to the read output, ensuring data coherence without needing to wait for the next clock cycle.

### Exercise 4: AI Accelerator (Neural Network)

*   **Files:** [nn.v](final_files/nn.v), [mac_unit.v](final_files/mac_unit.v)
*   **Type:** FSM-controlled datapath.
*   **Components:**
    *   1x ROM (for weights/biases)
    *   1x Register File (16x32-bit)
    *   2x ALU (for shift operations)
    *   2x MAC Unit (each containing 2 ALUs for multiply-add)
*   **MAC Unit (`mac_unit.v`):** A structural module that chains two ALUs. The first performs multiplication (`op1 * op2`), and the second adds a third operand (`+ op3`), outputting the final result and flags.

#### FSM Design

*   **Type:** **Moore FSM** (outputs depend only on the current state).
*   **States (7):**
    1.  `STATE_DEACTIVATED`: Idle, waiting for `enable` signal after reset.
    2.  `STATE_LOAD`: Loads 8 pairs of weights/biases from ROM into the Register File (requires 9 clock cycles).
    3.  `STATE_PREPROCESS`: Performs arithmetic right shift on inputs using the two ALUs.
    4.  `STATE_INPUT_LAYER`: Executes the first two neurons in parallel using the two MAC units.
    5.  `STATE_OUTPUT_LAYER_1`: First stage of the third neuron (first MAC operation).
    6.  `STATE_OUTPUT_LAYER_2`: Second stage of the third neuron (second MAC operation).
    7.  `STATE_POSTPROCESS`: Performs arithmetic left shift on the output.
    8.  `STATE_IDLE`: Computation complete, waiting for new inputs.
*   **Overflow Handling:** If an overflow is detected at any stage, the FSM immediately transitions to `STATE_IDLE` and outputs the maximum positive 32-bit value (`0x7FFFFFFF`).
*   **Design Choice:** Intermediate results are stored in dedicated registers rather than reusing the Register File, simplifying port management and avoiding structural hazards.

## Repository Structure

```
Hardware-1/
├── README.md                     # This file
├── project_instructions.pdf      # Original project specifications (Greek)
├── Hardware 1 Project REPORT.pdf # Final project report (Greek)
│
├── Default Files/                # Files provided by the instructor
│   ├── all_modules_together.sv
│   ├── nn_model.v                # Reference model for the neural network
│   └── rom.v                     # ROM module for weights/biases
│
├── final_files/                  # Final Verilog implementations
│   ├── alu.v                     # Exercise 1: ALU
│   ├── calc.v                    # Exercise 2: Calculator (top-level)
│   ├── calc_enc.v                # Exercise 2: Button-to-ALUop encoder
│   ├── calc_tb.v                 # Exercise 2: Testbench
│   ├── regfile.v                 # Exercise 3: Register File
│   ├── mac_unit.v                # Exercise 4: MAC Unit
│   ├── nn.v                      # Exercise 4: Neural Network (top-level)
│   ├── testbench_alu.v           # Exercise 1: Testbench
│   ├── testbench_regfile.v       # Exercise 3: Testbench
│   ├── tb_nn.v                   # Exercise 4: Main Testbench
│   ├── tb_nn_solo_testing.v      # Exercise 4: Alternative Testbench
│   └── results/                  # Simulation waveforms and console outputs (PNG)
│
└── Report Files/                 # LaTeX source and diagrams for the report
    ├── fsm.drawio                # FSM diagram source file
    └── REPORT.tex                # LaTeX source for the report
```

## Testing & Simulation Results

Each module was verified with a dedicated testbench.

| Module         | Testbench               | Key Tests                                                                                                |
| :------------- | :---------------------- | :------------------------------------------------------------------------------------------------------- |
| `alu.v`        | `testbench_alu.v`       | All 12 operations, positive/negative overflow for ADD/SUB/MUL, `zero` flag check.                        |
| `calc.v`       | `calc_tb.v`             | 9-step sequence from specifications (RESET, ADD, XOR, LSR, NOR, MULT, LSL, NAND, SUB). All tests passed. |
| `regfile.v`    | `testbench_regfile.v`   | Async reset, basic R/W, write collision priority, bypass logic, bypass collision priority.              |
| `nn.v`         | `tb_nn.v`               | 300 test cases (100 iterations x 3 input ranges) comparing against `nn_model.v` reference. **All 300/300 tests passed.** |

Simulation waveforms and console outputs are available in the [final_files/results/](final_files/results/) directory.

## How to Run

A Verilog simulator like **Icarus Verilog**, **ModelSim**, or **Vivado** is required.

**Example using Icarus Verilog:**

1.  **Navigate to the `final_files` directory:**
    ```bash
    cd final_files
    ```

2.  **Compile and run a testbench:**

    *   **ALU Testbench:**
        ```bash
        iverilog -g2012 -o alu_tb.out testbench_alu.v alu.v
        vvp alu_tb.out
        ```

    *   **Calculator Testbench:**
        ```bash
        iverilog -g2012 -o calc_tb.out calc_tb.v calc.v calc_enc.v alu.v
        vvp calc_tb.out
        ```

    *   **Register File Testbench:**
        ```bash
        iverilog -g2012 -o regfile_tb.out testbench_regfile.v regfile.v
        vvp regfile_tb.out
        ```

    *   **Neural Network Testbench:**
        ```bash
        # Copy rom.v and nn_model.v from Default Files first
        cp "../Default Files/rom.v" .
        cp "../Default Files/nn_model.v" .
        iverilog -g2012 -o nn_tb.out tb_nn.v nn.v mac_unit.v alu.v regfile.v rom.v nn_model.v
        vvp nn_tb.out
        ```

3.  **(Optional) View waveforms:** If your testbench generates a `.vcd` file, you can view it with GTKWave:
    ```bash
    gtkwave dump.vcd
    ```

