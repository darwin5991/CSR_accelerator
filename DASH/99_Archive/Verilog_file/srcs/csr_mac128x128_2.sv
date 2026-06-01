module mac_128x128(
    input  logic        i_clk,
    input  logic        i_rst_n,
    input  logic        i_start,
    output logic        o_done,
    input logic [1:0]  i_quarter_cnt,
    input logic [13:0] i_nnz,

    //weigth memory interface(data)
    output logic [13:0] o_addr_wd, //virtuallized
    output logic        o_en_wd,
    input  logic [14:0] i_data_wd,
    //weigth memory interface(row num)
    output logic [6:0] o_addr_row, //virtuallized
    output logic        o_en_row,
    input  logic [6:0] i_data_row,
    //q_bias memory interface
    output logic [6:0] o_addr_bias,
    output logic        o_en_bias,
    input  logic [31:0] i_data_bias,

    //input feature memory interface(col)
    output logic [6:0] o_addr_in,
    output logic        o_en_in,
    // output logic [7:0] o_data_in,
    input  logic [7:0] i_data_in,

    //output_tmp feature memory interface
    output logic [6:0] o_addr_tmp,
    output logic        o_en_tmp,
    output logic        o_we_tmp,
    output logic [31:0] o_data_tmp,
    input  logic [31:0] i_data_tmp

);

    parameter S_IDLE=3'b000, S_FETCH_PTR=3'b001, S_DATA=3'b010, S_WAIT0=3'b011, S_WAIT1=3'b100, S_LAST=3'b101, S_DONE=3'b110;
    reg [2:0] state;
    reg [2:0] next_state;

    reg [6:0] r_addr_row;
    wire [6:0] w_addr_row_n;
    reg ctrl_addr_row;
    assign o_addr_row = r_addr_row;
    assign w_addr_row_n= (ctrl_addr_row)? r_addr_row + 7'd0: r_addr_row + 7'd1;

    reg[6:0] r_cnt;
    wire[6:0] w_cnt_n;
    reg [1:0] ctrl_cnt;
    assign w_cnt_n= (ctrl_cnt==2'b00)? r_cnt - 7'd1 : //
                    (ctrl_cnt==2'b01)? i_data_row : r_cnt;//state가 wait 일때 cnt가 0이면 i_data_row, 1이면 r_cnt 유지

    reg [13:0] r_addr_data;
    wire [13:0] w_addr_data_n;
    reg [1:0] ctrl_addr_data;
    assign o_addr_wd = r_addr_data;
    assign w_addr_data_n= (ctrl_addr_data==2'b00) ? r_addr_data +  14'd1:
                          (ctrl_addr_data==2'b01) ? r_addr_data +  14'd0: 14'd0;

    assign o_addr_in= i_data_wd[6:0];

    // reg [7:0] r_col;
    // reg r_col_saved;
    // always@(posedge i_clk or negedge i_rst_n) begin
    //     if(!i_rst_n) begin
    //         r_col <= 8'd0;
    //         r_col_saved <= 1'b0;
    //     end
    //     else begin
    //         if(state==S_WAIT0 || state==S_WAIT1) begin
    //             if(!r_col_saved) begin
    //                 r_col <= i_data_in;
    //                 r_col_saved <= 1'b1;
    //             end
    //             else begin
    //                 r_col<=r_col;
    //                 r_col_saved<=r_col_saved;
    //             end
    //         end
    //         else begin
    //             r_col <= 8'd0;
    //             r_col_saved <= 1'b0;
    //         end
    //     end
    // end
    reg r_wait;
    always@(posedge i_clk or negedge i_rst_n) begin
        if(!i_rst_n) begin
            r_wait<=0;
        end
        else begin
            if(state==S_WAIT0 || state==S_WAIT1) begin
                if(r_wait==1'b0) begin
                    r_wait<=1;
                end
                else begin
                    r_wait<=r_wait;
                end
            end
            else begin
                r_wait <= 0;
            end
        end
    end
    

    wire [15:0] w_mult;
    // assign w_mult = i_data_wd[14:7] * (r_col_saved)? r_col : i_data_in;
    wire [7:0] weight_val;
    wire [7:0] input_val;
    assign weight_val = i_data_wd[14:7];
    assign input_val = i_data_in;
    wire [7:0] weight_val_s;
    wire [7:0] input_val_s;
    assign weight_val_s= (weight_val^{8{weight_val[7]}})+weight_val[7];
    assign input_val_s= (input_val^{8{input_val[7]}})+input_val[7];
    assign w_mult= (((weight_val_s*input_val_s))^({16{weight_val[7]^input_val[7]}})) + (weight_val[7]^input_val[7]);


    reg [31:0] r_accum;
    wire [31:0] w_accum_n;
    reg [1:0] ctrl_accum;
    assign w_accum_n = (ctrl_accum==2'b00)? {{16{w_mult[15]}}, w_mult} :
                        (ctrl_accum==2'b01)? r_accum + {{16{w_mult[15]}}, w_mult} : r_accum;


    reg r_write;
    reg r_write_n;
    assign o_we_tmp= r_write ;//항상 tmp에 저장
    
    always@(*)begin
        if(r_write==1'b1) begin
            r_write_n = 1'b0;
        end
        else begin
            if(state==S_DATA && r_cnt==1) begin
                r_write_n = 1'b1;
            end
            else begin
                r_write_n = r_write;
            end
        end
    end



    reg [6:0] r_addr_bias;
    wire [6:0] w_addr_bias_n;
    reg ctrl_addr_bias;
    assign o_addr_bias = r_addr_bias;
    assign o_addr_tmp = r_addr_bias;//quarter==0
    assign w_addr_bias_n= (ctrl_addr_bias)? r_addr_bias + 7'd1:r_addr_bias + 7'd0;

    always@(*) begin
        case(state)
            S_IDLE: begin
                if(i_start) begin
                    next_state = S_FETCH_PTR;
                end
                else begin
                    next_state = S_IDLE;
                end
            end
            S_FETCH_PTR: begin
                if(i_data_row == 7'd0)
                    next_state = S_WAIT0;
                else if(i_data_row == 7'd1)
                    next_state = S_WAIT1;
                else
                next_state = S_DATA;
            end
            S_DATA: begin
                if(r_cnt==1)begin
                    if(r_addr_bias==7'd127)begin
                        next_state = S_LAST;
                    end
                    else begin
                        if(i_data_row == 7'd0)begin
                            next_state = S_WAIT0;
                        end
                        else if(i_data_row == 7'd1) begin
                            next_state = S_WAIT1;
                        end
                        else begin
                            next_state = S_DATA;
                        end
                    end
                end
                else begin
                    next_state = S_DATA;    
                end
            end
            S_WAIT0: begin
                if(i_data_row==7'd0)begin
                    if(r_addr_row==7'd0)begin
                        next_state = S_LAST;
                    end
                    else begin
                        next_state = S_WAIT0;
                    end
                end
                else if(i_data_row==7'd1) begin
                    next_state = S_WAIT1;
                end
                else begin
                    next_state = S_DATA;
                end
            end
            S_WAIT1: begin
                next_state = S_DATA;
            end
            S_LAST: begin
                next_state = S_DONE;
            end
            S_DONE: begin
                next_state = S_IDLE;
            end
            default: begin
                next_state = S_IDLE;
            end
        endcase
    end

    always@(*)begin
        //default
        ctrl_addr_row = 1'b1;
        ctrl_cnt = 2'b10;
        ctrl_addr_data = 2'b01;
        ctrl_accum = 2'b10;
        ctrl_addr_bias = 1'b0;

        //제어신호 별 설정
        
        if(r_write==1)begin
            ctrl_accum=2'b00;
        end
        else if(state==S_DATA||state==S_WAIT0||state==S_WAIT1) begin
            if(r_wait==1'b0)begin
                ctrl_accum=2'b01;
            end
            else begin
                ctrl_accum=2'b10;
            end
        end
        else begin
            ctrl_accum=2'b10;
        end

        //next_state가 fetch_ptr,wait0일 때는 addr_row 증가
        //현재 state가 Data이고 r_cnt가 2일떄 addr_row 증가
        //나머지 경우는 addr_row 유지
        if(next_state==S_FETCH_PTR || next_state==S_WAIT0) begin
            ctrl_addr_row=1'b0;
        end
        else if(state!=S_FETCH_PTR && o_addr_row==7'd0) begin
            ctrl_addr_row=1'b1;
        end
        else if (state==S_WAIT1) begin
            ctrl_addr_row=1'b0;
        end
        else if(state==S_DATA && r_cnt==2) begin
            ctrl_addr_row=1'b0;
        end
        else begin
            ctrl_addr_row=1'b1;
        end

        //ctrl_addr_row:
        //idle->ptr :0
        //ptr: i_data_row 가 0이면 0, 1이면 1
        //data: reg_cnt==2일 떄 0, r_cnt==1이고 i_data_dout==0이면 0, 나머지는 1
        //wait0: i_data_row가 0이면 0, 0이 아니면이면 1
        //wait1: 0
        //last:1
        //나머지 :1
        // if(state==S_IDLE && i_start==1'b1)begin
        //     ctrl_addr_row=1'b0;
        // end
        // else if(state==S_FETCH_PTR) begin
        //     if(i_data_row==7'd0) begin
        //         ctrl_addr_row=1'b0;
        //     end
        //     else begin
        //         ctrl_addr_row=1'b1;
        //     end
        // end
        // else if(state!=S_FETCH_PTR && o_addr_row==7'd0) begin
        //     ctrl_addr_row=1'b1;
        // end
        // else if(state==S_DATA) begin
        //     if(r_cnt==2) begin
        //         ctrl_addr_row=1'b0;
        //     end
        //     else if(r_cnt==1) begin
        //         if(i_data_row==7'd0) begin
        //             ctrl_addr_row=1'b0;
        //         end
        //         else begin
        //             ctrl_addr_row=1'b1;
        //         end
        //     end
        //     else begin
        //         ctrl_addr_row=1'b1;
        //     end
        // end
        // else if(state==S_WAIT0) begin
        //     if(i_data_row==7'd0) begin
        //         ctrl_addr_row=1'b0;
        //     end
        //     else begin
        //         ctrl_addr_row=1'b1;
        //     end
        // end
        // else if( state==S_WAIT1) begin
        //     ctrl_addr_row=1'b0;
        // end
        // else begin
        //     ctrl_addr_row=1'b1;
        // end

        //ctrl_cnt
        // wait0 이면 01
        // data이면 r_cnt==1 이면 01
        // wait1이면 10
        if(state==S_WAIT0) begin
            ctrl_cnt=2'b01;
        end
        else if(state==S_FETCH_PTR) begin
            ctrl_cnt=2'b01;
        end
        else if(state==S_DATA) begin
            if(r_cnt==1) begin
                ctrl_cnt=2'b01;
            end
            else begin
                ctrl_cnt=2'b00;
            end
        end
        else if(state==S_WAIT1) begin
            ctrl_cnt=2'b10;
        end
        else begin
            ctrl_cnt=2'b10;
        end 

        //ctrl_addr_data
        //data:00
        //next_state가 wait0또는 wait0이면 01
        //address_row가 i_nnz-1이면 10
        //나머지 01
        if(next_state==S_DATA) begin
            ctrl_addr_data=(r_addr_data==i_nnz-1)?2'b10:2'b00;
        end
        else if(next_state==S_FETCH_PTR) begin
            ctrl_addr_data=2'b00;
        end
        else if(next_state==S_WAIT0 || next_state==S_WAIT1) begin
            ctrl_addr_data=2'b01;
        end
        // else if(r_addr_data==i_nnz-1) begin
        //     ctrl_addr_data=2'b10;
        // end
        else begin
            ctrl_addr_data=2'b01;
        end
        
        //ctrl_addr_bias
        //write 될 때 1
        //r_wait==1 일때 1
        if(o_addr_bias==7'd127) begin
            ctrl_addr_bias=1'b0;
        end
        else if((r_wait==1'b1) && (state==S_DATA)&&(r_cnt==7'd1)) begin
            ctrl_addr_bias=1'b0;
        end
        else if(r_write==1'b1 || (r_wait==1'b1)) begin
            ctrl_addr_bias=1'b1;
        end
        else begin
            ctrl_addr_bias=1'b0;
        end
    end



    always@(posedge i_clk or negedge i_rst_n) begin
        if(!i_rst_n) begin
            state <= S_IDLE;
            o_done <= 1'b0;
            
            r_addr_row <= 7'd0;
            r_cnt <= 7'd0;
            r_addr_data <= 14'd0;
            r_accum <= 32'd0;
            r_addr_bias <= 7'd0;
            r_write <= 1'b0;
        end
        else begin
            state <= next_state;
            r_addr_row  <= w_addr_row_n;
            r_cnt       <= w_cnt_n;
            r_addr_data <= w_addr_data_n;
            r_accum     <= w_accum_n;
            r_addr_bias <= w_addr_bias_n;
            r_write     <= r_write_n;
            if(state == S_DONE) begin
                o_done <= 1'b1;

                r_addr_row <= 7'd0;
                r_cnt <= 7'd0;
                r_addr_data <= 14'd0;
                r_accum <= 32'd0;
                r_addr_bias <= 7'd0;
                r_write <= 1'b0;
            end
            else if( state==S_IDLE && i_start) begin
                o_done <= 1'b0;
            end
            else begin
                o_done<=o_done;
            end
        end
    end






endmodule



