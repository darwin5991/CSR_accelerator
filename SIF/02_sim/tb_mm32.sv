`timescale 1ns / 1ps

module tb_mm32;
    // (1) clock define
    reg     clk;
    initial begin
        clk = 0;
        forever #(10) clk=~clk;
    end
    
    // (2) signal define
    wire            tester_cen;
    wire            tester_wen;
    wire    [10:0]  tester_addr; // [변경] 11비트 주소
    wire    [31:0]  tester_din;
    wire    [31:0]  tester_dout;
    
    wire            tester_rstn;
    wire            tester_matmul_en;
    wire    [2:0]   tester_fl;
    wire            tester_done;

    // (3) DUT: custom_matmul32x32 연결
    custom_matmul32x32 DUT (
        .i_clk          (clk),
        .i_cen          (tester_cen),
        .i_wen          (tester_wen),
        .i_addr         (tester_addr),
        .i_din          (tester_din),
        .o_dout         (tester_dout),
        
        .i_rstn         (tester_rstn),
        .i_matmul_en    (tester_matmul_en),
        .i_fl           (tester_fl),
        .o_done         (tester_done)
    );

    // (4) Tester: mm_tester32 연결
    mm_tester32 tester (
        .i_clk          (clk),
        .o_cen          (tester_cen),
        .o_wen          (tester_wen),
        .o_addr         (tester_addr),
        .o_din          (tester_din),
        .i_dout         (tester_dout), // tester 입력으로 들어감
        
        .o_rstn         (tester_rstn),
        .o_matmul_en    (tester_matmul_en),
        .o_fl           (tester_fl),
        .i_done         (tester_done)
    );

endmodule