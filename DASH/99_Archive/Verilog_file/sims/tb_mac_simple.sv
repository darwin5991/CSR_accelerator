`timescale 1ns / 1ps
module tb_mac_simple();

    reg i_clk;
    reg i_rst_n;
    reg i_start;

    wire o_done;
    //weight memory interface
    wire [13:0] o_addr_wd_virt;
    wire [6:0]  o_addr_row_virt;
    wire [6:0]  o_addr_bias;
    wire [6:0]  o_addr_in;
    wire [6:0]  o_addr_tmp;
    wire        o_we_tmp;
    wire [31:0] o_data_tmp;
    wire [14:0] i_data_wd;
    wire [6:0]  i_data_row;
    wire [31:0] i_data_bias;
    wire [7:0]  i_data_in;
    wire [31:0] i_data_tmp;

        
    initial begin
        i_clk = 0;
        forever #10 i_clk = ~i_clk;
    end


    //메모리 5개
    //1. quantized weight memory(DATA) : 15비트[8비트 val][7비트 col idx], 최대 128x128개, 주소공간 14비트
    weight_data weight_data_mem (
        .clka(i_clk),            // input wire clka
        .rsta(!i_rst_n),            // input wire rsta
        .ena(1'b1),              // input wire ena
        .wea(1'b0),              // input wire [0 : 0] wea
        .addra(o_addr_wd_virt),          // input wire [13 : 0] addra
        .dina(15'd0),            // input wire [14 : 0] dina
        .douta(i_data_wd),          // output wire [14 : 0] douta
        .rsta_busy()  // output wire rsta_busy
    );
    //2. row num memory(ROW) : 7비트, 주소공간 7비트
    weight_rownum weight_rownum_mem (
        .clka(i_clk),            // input wire clka
        .rsta(!i_rst_n),            // input wire rsta
        .ena(1'b1),              // input wire ena
        .wea(1'b0),              // input wire [0 : 0] wea
        .addra(o_addr_row_virt),          // input wire [6 : 0] addra
        .dina(7'd0),            // input wire [6 : 0] dina
        .douta(i_data_row),          // output wire [6 : 0] douta
        .rsta_busy()  // output wire rsta_busy
    );

    //3. q_bias memory(BIAS) : 32비트, 주소공간 7비트
    q_bias q_bias_mem (
        .clka(i_clk),            // input wire clka
        .rsta(!i_rst_n),            // input wire rsta
        .ena(1'b1),              // input wire ena
        .wea(1'b0),              // input wire [0 : 0] wea
        .addra(o_addr_bias),          // input wire [6 : 0] addra
        .dina(32'd0),            // input wire [31 : 0] dina
        .douta(i_data_bias),          // output wire [31 : 0] douta
        .rsta_busy()  // output wire rsta_busy
    );
    //4. input feature memory(COL) : 8비트, 주소공간 7비트
    input_vector input_vector_mem (
        .clka(i_clk),            // input wire clka
        .rsta(!i_rst_n),            // input wire rsta
        .ena(1'b1),              // input wire ena
        .wea(1'b0),              // input wire [0 : 0] wea
        .addra(o_addr_in),          // input wire [6 : 0] addra
        .dina(8'd0),            // input wire [7 : 0] dina
        .douta(i_data_in),          // output wire [7 : 0] douta
        .rsta_busy()  // output wire rsta_busy
    );
    //5. output_tmp feature memory(TMP) : 32비트, 주소공간 7비트
    output_tmp output_tmp_mem (
        .clka(i_clk),            // input wire clka
        .rsta(!i_rst_n),            // input wire rsta
        .ena(1'b1),              // input wire ena
        .wea(o_we_tmp),              // input wire [0 : 0] wea
        .addra(o_addr_tmp),          // input wire [6 : 0] addra
        .dina(o_data_tmp),            // input wire [31 : 0] dina
        .douta(i_data_tmp),          // output wire [31 : 0] douta
        .rsta_busy()  // output wire rsta_busy
    );

    //mac 128x128
    mac_128x128 u_mac_128x128 (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_start(i_start),
        .o_done(o_done),
        .i_quarter_cnt(2'b00), // input메모리 읽어서 tmp에 저장.
        .i_nnz(14'd933),
        //weigth memory interface(data)
        .o_addr_wd(o_addr_wd_virt),
        .o_en_wd(),
        .i_data_wd(i_data_wd),
        //weigth memory interface(row num)
        .o_addr_row(o_addr_row_virt),
        .o_en_row(),
        .i_data_row(i_data_row),
//        //q_bias memory interface
//        .o_addr_bias(o_addr_bias),
//        .o_en_bias(),
//        .i_data_bias(i_data_bias),
        //input feature memory interface(col)
        .o_addr_in(o_addr_in),
        .o_en_in(),
        .i_data_in(i_data_in),
        //output_tmp feature memory interface
        .o_addr_tmp(o_addr_tmp),
        .o_en_tmp(),
        .o_we_tmp(o_we_tmp),
        .o_data_tmp(o_data_tmp),
        .i_data_tmp(i_data_tmp)
    );

    initial begin
        i_rst_n = 0;
        i_start = 0;
        #50;
        i_rst_n = 1;
        #110;
        i_start = 1;
        #20;
        i_start = 0;
        wait(o_done==1'b1);
        #100;
        $finish;
    end




endmodule
