module csr_mac128x512 (
    input  logic        i_clk,
    input  logic        i_rst_n,

    input  logic        i_start,
    output logic        o_done,
    input logic [1:0]  i_quarter_cnt,
    input logic [15:0] i_addr_base,
    input logic [8:0]   i_addr_base_row,
    input logic [7:0] i_scale_factor,
    input logic [7:0] i_zero_point,
    input logic [13:0] i_nnz,

    //weigth memory interface(data)-read_only
    output logic [15:0] o_addr_wd, //virtuallized
    output logic        o_en_wd,
    input  logic [14:0] i_data_wd,
    //weigth memory interface(row num)-read_only
    output logic [8:0] o_addr_row, //virtuallized
    output logic        o_en_row,
    input  logic [6:0] i_data_row,
    //q_bias memory interface-read_only
    output logic [6:0] o_addr_bias,
    output logic        o_en_bias,
    input  logic [31:0] i_data_bias,

    //input feature memory interface(col)-read_and_write
    output logic [6:0] o_addr_in, //virtuallized
    output logic        o_en_in,
    output logic        o_we_in,
    output logic [7:0] o_data_in,
    input  logic [7:0] i_data_in,

    //output_tmp feature memory interface-read_and_write
    output logic [6:0] o_addr_tmp,
    output logic        o_en_tmp,
    output logic        o_we_tmp,
    output logic [31:0] o_data_tmp,
    input  logic [31:0] i_data_tmp,

    // signal
    output logic [1:0] start_final_write

);

    wire [13:0] o_addr_wd_virt;
    wire [6:0] o_addr_row_virt;
    wire [6:0] o_addr_in_virt;
    wire [6:0] o_addr_tmp_1;



    assign o_addr_wd = {1'b0, o_addr_wd_virt} + {i_addr_base};
    assign o_addr_row= {1'b0, o_addr_row_virt}+ {i_addr_base_row};

    
    // reg [1:0] start_final_write; 
    wire o_we_tmp_1;
    wire [31:0] o_data_tmp_1;
    assign o_en_in = (start_final_write==2'd2)? 1'b0 : 1'b1;
    assign o_we_in = (start_final_write==2'd0)? 1'b0 : 1'b1;

    assign o_we_tmp= (start_final_write==2'd0)? o_we_tmp_1 : 
                     (start_final_write==2'd1)? 1'b0       :1'b1;
    assign o_data_tmp= (start_final_write==2'd0)?  o_data_tmp_1 : 
                       (start_final_write==2'd1)?  32'd1 :32'd0;
    
    assign o_en_wd=(start_final_write==2'd0)? 1'b1 : 1'b0;
    assign o_en_row=(start_final_write==2'd0)? 1'b1 : 1'b0;
    assign o_en_bias=(start_final_write==2'd0)? 1'b1 : 
                     (start_final_write==2'd1)? 1'b1 : 1'b0;

    assign o_en_tmp= (start_final_write==2'd0)? 1'b1 : 1'b1;

    // wire [6:0] o_addr_bias_r;

    mac_128x128 u_mac_128x128 (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_start(i_start),
        .o_done(o_done),
        .i_quarter_cnt(i_quarter_cnt),
        .i_nnz(i_nnz),
        //weigth memory interface(data)-read_only
        .o_addr_wd(o_addr_wd_virt),
        // .o_en_wd(),
        .i_data_wd(i_data_wd),
        //weigth memory interface(row num)-read_only
        .o_addr_row(o_addr_row_virt),
        // .o_en_row(),
        .i_data_row(i_data_row),
            // //q_bias memory interface-read_only
            // .o_addr_bias(o_addr_bias_r),
            // .o_en_bias(),
            // .i_data_bias(i_data_bias),
        //input feature memory interface(col)-read_only
        .o_addr_in(o_addr_in_virt),
        // .o_en_in(),
        .i_data_in(i_data_in),
        //output_tmp feature memory interface-read_and_write
        .o_addr_tmp(o_addr_tmp_1),
        // .o_en_tmp(),
        .o_we_tmp(o_we_tmp_1),
        .o_data_tmp(o_data_tmp_1),
        .i_data_tmp(i_data_tmp)
    );

    //i_quarter_cnt==3까지 모두 연산하고 나면
    //output_tmp 메모리에 저장된 값을 이용하여 최종 output을 계산, input_mem에 저장. 
    // 그 후 output_tmp는 0으로 초기화
    //o_addr_tmp, o_addr_in 모두 0부터 127까지 순차적으로 접근
    // o_en_tmp, o_en_in 모두 1
    // o_we_in 1, o_we_tmp 0


    //i_quarter_cnt==3이고 o_done이 0에서 1이 되면 start_final_write=2'd1 (최종 output을 계산, input_mem에 저장.)
    // start_final_write==2'd1이고 o_addr_in==7'd127이면 start_final_write=2'd2 (output_tmp 0으로 초기화)
    
    // start_final_write==2'd1이면 o_en_in=1, o_en_tmp=1, o_we_in=1, o_we_tmp=0
    // start_final_write==2'd2이면 o_en_in=0, o_en_tmp=1, o_we_in=0, o_we_tmp=1

    // start_final_write==2'd2이고 r_addr_final==7'd127이면 o_done<=1'b1;
    
    reg o_done_delay;
    reg wait_final;
    reg [6:0] r_addr_final;// tmp와 bias 같이 사용
    
    wire [31:0] w_mac_result;// i_dout_tmp+i_dout_bias
    assign w_mac_result = i_data_tmp + i_data_bias;
    wire [31:0] w_mac_result_ReLU;// w_mac_result의 MSB가 1이면 w_mac_result_ReLU=0
    assign w_mac_result_ReLU = (w_mac_result[31]==1'b1)? 32'd0 : w_mac_result;
    wire [31:0] w_scaled_result;// w_mac_result_ReLU * i_scale_factor
    assign w_scaled_result = w_mac_result_ReLU * i_scale_factor;
    wire [7:0] w_final_result;// i_scale_factor 곱하고 16비트 right_shift,i_zero_point 적용 후 하위 8비트만 할당
    wire [7:0] w_final_result_shifted;
    assign w_final_result_shifted = w_scaled_result[25:16];
    assign w_final_result = w_final_result_shifted + i_zero_point;
    

    reg [6:0] r_addr_in_final; //r_addr_final 1클럭 딜레이


    // o_addr_in과 o_addr_tmp,o_addr_bias도 start_final_write에 따라 muxing
    assign o_addr_in = (start_final_write==2'd0)? o_addr_in_virt : r_addr_in_final;
    assign o_addr_tmp= (start_final_write==2'd0)? o_addr_tmp_1 : r_addr_final;
    assign o_addr_bias= r_addr_final;
    assign o_data_in = (start_final_write==2'd0)? 8'd0 : w_final_result;
    
    always @(posedge i_clk or negedge i_rst_n) begin
        if(!i_rst_n) begin
            start_final_write <= 2'd0;
            o_done <= 1'b0;
            o_done_delay <= 1'b0;
            r_addr_final <= 7'd0;
            r_addr_in_final <= 7'd0;
            wait_final<=1'b0;
        end
        else begin
            o_done_delay <= o_done;
            //start_final_write 제어
            if((start_final_write==2'd0)&&(i_quarter_cnt==2'd3) && (o_done_delay==1'b0) && (o_done==1'b1)) begin
                wait_final<=1'b1;
            end
            else if(wait_final==1'b1&&i_start==1'b1) begin
                start_final_write <= 2'd1;
                r_addr_final <= 7'd0;
                o_done <= 1'b0;
            end
            else if((start_final_write==2'd1) && (r_addr_in_final==7'd127)) begin
                start_final_write <= 2'd2;
                // o_done <= 1'b1;
                r_addr_final <= 7'd0;
            end

            //o_done 제어
            else if((start_final_write==2'd2) && (r_addr_final==7'd127)) begin
                o_done <= 1'b1;
            end

            //r_addr_final 제어
            else if(start_final_write!=2'd0) begin
                r_addr_final <= r_addr_final + 7'd1;
                r_addr_in_final <= r_addr_final;
            end
            else begin
                r_addr_final <= 7'd0;
                r_addr_in_final <= 7'd0;
            end
        end
    end



endmodule