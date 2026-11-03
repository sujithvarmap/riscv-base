`timescale 1ns/1ps

module tb_riscv;
    reg clk = 0, rst = 1;
    wire [7:0] led;

    riscv_top dut (.clk(clk), .rst(rst), .led(led));

    always #5 clk = ~clk;

    initial begin
        #20 rst = 0;
        #3000;
        $display("result = %0d", dut.dmem[0]);
        if (dut.dmem[0] == 32'd120) $display("PASS");
        else                        $display("FAIL");
        $finish;
    end
endmodule
