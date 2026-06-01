`timescale 1ns / 1ps
module tb_mac_channel();

    reg i_clk;
    reg i_rst_n;
    reg i_start;

    wire o_done;

    reg [13:0] nnz [0:3];
    reg [1:0] i_quarter_cnt;
    reg [15:0] i_addr_base;
    reg [7:0] i_scale_factor;
    reg [7:0] i_zero_point;
    reg [13:0] i_nnz;
    //weight memory interface
    wire [15:0] o_addr_wd;
    wire [8:0]  o_addr_row;
    wire [6:0]  o_addr_bias;
    wire [6:0]  o_addr_in, o_addr_in0, o_addr_in1, o_addr_in2, o_addr_in3;

    wire [6:0]  o_addr_tmp;
    wire        o_we_tmp;
    wire [31:0] o_data_tmp;
    wire [7:0] o_data_in;
    
    wire [14:0] i_data_wd;
    wire [6:0]  i_data_row;
    wire [31:0] i_data_bias;
    wire [7:0]  i_data_in,i_data_in0, i_data_in1, i_data_in2, i_data_in3;
    wire [31:0] i_data_tmp;

    wire o_en_wd, o_en_row, o_en_bias, o_en_in0, o_en_in1, o_en_in2, o_en_in3, o_en_in, o_en_tmp,o_we_in;
    wire [1:0] start_final_write;

        
    initial begin
        i_clk = 0;
        forever #10 i_clk = ~i_clk;
    end


    //메모리 5개
    //1. quantized weight memory(DATA) : 15비트[8비트 val][7비트 col idx], 최대 (128x128개)x4, 주소공간 16비트
    weight_data weight_data_mem (
        .clka(i_clk),            // input wire clka
        .rsta(!i_rst_n),            // input wire rsta
        .ena(o_en_wd),              // input wire ena
        .wea(1'b0),              // input wire [0 : 0] wea
        .addra(o_addr_wd),          // input wire [15 : 0] addra
        .dina(15'd0),            // input wire [14 : 0] dina
        .douta(i_data_wd),          // output wire [14 : 0] douta
        .rsta_busy()  // output wire rsta_busy
    );
    //2. row num memory(ROW) : 7비트, 주소공간 9비트
    weight_rownum weight_rownum_mem (
        .clka(i_clk),            // input wire clka
        .rsta(!i_rst_n),            // input wire rsta
        .ena(o_en_row),              // input wire ena
        .wea(1'b0),              // input wire [0 : 0] wea
        .addra(o_addr_row),          // input wire [8 : 0] addra
        .dina(7'd0),            // input wire [6 : 0] dina
        .douta(i_data_row),          // output wire [6 : 0] douta
        .rsta_busy()  // output wire rsta_busy
    );

    //3. q_bias memory(BIAS) : 32비트, 주소공간 7비트
    q_bias q_bias_mem (
        .clka(i_clk),            // input wire clka
        .rsta(!i_rst_n),            // input wire rsta
        .ena(o_en_bias),              // input wire ena
        .wea(1'b0),              // input wire [0 : 0] wea
        .addra(o_addr_bias),          // input wire [6 : 0] addra
        .dina(32'd0),            // input wire [31 : 0] dina
        .douta(i_data_bias),          // output wire [31 : 0] douta
        .rsta_busy()  // output wire rsta_busy
    );
    //4. input feature memory(COL) : 8비트, 주소공간 7비트
    input_vector input_vector0_mem (
        .clka(i_clk),            // input wire clka
        .rsta(!i_rst_n),            // input wire rsta
        .ena(o_en_in0),              // input wire ena
        .wea(o_we_in),              // input wire [0 : 0] wea
        .addra(o_addr_in0),          // input wire [6 : 0] addra
        .dina(o_data_in),            // input wire [7 : 0] dina
        .douta(i_data_in0),          // output wire [7 : 0] douta
        .rsta_busy()  // output wire rsta_busy
    );
    input_vector_1 input_vector1_mem (
        .clka(i_clk),            // input wire clka
        .rsta(!i_rst_n),            // input wire rsta
        .ena(o_en_in1),              // input wire ena
        .wea(1'b0),              // input wire [0 : 0] wea
        .addra(o_addr_in1),          // input wire [6 : 0] addra
        .dina(8'd0),            // input wire [7 : 0] dina
        .douta(i_data_in1),          // output wire [7 : 0] douta
        .rsta_busy()  // output wire rsta_busy
    );
    input_vector_2 input_vector2_mem (
        .clka(i_clk),            // input wire clka
        .rsta(!i_rst_n),            // input wire rsta
        .ena(o_en_in2),              // input wire ena
        .wea(1'b0),              // input wire [0 : 0] wea
        .addra(o_addr_in2),          // input wire [6 : 0] addra
        .dina(8'd0),            // input wire [7 : 0] dina
        .douta(i_data_in2),          // output wire [7 : 0] douta
        .rsta_busy()  // output wire rsta_busy
    );
    input_vector_3 input_vector3_mem (
        .clka(i_clk),            // input wire clka
        .rsta(!i_rst_n),            // input wire rsta
        .ena(o_en_in3),              // input wire ena
        .wea(1'b0),              // input wire [0 : 0] wea
        .addra(o_addr_in3),          // input wire [6 : 0] addra
        .dina(8'd0),            // input wire [7 : 0] dina
        .douta(i_data_in3),          // output wire [7 : 0] douta
        .rsta_busy()  // output wire rsta_busy
    );

    //5. output_tmp feature memory(TMP) : 32비트, 주소공간 7비트
    output_tmp output_tmp_mem (
        .clka(i_clk),            // input wire clka
        .rsta(!i_rst_n),            // input wire rsta
        .ena(o_en_tmp),              // input wire ena
        .wea(o_we_tmp),              // input wire [0 : 0] wea
        .addra(o_addr_tmp),          // input wire [6 : 0] addra
        .dina(o_data_tmp),            // input wire [31 : 0] dina
        .douta(i_data_tmp),          // output wire [31 : 0] douta
        .rsta_busy()  // output wire rsta_busy
    );

    csr_mac128x512 u_mac_128x512 (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_start(i_start),
        .o_done(o_done),
        .i_quarter_cnt(i_quarter_cnt),

        .i_addr_base(i_addr_base),
        .i_scale_factor(i_scale_factor),
        .i_zero_point(i_zero_point),
        .i_nnz(i_nnz),

        //weigth memory interface(data)-read_only
        .o_addr_wd(o_addr_wd), //virtuallized
        .o_en_wd(o_en_wd),
        .i_data_wd(i_data_wd),
        //weigth memory interface(row num)-read_only
        .o_addr_row(o_addr_row), //virtuallized
        .o_en_row(o_en_row),
        .i_data_row(i_data_row),
        //q_bias memory interface-read_only
        .o_addr_bias(o_addr_bias),
        .o_en_bias(o_en_bias),
        .i_data_bias(i_data_bias),

        //input feature memory interface(col)-read_and_write
        .o_addr_in(o_addr_in),
        .o_en_in(o_en_in),
        .o_we_in(o_we_in),
        .o_data_in(o_data_in),
        .i_data_in(i_data_in),

        //output_tmp feature memory interface-read_and_write
        .o_addr_tmp(o_addr_tmp),
        .o_en_tmp(o_en_tmp),
        .o_we_tmp(o_we_tmp),
        .o_data_tmp(o_data_tmp),
        .i_data_tmp(i_data_tmp),

        //signal
        .start_final_write(start_final_write)
    );
    
    //i_quarter에 따라 o_addr_in이 o_addr_in0~3까지 연결
    assign o_addr_in0 = (i_quarter_cnt==2'd0 && start_final_write==2'd0) ? o_addr_in : 
                        (start_final_write!=2'd0)                        ? o_addr_in :7'd0;
    assign o_addr_in1 = (i_quarter_cnt==2'd1 && start_final_write==2'd0) ? o_addr_in : 7'd0;
    assign o_addr_in2 = (i_quarter_cnt==2'd2 && start_final_write==2'd0) ? o_addr_in : 7'd0;
    assign o_addr_in3 = (i_quarter_cnt==2'd3 && start_final_write==2'd0) ? o_addr_in : 7'd0;

    
    assign o_en_in0 = (i_quarter_cnt==2'd0 && start_final_write==2'd0) ? o_en_in : 
                      (start_final_write!=2'd0)                        ? o_en_in :1'd0;
    assign o_en_in1 = (i_quarter_cnt==2'd1 && start_final_write==2'd0) ? o_en_in : 1'b0;
    assign o_en_in2 = (i_quarter_cnt==2'd2 && start_final_write==2'd0) ? o_en_in : 1'b0;
    assign o_en_in3 = (i_quarter_cnt==2'd3 && start_final_write==2'd0) ? o_en_in : 1'b0;



    assign i_data_in = (i_quarter_cnt==2'd0 && start_final_write==2'd0) ? i_data_in0 :
                       (i_quarter_cnt==2'd1 && start_final_write==2'd0) ? i_data_in1 :
                       (i_quarter_cnt==2'd2 && start_final_write==2'd0) ? i_data_in2 :
                       (i_quarter_cnt==2'd3 && start_final_write==2'd0) ? i_data_in3 :
                       8'd0;

    

    initial begin
        i_rst_n = 0;
        i_start = 0;
        nnz[0] = 14'd933;
        nnz[1] = 14'd907;
        nnz[2] = 14'd891;
        nnz[3] = 14'd897;
        i_quarter_cnt = 2'd0;
        i_addr_base = 16'd0;
        i_scale_factor = 8'd135;
        i_zero_point = 8'h80;
        i_nnz= nnz[0];
        
        
        #50;
        i_rst_n = 1;
        #110;
        i_start = 1;
        #20;
        i_start = 0;
        wait(o_done==1'b1);
        #110;
        
        i_quarter_cnt = 2'd1;
        i_addr_base = nnz[0];
        i_nnz= nnz[1];
        i_start = 1;
        #20;
        i_start = 0;
        wait(o_done==1'b1);
        #110;
        
        i_quarter_cnt = 2'd2;
        i_nnz= nnz[2];
        i_addr_base = nnz[0] + nnz[1];
        i_start = 1;
        #20;
        i_start = 0;
        wait(o_done==1'b1);
        #110;
        
         i_quarter_cnt = 2'd3;
         i_nnz= nnz[3];
         i_addr_base = nnz[0] + nnz[1] + nnz[2];
         i_start = 1;
         #20;
         i_start = 0;
         wait(o_done==1'b1);
         #110;
         
         
         
         i_start = 1;
         #20;
         i_start = 0;
         
         wait(o_done==1'b1);
         #110;


        $finish;
    end




endmodule
