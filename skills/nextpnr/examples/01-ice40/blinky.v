module blinky (input wire clk, output wire led);
    reg [23:0] cnt = 0;
    always @(posedge clk) cnt <= cnt + 1'b1;
    assign led = cnt[23];
endmodule
