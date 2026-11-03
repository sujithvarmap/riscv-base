`timescale 1ns/1ps

module reg_file (
    input         clk,
    input         rst,
    input  [4:0]  rs1,
    input  [4:0]  rs2,
    input  [4:0]  rd,
    input  [31:0] wd,
    input         we,
    output [31:0] rd1,
    output [31:0] rd2
);
    reg [31:0] rf [31:0];
    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                rf[i] <= 32'd0;
        end else if (we && (rd != 5'd0)) begin
            rf[rd] <= wd;
        end
    end

    assign rd1 = (rs1 == 5'd0)       ? 32'd0 :
                 (we && (rd == rs1)) ? wd    : rf[rs1];
    assign rd2 = (rs2 == 5'd0)       ? 32'd0 :
                 (we && (rd == rs2)) ? wd    : rf[rs2];
endmodule

