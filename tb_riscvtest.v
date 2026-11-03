`timescale 1ns / 1ps

module tb_riscv();
    reg clk = 0;
    reg rst = 1;

    riscv_top dut (.clk(clk), .rst(rst));

    always #5 clk = ~clk;

    initial begin
        #20 rst = 0;
        #3000;
        
        $display("dmem[0] = %0d", dut.dmem[0]);
        
        $finish;
    end
endmodule
