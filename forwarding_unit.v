`timescale 1ns/1ps

module forwarding_unit (
    input  [4:0] ex_rs1,
    input  [4:0] ex_rs2,
    input  [4:0] mem_rd,
    input        mem_reg_write,
    input  [4:0] wb_rd,
    input        wb_reg_write,
    output reg [1:0] forward_a,
    output reg [1:0] forward_b
);
    always @(*) begin
        forward_a = 2'b00;
        forward_b = 2'b00;

        // Forward from MEM stage
        if (mem_reg_write && (mem_rd != 5'd0) && (mem_rd == ex_rs1))
            forward_a = 2'b10;
        if (mem_reg_write && (mem_rd != 5'd0) && (mem_rd == ex_rs2))
            forward_b = 2'b10;

        // Forward from WB stage (only if MEM isn't already forwarding)
        if (wb_reg_write && (wb_rd != 5'd0) &&
            !(mem_reg_write && (mem_rd != 5'd0) && (mem_rd == ex_rs1)) &&
            (wb_rd == ex_rs1))
            forward_a = 2'b01;

        if (wb_reg_write && (wb_rd != 5'd0) &&
            !(mem_reg_write && (mem_rd != 5'd0) && (mem_rd == ex_rs2)) &&
            (wb_rd == ex_rs2))
            forward_b = 2'b01;
    end
endmodule

