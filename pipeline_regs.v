`timescale 1ns/1ps

module pipeline_regs (
    input clk,
    input rst,
    input flush,
    input stall,

    // IF/ID
    input  [31:0] if_pc,
    input  [31:0] if_inst,
    output reg [31:0] id_pc,
    output reg [31:0] id_inst,

    // ID/EX
    input         id_reg_write,
    input         id_mem_to_reg,
    input         id_mem_read,
    input         id_mem_write,
    input  [1:0]  id_alu_op,
    input         id_alu_src,
    input  [31:0] id_rd1,
    input  [31:0] id_rs2_data,
    input  [31:0] id_imm,
    input  [4:0]  id_rs1_addr,
    input  [4:0]  id_rs2_addr,
    input  [4:0]  id_rd_addr,

    output reg        ex_reg_write,
    output reg        ex_mem_to_reg,
    output reg        ex_mem_read,
    output reg        ex_mem_write,
    output reg [1:0]  ex_alu_op,
    output reg        ex_alu_src,
    output reg [31:0] ex_rd1,
    output reg [31:0] ex_rs2_data,
    output reg [31:0] ex_imm,
    output reg [4:0]  ex_rs1_addr,
    output reg [4:0]  ex_rs2_addr,
    output reg [4:0]  ex_rd_addr,

    // EX/MEM
    input         ex_mem_reg_write,
    input         ex_mem_mem_to_reg,
    input         ex_mem_mem_read,
    input         ex_mem_mem_write,
    input  [31:0] ex_mem_alu_result,
    input  [31:0] ex_mem_write_data,
    input  [4:0]  ex_mem_rd_addr,

    output reg        mem_reg_write,
    output reg        mem_mem_to_reg,
    output reg        mem_mem_read,
    output reg        mem_mem_write,
    output reg [31:0] mem_alu_result,
    output reg [31:0] mem_write_data,
    output reg [4:0]  mem_rd_addr,

    // MEM/WB
    input         mem_wb_reg_write,
    input         mem_wb_mem_to_reg,
    input  [31:0] mem_wb_read_data,
    input  [31:0] mem_wb_alu_result,
    input  [4:0]  mem_wb_rd_addr,

    output reg        wb_reg_write,
    output reg        wb_mem_to_reg,
    output reg [31:0] wb_read_data,
    output reg [31:0] wb_alu_result,
    output reg [4:0]  wb_rd_addr
);

    // IF/ID
    always @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            id_pc   <= 32'd0;
            id_inst <= 32'd0;
        end else if (!stall) begin
            id_pc   <= if_pc;
            id_inst <= if_inst;
        end
    end

    // ID/EX
    always @(posedge clk or posedge rst) begin
        if (rst || flush || stall) begin
            ex_reg_write  <= 1'b0;
            ex_mem_to_reg <= 1'b0;
            ex_mem_read   <= 1'b0;
            ex_mem_write  <= 1'b0;
            ex_alu_op     <= 2'b00;
            ex_alu_src    <= 1'b0;
            ex_rd1        <= 32'd0;
            ex_rs2_data   <= 32'd0;
            ex_imm        <= 32'd0;
            ex_rs1_addr   <= 5'd0;
            ex_rs2_addr   <= 5'd0;
            ex_rd_addr    <= 5'd0;
        end else begin
            ex_reg_write  <= id_reg_write;
            ex_mem_to_reg <= id_mem_to_reg;
            ex_mem_read   <= id_mem_read;
            ex_mem_write  <= id_mem_write;
            ex_alu_op     <= id_alu_op;
            ex_alu_src    <= id_alu_src;
            ex_rd1        <= id_rd1;
            ex_rs2_data   <= id_rs2_data;
            ex_imm        <= id_imm;
            ex_rs1_addr   <= id_rs1_addr;
            ex_rs2_addr   <= id_rs2_addr;
            ex_rd_addr    <= id_rd_addr;
        end
    end

    // EX/MEM
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mem_reg_write  <= 1'b0;
            mem_mem_to_reg <= 1'b0;
            mem_mem_read   <= 1'b0;
            mem_mem_write  <= 1'b0;
            mem_alu_result <= 32'd0;
            mem_write_data <= 32'd0;
            mem_rd_addr    <= 5'd0;
        end else begin
            mem_reg_write  <= ex_mem_reg_write;
            mem_mem_to_reg <= ex_mem_mem_to_reg;
            mem_mem_read   <= ex_mem_mem_read;
            mem_mem_write  <= ex_mem_mem_write;
            mem_alu_result <= ex_mem_alu_result;
            mem_write_data <= ex_mem_write_data;
            mem_rd_addr    <= ex_mem_rd_addr;
        end
    end

    // MEM/WB
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wb_reg_write  <= 1'b0;
            wb_mem_to_reg <= 1'b0;
            wb_read_data  <= 32'd0;
            wb_alu_result <= 32'd0;
            wb_rd_addr    <= 5'd0;
        end else begin
            wb_reg_write  <= mem_wb_reg_write;
            wb_mem_to_reg <= mem_wb_mem_to_reg;
            wb_read_data  <= mem_wb_read_data;
            wb_alu_result <= mem_wb_alu_result;
            wb_rd_addr    <= mem_wb_rd_addr;
        end
    end

endmodule

