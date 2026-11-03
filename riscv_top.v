`timescale 1ns/1ps

module riscv_top (
    input        clk,
    input        rst,
    output [7:0] led
);

    // --- Signals & wires ---
    reg  [31:0] pc;
    wire [31:0] pc_next, pc_plus_4;
    wire [31:0] inst;

    // IF/ID
    wire [31:0] id_pc, id_inst;

    // Decode
    wire branch, mem_read, mem_to_reg, mem_write, alu_src, reg_write;
    wire [1:0] alu_op;
    wire [31:0] rd1, rd2, imm_val;

    // EX
    wire ex_reg_write, ex_mem_to_reg, ex_mem_read, ex_mem_write, ex_alu_src;
    wire [1:0] ex_alu_op;
    wire [31:0] ex_rd1, ex_rs2_data, ex_imm;
    wire [4:0] ex_rs1_addr, ex_rs2_addr, ex_rd_addr;

    // MEM
    wire mem_reg_write, mem_mem_to_reg, mem_mem_read, mem_mem_write;
    wire [31:0] mem_alu_result, mem_write_data;
    wire [4:0] mem_rd_addr;

    // WB
    wire wb_reg_write, wb_mem_to_reg;
    wire [31:0] wb_read_data, wb_alu_result;
    wire [4:0] wb_rd_addr;
    wire [31:0] write_data_wb;

    // Hazard & forwarding
    wire stall, flush;
    wire [1:0] forward_a, forward_b;
    wire [31:0] alu_in1, alu_in2_pre, alu_in2, alu_result;
    wire zero;
    reg  [3:0] alu_control;

    // Extra ID/EX info (branch + ALU decode)
    reg        ex_branch;
    reg [2:0]  ex_funct3;
    reg        ex_funct7_5;
    reg        ex_is_rtype;
    reg [31:0] ex_pc;

    wire id_is_rtype = (id_inst[6:0] == 7'b0110011);

    // Branch resolution (EX stage): beq / bne
    wire eq           = (alu_in1 == alu_in2_pre);
    wire branch_taken = ex_branch & ((ex_funct3 == 3'b000) ?  eq :
                                     (ex_funct3 == 3'b001) ? ~eq :
                                                             1'b0);

    // Data memory read data
    wire [31:0] mem_read_data;

    // --- Instruction memory: loaded from program.mem ---
    reg [31:0] imem [0:255];
    integer k;
    initial begin
        for (k = 0; k < 256; k = k + 1) imem[k] = 32'h00000013; // NOPs
        $readmemh("program.mem", imem);
    end

    // --- 1. Fetch (IF) ---
    always @(posedge clk or posedge rst) begin
        if (rst)
            pc <= 32'd0;
        else if (!stall)
            pc <= pc_next;
    end

    assign pc_plus_4 = pc + 32'd4;
    assign pc_next   = branch_taken ? (ex_pc + ex_imm) : pc_plus_4;
    assign inst      = imem[pc[9:2]];
    assign flush     = branch_taken;

    // --- Data memory ---
    reg [31:0] dmem [0:255];
    integer j;
    initial begin
        for (j = 0; j < 256; j = j + 1) dmem[j] = 32'd0;
    end

    always @(posedge clk) begin
        if (mem_mem_write)
            dmem[mem_alu_result[9:2]] <= mem_write_data;
    end

    assign mem_read_data = mem_mem_read ? dmem[mem_alu_result[9:2]] : 32'd0;

    // Output so synthesis keeps the design: low 8 bits of the stored result
    assign led = dmem[0][7:0];

    // --- 2. Pipeline registers ---
    pipeline_regs pipe_regs (
        .clk(clk), .rst(rst), .flush(flush), .stall(stall),

        // IF -> ID
        .if_pc(pc), .if_inst(inst),
        .id_pc(id_pc), .id_inst(id_inst),

        // ID -> EX
        .id_reg_write(reg_write), .id_mem_to_reg(mem_to_reg), .id_mem_read(mem_read),
        .id_mem_write(mem_write), .id_alu_op(alu_op), .id_alu_src(alu_src),
        .id_rd1(rd1), .id_rs2_data(rd2), .id_imm(imm_val),
        .id_rs1_addr(id_inst[19:15]), .id_rs2_addr(id_inst[24:20]), .id_rd_addr(id_inst[11:7]),

        .ex_reg_write(ex_reg_write), .ex_mem_to_reg(ex_mem_to_reg), .ex_mem_read(ex_mem_read),
        .ex_mem_write(ex_mem_write), .ex_alu_op(ex_alu_op), .ex_alu_src(ex_alu_src),
        .ex_rd1(ex_rd1), .ex_rs2_data(ex_rs2_data), .ex_imm(ex_imm),
        .ex_rs1_addr(ex_rs1_addr), .ex_rs2_addr(ex_rs2_addr), .ex_rd_addr(ex_rd_addr),

        // EX -> MEM
        .ex_mem_reg_write(ex_reg_write), .ex_mem_mem_to_reg(ex_mem_to_reg),
        .ex_mem_mem_read(ex_mem_read), .ex_mem_mem_write(ex_mem_write),
        .ex_mem_alu_result(alu_result), .ex_mem_write_data(alu_in2_pre), .ex_mem_rd_addr(ex_rd_addr),

        .mem_reg_write(mem_reg_write), .mem_mem_to_reg(mem_mem_to_reg),
        .mem_mem_read(mem_mem_read), .mem_mem_write(mem_mem_write),
        .mem_alu_result(mem_alu_result), .mem_write_data(mem_write_data), .mem_rd_addr(mem_rd_addr),

        // MEM -> WB
        .mem_wb_reg_write(mem_reg_write), .mem_wb_mem_to_reg(mem_mem_to_reg),
        .mem_wb_read_data(mem_read_data), .mem_wb_alu_result(mem_alu_result), .mem_wb_rd_addr(mem_rd_addr),

        .wb_reg_write(wb_reg_write), .wb_mem_to_reg(wb_mem_to_reg),
        .wb_read_data(wb_read_data), .wb_alu_result(wb_alu_result), .wb_rd_addr(wb_rd_addr)
    );

    // Extra ID/EX registers (same flush/stall behaviour as pipeline_regs)
    always @(posedge clk or posedge rst) begin
        if (rst || flush || stall) begin
            ex_branch   <= 1'b0;
            ex_funct3   <= 3'd0;
            ex_funct7_5 <= 1'b0;
            ex_is_rtype <= 1'b0;
            ex_pc       <= 32'd0;
        end else begin
            ex_branch   <= branch;
            ex_funct3   <= id_inst[14:12];
            ex_funct7_5 <= id_inst[30];
            ex_is_rtype <= id_is_rtype;
            ex_pc       <= id_pc;
        end
    end

    // --- 3. Decode (ID) ---
    control_unit ctrl (
        .opcode(id_inst[6:0]),
        .branch(branch), .mem_read(mem_read), .mem_to_reg(mem_to_reg),
        .alu_op(alu_op), .mem_write(mem_write), .alu_src(alu_src), .reg_write(reg_write)
    );

    reg_file rf (
        .clk(clk), .rst(rst),
        .rs1(id_inst[19:15]), .rs2(id_inst[24:20]),
        .rd(wb_rd_addr), .wd(write_data_wb), .we(wb_reg_write),
        .rd1(rd1), .rd2(rd2)
    );

    imm_gen ig (
        .inst(id_inst), .imm(imm_val)
    );

    // --- 4. Execute (EX) ---
    assign alu_in1 = (forward_a == 2'b10) ? mem_alu_result :
                     (forward_a == 2'b01) ? write_data_wb :
                     ex_rd1;

    assign alu_in2_pre = (forward_b == 2'b10) ? mem_alu_result :
                         (forward_b == 2'b01) ? write_data_wb :
                         ex_rs2_data;

    assign alu_in2 = ex_alu_src ? ex_imm : alu_in2_pre;

    // ALU control: funct3/funct7 decoding
    always @(*) begin
        case (ex_alu_op)
            2'b00: alu_control = 4'b0000;           // ADD (load/store)
            2'b01: alu_control = 4'b0001;           // SUB (branch)
            default: begin                          // R-type / I-type ALU
                case (ex_funct3)
                    3'b000: alu_control = (ex_is_rtype && ex_funct7_5) ? 4'b0001  // SUB
                                                                       : 4'b0000; // ADD/ADDI
                    3'b001: alu_control = 4'b0101;                                // SLL
                    3'b010: alu_control = 4'b1000;                                // SLT
                    3'b011: alu_control = 4'b1001;                                // SLTU
                    3'b100: alu_control = 4'b0100;                                // XOR
                    3'b101: alu_control = ex_funct7_5 ? 4'b0111 : 4'b0110;        // SRA : SRL
                    3'b110: alu_control = 4'b0011;                                // OR
                    3'b111: alu_control = 4'b0010;                                // AND
                    default: alu_control = 4'b0000;
                endcase
            end
        endcase
    end

    alu execution_unit (
        .a(alu_in1), .b(alu_in2),
        .alu_control(alu_control),
        .result(alu_result), .zero(zero)
    );

    // --- 5. Writeback (WB) ---
    assign write_data_wb = wb_mem_to_reg ? wb_read_data : wb_alu_result;

    // --- Hazard & forwarding units ---
    hazard_unit hazard_detection (
        .id_ex_mem_read(ex_mem_read),
        .id_ex_rd(ex_rd_addr),
        .if_id_rs1(id_inst[19:15]),
        .if_id_rs2(id_inst[24:20]),
        .stall(stall)
    );

    forwarding_unit forward_logic (
        .ex_rs1(ex_rs1_addr), .ex_rs2(ex_rs2_addr),
        .mem_rd(mem_rd_addr), .mem_reg_write(mem_reg_write),
        .wb_rd(wb_rd_addr), .wb_reg_write(wb_reg_write),
        .forward_a(forward_a), .forward_b(forward_b)
    );

endmodule

