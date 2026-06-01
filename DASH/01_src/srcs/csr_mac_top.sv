module csr_mac_top (
    input  logic        i_clk,
    input  logic        i_rst_n,

    input  logic        i_start,
    output logic        o_done,

    input  logic [1:0]  i_quarter_cnt,
    input  logic [7:0]  i_scale_factor,
    input  logic [7:0]  i_zero_point,
    input logic [1:0] i_layer_num,

    // data initialization interface
    input logic i_init_mode,

    input logic [7:0] i_tb_input0_data, i_tb_input1_data, i_tb_input2_data, i_tb_input3_data,
    input logic [6:0] i_tb_input0_addr, i_tb_input1_addr, i_tb_input2_addr, i_tb_input3_addr,
    input logic i_tb_input0_we, i_tb_input1_we, i_tb_input2_we, i_tb_input3_we,

    input logic [14:0] i_tb_weight0_data, i_tb_weight1_data, i_tb_weight2_data, i_tb_weight3_data,
    input logic [15:0] i_tb_weight0_addr, i_tb_weight1_addr, i_tb_weight2_addr, i_tb_weight3_addr,
    input logic i_tb_weight0_we, i_tb_weight1_we, i_tb_weight2_we, i_tb_weight3_we,

    input logic [6:0] i_tb_rownum0_data, i_tb_rownum1_data, i_tb_rownum2_data, i_tb_rownum3_data,
    input logic [8:0] i_tb_rownum0_addr, i_tb_rownum1_addr, i_tb_rownum2_addr, i_tb_rownum3_addr,
    input logic i_tb_rownum0_we, i_tb_rownum1_we, i_tb_rownum2_we, i_tb_rownum3_we,

    input logic [31:0] i_tb_bias0_data, i_tb_bias1_data, i_tb_bias2_data, i_tb_bias3_data,
    input logic [6:0] i_tb_bias0_addr, i_tb_bias1_addr, i_tb_bias2_addr, i_tb_bias3_addr,
    input logic i_tb_bias0_we, i_tb_bias1_we, i_tb_bias2_we, i_tb_bias3_we

);
    logic [6:0] o_addr_in_0, o_addr_in_1, o_addr_in_2, o_addr_in_3;
    logic [6:0] o_addr_in0, o_addr_in1, o_addr_in2, o_addr_in3;
    logic       o_en_in_0,   o_en_in_1,   o_en_in_2,   o_en_in_3;
    logic       o_we_in_0,   o_we_in_1,   o_we_in_2,   o_we_in_3;
    logic [7:0] o_data_in_0, o_data_in_1, o_data_in_2, o_data_in_3;
    logic [7:0] o_data_in0, o_data_in1, o_data_in2, o_data_in3;
    logic [7:0] i_data_in0, i_data_in1, i_data_in2, i_data_in3;
    logic [7:0] i_data_in_0, i_data_in_1, i_data_in_2, i_data_in_3;

    //4. input feature memory(COL) : 8비트, 주소공간 7비트
    input_vector input_vector0_mem (
        .clka(i_clk),            // input wire clka
        .rsta(!i_rst_n),            // input wire rsta
        .ena(o_en_in_0),              // input wire ena
        .wea(o_we_in_0),              // input wire [0 : 0] wea
        .addra(o_addr_in_0),          // input wire [6 : 0] addra
        .dina(o_data_in_0),            // input wire [7 : 0] dina
        .douta(i_data_in_0),          // output wire [7 : 0] douta
        .rsta_busy()  // output wire rsta_busy
    );
    always_comb begin
        // Rule 8: 기본값 설정 (Latch 방지)
        o_addr_in_0 = 7'd0; o_en_in_0 = 1'b0; o_we_in_0 = 1'b0; o_data_in_0 = 8'd0;
        i_data_in0  = 8'd0;

        if (i_init_mode) begin
            o_addr_in_0 = i_tb_input0_addr;
            o_en_in_0   = 1'b1;
            o_we_in_0   = i_tb_input0_we;
            o_data_in_0 = i_tb_input0_data;
            i_data_in0  = 8'd0; // PE 입력은 0으로 고정
        end else begin
            case(i_quarter_cnt)
                2'd0: begin
                    o_addr_in_0 = o_addr_in0; o_en_in_0 = o_en_in0; o_we_in_0 = o_we_in0; o_data_in_0 = o_data_in0;
                    i_data_in0  = i_data_in_0;
                end
                2'd1: begin
                    o_addr_in_0 = o_addr_in3; o_en_in_0 = o_en_in3; o_we_in_0 = o_we_in3; o_data_in_0 = o_data_in3;
                    i_data_in0  = i_data_in_1;
                end
                2'd2: begin
                    o_addr_in_0 = o_addr_in2; o_en_in_0 = o_en_in2; o_we_in_0 = o_we_in2; o_data_in_0 = o_data_in2;
                    i_data_in0  = i_data_in_2;
                end
                2'd3: begin
                    if (o_we_in0 == 1'b0 && o_we_in1 == 1'b0 && o_we_in2 == 1'b0 && o_we_in3 == 1'b0) begin
                        o_addr_in_0 = o_addr_in1; o_en_in_0 = o_en_in1; o_we_in_0 = o_we_in1; o_data_in_0 = o_data_in1;
                        i_data_in0  = i_data_in_3;
                    end else begin
                        o_addr_in_0 = o_addr_in0; o_en_in_0 = o_en_in0; o_we_in_0 = o_we_in0; o_data_in_0 = o_data_in0;
                        i_data_in0  = i_data_in_0;
                    end
                end
                default: begin
                    o_addr_in_0 = o_addr_in0; o_en_in_0 = o_en_in0; o_we_in_0 = o_we_in0; o_data_in_0 = o_data_in0;
                    i_data_in0  = i_data_in_0;
                end
            endcase
        end
    end
    input_vector_1 input_vector1_mem (
        .clka(i_clk),            // input wire clka
        .rsta(!i_rst_n),            // input wire rsta
        .ena(o_en_in_1),              // input wire ena
        .wea(o_we_in_1),              // input wire [0 : 0] wea
        .addra(o_addr_in_1),          // input wire [6 : 0] addra
        .dina(o_data_in_1),            // input wire [7 : 0] dina
        .douta(i_data_in_1),          // output wire [7 : 0] douta
        .rsta_busy()  // output wire rsta_busy
    );
    always_comb begin
        o_addr_in_1 = 7'd0; o_en_in_1 = 1'b0; o_we_in_1 = 1'b0; o_data_in_1 = 8'd0;
        i_data_in1  = 8'd0;

        if (i_init_mode) begin
            o_addr_in_1 = i_tb_input1_addr;
            o_en_in_1   = 1'b1;
            o_we_in_1   = i_tb_input1_we;
            o_data_in_1 = i_tb_input1_data;
            i_data_in1  = 8'd0;
        end else begin
            case(i_quarter_cnt)
                2'd0: begin
                    o_addr_in_1 = o_addr_in1; o_en_in_1 = o_en_in1; o_we_in_1 = o_we_in1; o_data_in_1 = o_data_in1;
                    i_data_in1  = i_data_in_1;
                end
                2'd1: begin
                    o_addr_in_1 = o_addr_in0; o_en_in_1 = o_en_in0; o_we_in_1 = o_we_in0; o_data_in_1 = o_data_in0;
                    i_data_in1  = i_data_in_2;
                end
                2'd2: begin
                    o_addr_in_1 = o_addr_in3; o_en_in_1 = o_en_in3; o_we_in_1 = o_we_in3; o_data_in_1 = o_data_in3;
                    i_data_in1  = i_data_in_3;
                end
                2'd3: begin
                    if (o_we_in0 == 1'b0 && o_we_in1 == 1'b0 && o_we_in2 == 1'b0 && o_we_in3 == 1'b0) begin
                        o_addr_in_1 = o_addr_in2; o_en_in_1 = o_en_in2; o_we_in_1 = o_we_in2; o_data_in_1 = o_data_in2;
                        i_data_in1  = i_data_in_0;
                    end else begin
                        o_addr_in_1 = o_addr_in1; o_en_in_1 = o_en_in1; o_we_in_1 = o_we_in1; o_data_in_1 = o_data_in1;
                        i_data_in1  = i_data_in_1;
                    end
                end
                default: begin
                    o_addr_in_1 = o_addr_in1; o_en_in_1 = o_en_in1; o_we_in_1 = o_we_in1; o_data_in_1 = o_data_in1;
                    i_data_in1  = i_data_in_1;
                end
            endcase
        end
    end
    input_vector_2 input_vector2_mem (
        .clka(i_clk),            // input wire clka
        .rsta(!i_rst_n),            // input wire rsta
        .ena(o_en_in_2),              // input wire ena
        .wea(o_we_in_2),              // input wire [0 : 0] wea
        .addra(o_addr_in_2),          // input wire [6 : 0] addra
        .dina(o_data_in_2),            // input wire [7 : 0] dina
        .douta(i_data_in_2),          // output wire [7 : 0] douta
        .rsta_busy()  // output wire rsta_busy
    );
    always_comb begin
        o_addr_in_2 = 7'd0; o_en_in_2 = 1'b0; o_we_in_2 = 1'b0; o_data_in_2 = 8'd0;
        i_data_in2  = 8'd0;

        if (i_init_mode) begin
            o_addr_in_2 = i_tb_input2_addr;
            o_en_in_2   = 1'b1;
            o_we_in_2   = i_tb_input2_we;
            o_data_in_2 = i_tb_input2_data;
            i_data_in2  = 8'd0;
        end else begin
            case(i_quarter_cnt)
                2'd0: begin
                    o_addr_in_2 = o_addr_in2; o_en_in_2 = o_en_in2; o_we_in_2 = o_we_in2; o_data_in_2 = o_data_in2;
                    i_data_in2  = i_data_in_2;
                end
                2'd1: begin
                    o_addr_in_2 = o_addr_in1; o_en_in_2 = o_en_in1; o_we_in_2 = o_we_in1; o_data_in_2 = o_data_in1;
                    i_data_in2  = i_data_in_3;
                end
                2'd2: begin
                    o_addr_in_2 = o_addr_in0; o_en_in_2 = o_en_in0; o_we_in_2 = o_we_in0; o_data_in_2 = o_data_in0;
                    i_data_in2  = i_data_in_0;
                end
                2'd3: begin
                    if (o_we_in0 == 1'b0 && o_we_in1 == 1'b0 && o_we_in2 == 1'b0 && o_we_in3 == 1'b0) begin
                        o_addr_in_2 = o_addr_in3; o_en_in_2 = o_en_in3; o_we_in_2 = o_we_in3; o_data_in_2 = o_data_in3;
                        i_data_in2  = i_data_in_1;
                    end else begin
                        o_addr_in_2 = o_addr_in2; o_en_in_2 = o_en_in2; o_we_in_2 = o_we_in2; o_data_in_2 = o_data_in2;
                        i_data_in2  = i_data_in_2;
                    end
                end
                default: begin
                    o_addr_in_2 = o_addr_in2; o_en_in_2 = o_en_in2; o_we_in_2 = o_we_in2; o_data_in_2 = o_data_in2;
                    i_data_in2  = i_data_in_2;
                end
            endcase
        end
    end
    input_vector_3 input_vector3_mem (
        .clka(i_clk),            // input wire clka
        .rsta(!i_rst_n),            // input wire rsta
        .ena(o_en_in_3),              // input wire ena
        .wea(o_we_in_3),              // input wire [0 : 0] wea
        .addra(o_addr_in_3),          // input wire [6 : 0] addra
        .dina(o_data_in_3),            // input wire [7 : 0] dina
        .douta(i_data_in_3),          // output wire [7 : 0] douta
        .rsta_busy()  // output wire rsta_busy
    );
    always_comb begin
        o_addr_in_3 = 7'd0; o_en_in_3 = 1'b0; o_we_in_3 = 1'b0; o_data_in_3 = 8'd0;
        i_data_in3  = 8'd0;

        if (i_init_mode) begin
            o_addr_in_3 = i_tb_input3_addr;
            o_en_in_3   = 1'b1;
            o_we_in_3   = i_tb_input3_we;
            o_data_in_3 = i_tb_input3_data;
            i_data_in3  = 8'd0;
        end else begin
            case(i_quarter_cnt)
                2'd0: begin
                    o_addr_in_3 = o_addr_in3; o_en_in_3 = o_en_in3; o_we_in_3 = o_we_in3; o_data_in_3 = o_data_in3;
                    i_data_in3  = i_data_in_3;
                end
                2'd1: begin
                    o_addr_in_3 = o_addr_in2; o_en_in_3 = o_en_in2; o_we_in_3 = o_we_in2; o_data_in_3 = o_data_in2;
                    i_data_in3  = i_data_in_0;
                end
                2'd2: begin
                    o_addr_in_3 = o_addr_in1; o_en_in_3 = o_en_in1; o_we_in_3 = o_we_in1; o_data_in_3 = o_data_in1;
                    i_data_in3  = i_data_in_1;
                end
                2'd3: begin
                    if (o_we_in0 == 1'b0 && o_we_in1 == 1'b0 && o_we_in2 == 1'b0 && o_we_in3 == 1'b0) begin
                        o_addr_in_3 = o_addr_in0; o_en_in_3 = o_en_in0; o_we_in_3 = o_we_in0; o_data_in_3 = o_data_in0;
                        i_data_in3  = i_data_in_2;
                    end else begin
                        o_addr_in_3 = o_addr_in3; o_en_in_3 = o_en_in3; o_we_in_3 = o_we_in3; o_data_in_3 = o_data_in3;
                        i_data_in3  = i_data_in_3;
                    end
                end
                default: begin
                    o_addr_in_3 = o_addr_in3; o_en_in_3 = o_en_in3; o_we_in_3 = o_we_in3; o_data_in_3 = o_data_in3;
                    i_data_in3  = i_data_in_3;
                end
            endcase
        end
    end


    // // data initialization interface
    // input  logic        i_init_mode, // 1: TB 초기화 모드, 0: 정상 동작 모드

    // // 1. Weight Memory Init Ports (Data: 15b, Addr: 16b)
    // input  logic [14:0] i_tb_weight_data,
    // input  logic [15:0] i_tb_weight_addr,
    // input  logic        i_tb_weight_we,

    // // 2. Row_num Memory Init Ports (Data: 7b, Addr: 9b)
    // input  logic [6:0]  i_tb_rownum_data,
    // input  logic [8:0]  i_tb_rownum_addr,
    // input  logic        i_tb_rownum_we,

    // // 3. Q_bias Memory Init Ports (Data: 32b, Addr: 7b)
    // input  logic [31:0] i_tb_bias_data,
    // input  logic [6:0]  i_tb_bias_addr,
    // input  logic        i_tb_bias_we
    PE_128x512 u_PE0(
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_start(i_start),

    .o_done(o_done0),

    .i_quarter_cnt(i_quarter_cnt),
    .i_scale_factor(i_scale_factor),
    .i_zero_point(i_zero_point),
    .i_layer_num(i_layer_num),
    .i_pe_num(2'd0),
    
    //input_vector interface
    .o_addr_in(o_addr_in0),
    .o_en_in(o_en_in0),
    .o_we_in(o_we_in0),
    .o_data_in(o_data_in0),
    .i_data_in(i_data_in0),

    //data initialization interface
    .i_init_mode(i_init_mode),
    
    .i_tb_weight_data(i_tb_weight0_data),
    .i_tb_weight_addr(i_tb_weight0_addr),
    .i_tb_weight_we(i_tb_weight0_we),

    .i_tb_rownum_data(i_tb_rownum0_data),
    .i_tb_rownum_addr(i_tb_rownum0_addr),
    .i_tb_rownum_we(i_tb_rownum0_we),

    .i_tb_bias_data(i_tb_bias0_data),
    .i_tb_bias_addr(i_tb_bias0_addr),
    .i_tb_bias_we(i_tb_bias0_we)
    );

    PE1_128x512 u_PE1(
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_start(i_start),

    .o_done(o_done1),

    .i_quarter_cnt(i_quarter_cnt),
    .i_scale_factor(i_scale_factor),
    .i_zero_point(i_zero_point),
    .i_layer_num(i_layer_num),
    .i_pe_num(2'd1),

    //input_vector interface
    .o_addr_in(o_addr_in1),
    .o_en_in(o_en_in1),
    .o_we_in(o_we_in1),
    .o_data_in(o_data_in1),
    .i_data_in(i_data_in1),

    //data initialization interface
    .i_init_mode(i_init_mode),
    
    .i_tb_weight_data(i_tb_weight1_data),
    .i_tb_weight_addr(i_tb_weight1_addr),
    .i_tb_weight_we(i_tb_weight1_we),

    .i_tb_rownum_data(i_tb_rownum1_data),
    .i_tb_rownum_addr(i_tb_rownum1_addr),
    .i_tb_rownum_we(i_tb_rownum1_we),
    
    .i_tb_bias_data(i_tb_bias1_data),
    .i_tb_bias_addr(i_tb_bias1_addr),
    .i_tb_bias_we(i_tb_bias1_we)
    );

    PE2_128x512 u_PE2(
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_start(i_start),

    .o_done(o_done2),

    .i_quarter_cnt(i_quarter_cnt),
    .i_scale_factor(i_scale_factor),
    .i_zero_point(i_zero_point),
    .i_layer_num(i_layer_num),
    .i_pe_num(2'd2),

    //input_vector interface
    .o_addr_in(o_addr_in2),
    .o_en_in(o_en_in2),
    .o_we_in(o_we_in2),
    .o_data_in(o_data_in2),
    .i_data_in(i_data_in2),

    //data initialization interface
    .i_init_mode(i_init_mode),
    
    .i_tb_weight_data(i_tb_weight2_data),
    .i_tb_weight_addr(i_tb_weight2_addr),
    .i_tb_weight_we(i_tb_weight2_we),

    .i_tb_rownum_data(i_tb_rownum2_data),
    .i_tb_rownum_addr(i_tb_rownum2_addr),
    .i_tb_rownum_we(i_tb_rownum2_we),
    
    .i_tb_bias_data(i_tb_bias2_data),
    .i_tb_bias_addr(i_tb_bias2_addr),
    .i_tb_bias_we(i_tb_bias2_we)
    );

    PE3_128x512 u_PE3(
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_start(i_start),

    .o_done(o_done3),

    .i_quarter_cnt(i_quarter_cnt),
    .i_scale_factor(i_scale_factor),
    .i_zero_point(i_zero_point),
    .i_layer_num(i_layer_num),
    .i_pe_num(2'd3),

    //input_vector interface
    .o_addr_in(o_addr_in3),
    .o_en_in(o_en_in3),
    .o_we_in(o_we_in3),
    .o_data_in(o_data_in3),
    .i_data_in(i_data_in3),

    //data initialization interface
    .i_init_mode(i_init_mode),
    
    .i_tb_weight_data(i_tb_weight3_data),
    .i_tb_weight_addr(i_tb_weight3_addr),
    .i_tb_weight_we(i_tb_weight3_we),

    .i_tb_rownum_data(i_tb_rownum3_data),
    .i_tb_rownum_addr(i_tb_rownum3_addr),
    .i_tb_rownum_we(i_tb_rownum3_we),
    
    .i_tb_bias_data(i_tb_bias3_data),
    .i_tb_bias_addr(i_tb_bias3_addr),
    .i_tb_bias_we(i_tb_bias3_we)
    );


    //i_quarter_cnt에 따라 input_vector 인터페이스 연결
    //i_quarter_cnt==3이면 같은 숫자끼리 연결  예)o_addr_in3과 o_addr_in_3, o_en_in3과 o_en_in_3
    //i_quarter_cnt==2이면 그 다음 숫자끼리 연결
    //i_quarter_cnt==1이면 그 다음 숫자끼리 연결
    //i_quarter_cnt==0이면 그 다음 숫자끼리 연결

   
    // always_comb begin
    //     // 기본값 설정 (Latch 방지)
    //     o_addr_in_0 = 7'd0; o_en_in_0 = '0; o_we_in_0 = '0; o_data_in_0 = '0;
    //     o_addr_in_1 = 7'd0; o_en_in_1 = '0; o_we_in_1 = '0; o_data_in_1 = '0;
    //     o_addr_in_2 = 7'd0; o_en_in_2 = '0; o_we_in_2 = '0; o_data_in_2 = '0;
    //     o_addr_in_3 = 7'd0; o_en_in_3 = '0; o_we_in_3 = '0; o_data_in_3 = '0;
    //     i_data_in0 = 8'd0; i_data_in1 = 8'd0; i_data_in2 = 8'd0; i_data_in3 = 8'd0;

    //     case(i_quarter_cnt)
    //         // Case 0: Identity Connection (같은 숫자끼리: PE0<->Mem0, PE1<->Mem1 ...)
    //         2'd0: begin
    //             // PE0 <-> Mem0
    //             o_addr_in_0 = o_addr_in0; 
    //             o_en_in_0 = o_en_in0; 
    //             o_we_in_0 = o_we_in0; 
    //             o_data_in_0 = o_data_in0;
    //             i_data_in0  = i_data_in_0;
    //             // PE1 <-> Mem1
    //             o_addr_in_1 = o_addr_in1; 
    //             o_en_in_1 = o_en_in1; 
    //             o_we_in_1 = o_we_in1; 
    //             o_data_in_1 = o_data_in1;
    //             i_data_in1  = i_data_in_1;
    //             // PE2 <-> Mem2
    //             o_addr_in_2 = o_addr_in2; 
    //             o_en_in_2 = o_en_in2; 
    //             o_we_in_2 = o_we_in2; 
    //             o_data_in_2 = o_data_in2;
    //             i_data_in2  = i_data_in_2;
    //             // PE3 <-> Mem3
    //             o_addr_in_3 = o_addr_in3; 
    //             o_en_in_3 = o_en_in3; 
    //             o_we_in_3 = o_we_in3; 
    //             o_data_in_3 = o_data_in3;
    //             i_data_in3  = i_data_in_3;
    //         end

    //         // Case 1: Shift +1 (그 다음 숫자: PE0->Mem1, PE1->Mem2 ...)
    //         2'd1: begin
    //             // PE0 -> Mem1
    //             o_addr_in_1 = o_addr_in0; 
    //             o_en_in_1 = o_en_in0; 
    //             o_we_in_1 = o_we_in0; 
    //             o_data_in_1 = o_data_in0;
    //             i_data_in0  = i_data_in_1;
    //             // PE1 -> Mem2
    //             o_addr_in_2 = o_addr_in1; 
    //             o_en_in_2 = o_en_in1; 
    //             o_we_in_2 = o_we_in1; 
    //             o_data_in_2 = o_data_in1;
    //             i_data_in1  = i_data_in_2;
    //             // PE2 -> Mem3
    //             o_addr_in_3 = o_addr_in2; 
    //             o_en_in_3 = o_en_in2; 
    //             o_we_in_3 = o_we_in2; 
    //             o_data_in_3 = o_data_in2;
    //             i_data_in2  = i_data_in_3;
    //             // PE3 -> Mem0
    //             o_addr_in_0 = o_addr_in3; 
    //             o_en_in_0 = o_en_in3; 
    //             o_we_in_0 = o_we_in3; 
    //             o_data_in_0 = o_data_in3;
    //             i_data_in3  = i_data_in_0;
    //         end

    //         // Case 2: Shift +2 (그 다음 숫자: PE0->Mem2, PE1->Mem3 ...)
    //         2'd2: begin
    //             // PE0 -> Mem2
    //             o_addr_in_2 = o_addr_in0; 
    //             o_en_in_2 = o_en_in0; 
    //             o_we_in_2 = o_we_in0; 
    //             o_data_in_2 = o_data_in0;
    //             i_data_in0  = i_data_in_2;
    //             // PE1 -> Mem3
    //             o_addr_in_3 = o_addr_in1; 
    //             o_en_in_3 = o_en_in1; 
    //             o_we_in_3 = o_we_in1; 
    //             o_data_in_3 = o_data_in1;
    //             i_data_in1  = i_data_in_3;
    //             // PE2 -> Mem0
    //             o_addr_in_0 = o_addr_in2; 
    //             o_en_in_0 = o_en_in2; 
    //             o_we_in_0 = o_we_in2;
    //             o_data_in_0 = o_data_in2;
    //             i_data_in2  = i_data_in_0;
    //             // PE3 -> Mem1
    //             o_addr_in_1 = o_addr_in3; 
    //             o_en_in_1 = o_en_in3; 
    //             o_we_in_1 = o_we_in3; 
    //             o_data_in_1 = o_data_in3;
    //             i_data_in3  = i_data_in_1;
    //         end

    //         // Case 3: Shift +3 (그 다음 숫자: PE0->Mem3, PE1->Mem0 ...)
    //         2'd3: begin
    //             if(o_we_in0==0 && o_we_in1==0 && o_we_in2==0 && o_we_in3==0) begin
    //                 // PE0 -> Mem3
    //                 o_addr_in_3 = o_addr_in0; 
    //                 o_en_in_3 = o_en_in0; 
    //                 o_we_in_3 = o_we_in0; 
    //                 o_data_in_3 = o_data_in0;
    //                 i_data_in0  = i_data_in_3;
    //                 // PE1 -> Mem0
    //                 o_addr_in_0 = o_addr_in1; 
    //                 o_en_in_0 = o_en_in1; 
    //                 o_we_in_0 = o_we_in1; 
    //                 o_data_in_0 = o_data_in1;
    //                 i_data_in1  = i_data_in_0;
    //                 // PE2 -> Mem1
    //                 o_addr_in_1 = o_addr_in2; 
    //                 o_en_in_1 = o_en_in2; 
    //                 o_we_in_1 = o_we_in2; 
    //                 o_data_in_1 = o_data_in2;
    //                 i_data_in2  = i_data_in_1;
    //                 // PE3 -> Mem2
    //                 o_addr_in_2 = o_addr_in3; 
    //                 o_en_in_2 = o_en_in3; 
    //                 o_we_in_2 = o_we_in3; 
    //                 o_data_in_2 = o_data_in3;
    //                 i_data_in3  = i_data_in_2;
    //             end
    //             else begin
    //                 // PE0 <-> Mem0
    //                 o_addr_in_0 = o_addr_in0; 
    //                 o_en_in_0 = o_en_in0; 
    //                 o_we_in_0 = o_we_in0; 
    //                 o_data_in_0 = o_data_in0;
    //                 i_data_in0  = i_data_in_0;
    //                 // PE1 <-> Mem1
    //                 o_addr_in_1 = o_addr_in1; 
    //                 o_en_in_1 = o_en_in1; 
    //                 o_we_in_1 = o_we_in1; 
    //                 o_data_in_1 = o_data_in1;
    //                 i_data_in1  = i_data_in_1;
    //                 // PE2 <-> Mem2
    //                 o_addr_in_2 = o_addr_in2; 
    //                 o_en_in_2 = o_en_in2; 
    //                 o_we_in_2 = o_we_in2; 
    //                 o_data_in_2 = o_data_in2;
    //                 i_data_in2  = i_data_in_2;
    //                 // PE3 <-> Mem3
    //                 o_addr_in_3 = o_addr_in3; 
    //                 o_en_in_3 = o_en_in3; 
    //                 o_we_in_3 = o_we_in3; 
    //                 o_data_in_3 = o_data_in3;
    //                 i_data_in3  = i_data_in_3;
    //             end
    //         end

    //         default: begin
    //             // Default Case (Identity와 동일하게 처리하여 안전성 확보)
    //             o_addr_in_0 = o_addr_in0; o_en_in_0 = o_en_in0; o_we_in_0 = o_we_in0; o_data_in_0 = o_data_in0;
    //             i_data_in0  = i_data_in_0;
    //             o_addr_in_1 = o_addr_in1; o_en_in_1 = o_en_in1; o_we_in_1 = o_we_in1; o_data_in_1 = o_data_in1;
    //             i_data_in1  = i_data_in_1;
    //             o_addr_in_2 = o_addr_in2; o_en_in_2 = o_en_in2; o_we_in_2 = o_we_in2; o_data_in_2 = o_data_in2;
    //             i_data_in2  = i_data_in_2;
    //             o_addr_in_3 = o_addr_in3; o_en_in_3 = o_en_in3; o_we_in_3 = o_we_in3; o_data_in_3 = o_data_in3;
    //             i_data_in3  = i_data_in_3;
    //         end
    //     endcase
    // end


    assign o_done= o_done0 & o_done1 & o_done2 & o_done3;
    









endmodule