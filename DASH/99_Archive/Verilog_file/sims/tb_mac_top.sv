`timescale 1ns / 1ps

module tb_mac_top;

    localparam IN_DEPTH   = 128;   // 7-bit addr
    localparam WT_DEPTH   = 65536; // 16-bit addr
    localparam ROW_DEPTH  = 512;   // 9-bit addr
    localparam BIAS_DEPTH = 128;   // 7-bit addr

    reg i_clk;
    reg i_rst_n;
    reg i_start;
    wire o_done;

    
    reg [7:0]  i_scale_factor;
    reg [7:0]  i_zero_point;
    reg [1:0] i_quarter_cnt;
    reg [1:0] i_layer_num;

    initial begin
        i_clk = 0;
        forever #10 i_clk = ~i_clk;
    end


    // // data initialization interface
    reg i_init_mode;

    reg [7:0] i_tb_input0_data, i_tb_input1_data, i_tb_input2_data, i_tb_input3_data;
    reg [6:0] i_tb_input0_addr, i_tb_input1_addr, i_tb_input2_addr, i_tb_input3_addr;
    reg i_tb_input0_we, i_tb_input1_we, i_tb_input2_we, i_tb_input3_we;

    reg [14:0] i_tb_weight0_data, i_tb_weight1_data, i_tb_weight2_data, i_tb_weight3_data;
    reg [15:0] i_tb_weight0_addr, i_tb_weight1_addr, i_tb_weight2_addr, i_tb_weight3_addr;
    reg i_tb_weight0_we, i_tb_weight1_we, i_tb_weight2_we, i_tb_weight3_we;

    reg [6:0] i_tb_rownum0_data, i_tb_rownum1_data, i_tb_rownum2_data, i_tb_rownum3_data;
    reg [8:0] i_tb_rownum0_addr, i_tb_rownum1_addr, i_tb_rownum2_addr, i_tb_rownum3_addr;
    reg i_tb_rownum0_we, i_tb_rownum1_we, i_tb_rownum2_we, i_tb_rownum3_we;

    reg [31:0] i_tb_bias0_data, i_tb_bias1_data, i_tb_bias2_data, i_tb_bias3_data;
    reg [6:0] i_tb_bias0_addr, i_tb_bias1_addr, i_tb_bias2_addr, i_tb_bias3_addr;
    reg i_tb_bias0_we, i_tb_bias1_we, i_tb_bias2_we, i_tb_bias3_we;

    reg [7:0]  tb_mem_input0  [0:IN_DEPTH-1];
    reg [7:0]  tb_mem_input1  [0:IN_DEPTH-1];
    reg [7:0]  tb_mem_input2  [0:IN_DEPTH-1];
    reg [7:0]  tb_mem_input3  [0:IN_DEPTH-1];

    reg [14:0] tb_mem_weight0 [0:WT_DEPTH-1];
    reg [14:0] tb_mem_weight1 [0:WT_DEPTH-1];
    reg [14:0] tb_mem_weight2 [0:WT_DEPTH-1];
    reg [14:0] tb_mem_weight3 [0:WT_DEPTH-1];

    reg [6:0]  tb_mem_rownum0 [0:ROW_DEPTH-1];
    reg [6:0]  tb_mem_rownum1 [0:ROW_DEPTH-1];
    reg [6:0]  tb_mem_rownum2 [0:ROW_DEPTH-1];
    reg [6:0]  tb_mem_rownum3 [0:ROW_DEPTH-1];

    reg [31:0] tb_mem_bias0   [0:BIAS_DEPTH-1];
    reg [31:0] tb_mem_bias1   [0:BIAS_DEPTH-1];
    reg [31:0] tb_mem_bias2   [0:BIAS_DEPTH-1];
    reg [31:0] tb_mem_bias3   [0:BIAS_DEPTH-1];

    csr_mac_top u_csr_mac_top(
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),

        .i_start(i_start),
        .o_done(o_done),

        .i_quarter_cnt(i_quarter_cnt),
        .i_scale_factor(i_scale_factor),
        .i_zero_point(i_zero_point),
        .i_layer_num(i_layer_num),

        // data initialization interface
        .i_init_mode(i_init_mode), // TB 초기화 모드
        .i_tb_input0_data(i_tb_input0_data), .i_tb_input1_data(i_tb_input1_data), .i_tb_input2_data(i_tb_input2_data), .i_tb_input3_data(i_tb_input3_data),
        .i_tb_input0_addr(i_tb_input0_addr), .i_tb_input1_addr(i_tb_input1_addr), .i_tb_input2_addr(i_tb_input2_addr), .i_tb_input3_addr(i_tb_input3_addr),
        .i_tb_input0_we(i_tb_input0_we), .i_tb_input1_we(i_tb_input1_we), .i_tb_input2_we(i_tb_input2_we), .i_tb_input3_we(i_tb_input3_we),

        .i_tb_weight0_data(i_tb_weight0_data), .i_tb_weight1_data(i_tb_weight1_data), .i_tb_weight2_data(i_tb_weight2_data), .i_tb_weight3_data(i_tb_weight3_data),
        .i_tb_weight0_addr(i_tb_weight0_addr), .i_tb_weight1_addr(i_tb_weight1_addr), .i_tb_weight2_addr(i_tb_weight2_addr), .i_tb_weight3_addr(i_tb_weight3_addr),
        .i_tb_weight0_we(i_tb_weight0_we), .i_tb_weight1_we(i_tb_weight1_we), .i_tb_weight2_we(i_tb_weight2_we), .i_tb_weight3_we(i_tb_weight3_we),

        .i_tb_rownum0_data(i_tb_rownum0_data), .i_tb_rownum1_data(i_tb_rownum1_data), .i_tb_rownum2_data(i_tb_rownum2_data), .i_tb_rownum3_data(i_tb_rownum3_data),
        .i_tb_rownum0_addr(i_tb_rownum0_addr), .i_tb_rownum1_addr(i_tb_rownum1_addr), .i_tb_rownum2_addr(i_tb_rownum2_addr), .i_tb_rownum3_addr(i_tb_rownum3_addr),
        .i_tb_rownum0_we(i_tb_rownum0_we), .i_tb_rownum1_we(i_tb_rownum1_we), .i_tb_rownum2_we(i_tb_rownum2_we), .i_tb_rownum3_we(i_tb_rownum3_we),

        .i_tb_bias0_data(i_tb_bias0_data), .i_tb_bias1_data(i_tb_bias1_data), .i_tb_bias2_data(i_tb_bias2_data), .i_tb_bias3_data(i_tb_bias3_data),
        .i_tb_bias0_addr(i_tb_bias0_addr), .i_tb_bias1_addr(i_tb_bias1_addr), .i_tb_bias2_addr(i_tb_bias2_addr), .i_tb_bias3_addr(i_tb_bias3_addr),
        .i_tb_bias0_we(i_tb_bias0_we), .i_tb_bias1_we(i_tb_bias1_we), .i_tb_bias2_we(i_tb_bias2_we), .i_tb_bias3_we(i_tb_bias3_we)

    );
    integer idx;

    initial begin
        $readmemh("input_mem_0.mem", tb_mem_input0);
        $readmemh("input_mem_1.mem", tb_mem_input1);
        $readmemh("input_mem_2.mem", tb_mem_input2);
        $readmemh("input_mem_3.mem", tb_mem_input3);

        $readmemh("qw_data_mem_0.mem", tb_mem_weight0);
        $readmemh("qw_data_mem_1.mem", tb_mem_weight1);
        $readmemh("qw_data_mem_2.mem", tb_mem_weight2);
        $readmemh("qw_data_mem_3.mem", tb_mem_weight3);

        $readmemh("row_num_mem_0.mem", tb_mem_rownum0);
        $readmemh("row_num_mem_1.mem", tb_mem_rownum1);
        $readmemh("row_num_mem_2.mem", tb_mem_rownum2);
        $readmemh("row_num_mem_3.mem", tb_mem_rownum3);
        
        $readmemh("q_bias_mem_0.mem", tb_mem_bias0);
        $readmemh("q_bias_mem_1.mem", tb_mem_bias1);
        $readmemh("q_bias_mem_2.mem", tb_mem_bias2);
        $readmemh("q_bias_mem_3.mem", tb_mem_bias3);

        i_rst_n = 0;
        i_start = 0;
       
        // i_scale_factor = 8'd124;
        i_scale_factor = 8'd52;
        i_zero_point = 8'h80;
        i_quarter_cnt = 2'd0;
        i_layer_num = 2'd0;

        i_init_mode = 1'b1; // 초기화 모드 활성화
        i_tb_input0_we = 0; i_tb_weight0_we = 0; i_tb_rownum0_we = 0; i_tb_bias0_we = 0;
        i_tb_input1_we = 0; i_tb_weight1_we = 0; i_tb_rownum1_we = 0; i_tb_bias1_we = 0;
        i_tb_input2_we = 0; i_tb_weight2_we = 0; i_tb_rownum2_we = 0; i_tb_bias2_we = 0;
        i_tb_input3_we = 0; i_tb_weight3_we = 0; i_tb_rownum3_we = 0; i_tb_bias3_we = 0;


        
        #50;
        i_rst_n = 1;
        #110;


        for (idx = 0; idx < WT_DEPTH; idx = idx + 1) begin
            @(negedge i_clk) begin
                // Weight Memory (전체 구간 Write)
                i_tb_weight0_we  = 1'b1;
                i_tb_weight1_we  = 1'b1;
                i_tb_weight2_we  = 1'b1;
                i_tb_weight3_we  = 1'b1;

                i_tb_weight0_addr = idx[15:0];
                i_tb_weight1_addr = idx[15:0];
                i_tb_weight2_addr = idx[15:0];
                i_tb_weight3_addr = idx[15:0];

                i_tb_weight0_data = tb_mem_weight0[idx];
                i_tb_weight1_data = tb_mem_weight1[idx];
                i_tb_weight2_data = tb_mem_weight2[idx];
                i_tb_weight3_data = tb_mem_weight3[idx];

                // Input & Bias Memory (깊이 128까지만 Write)
                if (idx < IN_DEPTH) begin
                    i_tb_input0_we   = 1'b1;
                    i_tb_input1_we   = 1'b1;
                    i_tb_input2_we   = 1'b1;
                    i_tb_input3_we   = 1'b1;

                    i_tb_input0_addr = idx[6:0];
                    i_tb_input1_addr = idx[6:0];
                    i_tb_input2_addr = idx[6:0];
                    i_tb_input3_addr = idx[6:0];

                    i_tb_input0_data  = tb_mem_input0[idx];
                    i_tb_input1_data  = tb_mem_input1[idx];
                    i_tb_input2_data  = tb_mem_input2[idx];
                    i_tb_input3_data  = tb_mem_input3[idx];

                    i_tb_bias0_we    = 1'b1;
                    i_tb_bias1_we    = 1'b1;
                    i_tb_bias2_we    = 1'b1;
                    i_tb_bias3_we    = 1'b1;

                    i_tb_bias0_addr   = idx[6:0];
                    i_tb_bias1_addr   = idx[6:0];
                    i_tb_bias2_addr   = idx[6:0];
                    i_tb_bias3_addr   = idx[6:0];

                    i_tb_bias0_data   = tb_mem_bias0[idx];
                    i_tb_bias1_data   = tb_mem_bias1[idx];
                    i_tb_bias2_data   = tb_mem_bias2[idx];
                    i_tb_bias3_data   = tb_mem_bias3[idx];

                end else begin
                    i_tb_input0_we   = 1'b0;
                    i_tb_input1_we   = 1'b0;
                    i_tb_input2_we   = 1'b0;
                    i_tb_input3_we   = 1'b0;
                    i_tb_bias0_we    = 1'b0;
                    i_tb_bias1_we    = 1'b0;
                    i_tb_bias2_we    = 1'b0;
                    i_tb_bias3_we    = 1'b0;
                end

                // Row_num Memory (깊이 512까지만 Write)
                if (idx < ROW_DEPTH) begin
                    i_tb_rownum0_we  = 1'b1;
                    i_tb_rownum1_we  = 1'b1;
                    i_tb_rownum2_we  = 1'b1;
                    i_tb_rownum3_we  = 1'b1;

                    i_tb_rownum0_addr = idx[8:0];
                    i_tb_rownum1_addr = idx[8:0];
                    i_tb_rownum2_addr = idx[8:0];
                    i_tb_rownum3_addr = idx[8:0];

                    i_tb_rownum0_data = tb_mem_rownum0[idx];
                    i_tb_rownum1_data = tb_mem_rownum1[idx];
                    i_tb_rownum2_data = tb_mem_rownum2[idx];
                    i_tb_rownum3_data = tb_mem_rownum3[idx];
                end else begin
                    i_tb_rownum0_we  = 1'b0;
                    i_tb_rownum1_we  = 1'b0;
                    i_tb_rownum2_we  = 1'b0;
                    i_tb_rownum3_we  = 1'b0;
                end
            end
        end

        // 마지막 사이클에서 Weight Write Disable 및 NPU 동작 모드로 전환
        @(negedge i_clk) begin
            i_tb_weight0_we = 1'b0;
            i_tb_weight1_we = 1'b0;
            i_tb_weight2_we = 1'b0;
            i_tb_weight3_we = 1'b0;
            i_init_mode      = 1'b0; // [중요] NPU 정상 동작 모드 전환
        end
        repeat(5) @(negedge i_clk);
        $stop;


        #100;

        @(negedge i_clk);
        i_start = 1;
        #20;
        i_start = 0;
        wait(o_done==1'b1);
        @(negedge i_clk);
        $stop;
        #100;

        repeat(5) @(negedge i_clk);
        i_quarter_cnt = 2'd1;  
        i_start = 1;
        #20;
        i_start = 0;
        wait(o_done==1'b1);
        @(negedge i_clk);
        $stop;
        #100;

        repeat(5) @(negedge i_clk);
        i_quarter_cnt = 2'd2;
        i_start = 1;
        #20;
        i_start = 0;
        wait(o_done==1'b1);
        @(negedge i_clk);
        $stop;
        #100;


        repeat(5) @(negedge i_clk);
        i_quarter_cnt = 2'd3;
        i_start = 1;
        #20;
        i_start = 0;
        wait(o_done==1'b1);
        @(negedge i_clk);
        $stop;
        #100;
        

        repeat(5) @(negedge i_clk);
        i_start = 1;
        #20;
        i_start = 0;
        wait(o_done==1'b1);
        
        repeat(5) @(negedge i_clk);
        #100;


        $finish;

    
    
    end


endmodule