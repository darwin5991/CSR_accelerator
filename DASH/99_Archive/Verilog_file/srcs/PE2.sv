module PE2_128x512 (
    input  logic        i_clk,
    input  logic        i_rst_n,
    input logic         i_start,

    output logic        o_done,

    input logic [1:0]  i_quarter_cnt,
    // input logic [15:0] i_addr_base,
    input logic [7:0]  i_scale_factor,
    input logic [7:0]  i_zero_point,
    // input logic [13:0] i_nnz,
    input logic [1:0] i_layer_num,
    input logic [1:0] i_pe_num,

    //input_vector interface
    output logic [6:0]      o_addr_in,
    output logic            o_en_in,
    output logic            o_we_in,
    output logic [7:0]      o_data_in,
    input  logic [7:0]      i_data_in,

    // data initialization interface
    input  logic        i_init_mode, // 1: TB 초기화 모드, 0: 정상 동작 모드

    // 1. Weight Memory Init Ports (Data: 15b, Addr: 16b)
    input  logic [14:0] i_tb_weight_data,
    input  logic [15:0] i_tb_weight_addr,
    input  logic        i_tb_weight_we,

    // 2. Row_num Memory Init Ports (Data: 7b, Addr: 9b)
    input  logic [6:0]  i_tb_rownum_data,
    input  logic [8:0]  i_tb_rownum_addr,
    input  logic        i_tb_rownum_we,

    // 3. Q_bias Memory Init Ports (Data: 32b, Addr: 7b)
    input  logic [31:0] i_tb_bias_data,
    input  logic [6:0]  i_tb_bias_addr,
    input  logic        i_tb_bias_we
);
    // Signals between MAC and Memories
    wire [15:0] o_addr_wd;
    wire        o_en_wd;
    wire [14:0] i_data_wd; // Read from Mem

    wire [8:0]  o_addr_row;
    wire        o_en_row;
    wire [6:0]  i_data_row; // Read from Mem

    wire [6:0]  o_addr_bias;
    wire        o_en_bias;
    wire [31:0] i_data_bias; // Read from Mem

    wire [6:0]  o_addr_tmp;
    wire        o_en_tmp;
    wire        o_we_tmp;
    wire [31:0] o_data_tmp; // Write to Mem (from MAC)
    wire [31:0] i_data_tmp; // Read from Mem (to MAC)

    // Control Signal
    wire [1:0]  start_final_write;

    reg [13:0] r_nnz [7:0]; // 8 Quarters, each has 14-bit nnz value
    reg [16:0] r_addr_base;
    reg [8:0] r_addr_base_row;
    wire [1:0] ctrl_cnt;
    assign ctrl_cnt= i_quarter_cnt+i_pe_num;

    // 1. Weight Memory
    logic [15:0] mux_addr_wd;
    logic        mux_en_wd;
    logic        mux_we_wd;
    logic [14:0] mux_dina_wd;

    // 2. Row_num Memory
    logic [8:0]  mux_addr_row;
    logic        mux_en_row;
    logic        mux_we_row;
    logic [6:0]  mux_dina_row;

    // 3. Q_bias Memory
    logic [6:0]  mux_addr_bias;
    logic        mux_en_bias;
    logic        mux_we_bias;
    logic [31:0] mux_dina_bias;

    logic [1:0] o_done_delay;
    always@(posedge i_clk or negedge i_rst_n) begin
        if(!i_rst_n) begin
            // r_nnz[0] <= 14'd831;
            // r_nnz[1] <= 14'd847;
            // r_nnz[2] <= 14'd831;
            // r_nnz[3] <= 14'd873;
            r_nnz[0] <= 14'd898;
            r_nnz[1] <= 14'd844;
            r_nnz[2] <= 14'd794;
            r_nnz[3] <= 14'd724;

            r_nnz[4] <= 14'd0;
            r_nnz[5] <= 14'd0;
            r_nnz[6] <= 14'd0;
            r_nnz[7] <= 14'd0;

            o_done_delay<=2'b00;
            // r_addr_base <= 17'd831+17'd847;
            r_addr_base <= 16'd898+16'd844;
            r_addr_base_row <= 9'd128*i_pe_num;
        end
        else if(i_start==1'b1) begin
            o_done_delay<=2'b00;
        end
        else if(start_final_write==0 && o_done==1'b1 && i_quarter_cnt!=2'd3&& o_done_delay==2'b00) begin
            o_done_delay<=2'b01;
            if(ctrl_cnt!=2'd3)begin
                r_addr_base <= r_addr_base + r_nnz[ctrl_cnt + (i_layer_num*4)];
                r_addr_base_row <= r_addr_base_row + 9'd128;
            end
            else begin
                // r_addr_base <= (831+847+831+873)*i_layer_num;
                r_addr_base <= (898+844+794+724)*i_layer_num;
                r_addr_base_row <= 9'd128*i_layer_num;
            end
        end
        else if(o_done_delay==2'b01) begin
            o_done_delay<=2'b10;
        end
        else begin
            o_done_delay<=o_done_delay;
            r_addr_base <= r_addr_base;
            r_addr_base_row <= r_addr_base_row;
        end
    end
    //1. quantized weight memory(DATA) : 15비트[8비트 val][7비트 col idx], 최대 (128x128개)x4, 주소공간 16비트
    weight_data_2 weight_data_mem (
        .clka(i_clk),    
        .rsta(!i_rst_n), 
        .ena(mux_en_wd),   
        .wea(mux_we_wd),      
        .addra(mux_addr_wd), 
        .dina(mux_dina_wd),       
        .douta(i_data_wd), 
        .rsta_busy()  
    );
    //2. row num memory(ROW) : 7비트, 주소공간 9비트
    weight_rownum_2 weight_rownum_mem (
        .clka(i_clk),        
        .rsta(!i_rst_n),        
        .ena(mux_en_row),        
        .wea(mux_we_row),        
        .addra(mux_addr_row),  
        .dina(mux_dina_row),      
        .douta(i_data_row),
        .rsta_busy()
    );
    //3. q_bias memory(BIAS) : 32비트, 주소공간 7비트
    q_bias_2 q_bias_mem (
        .clka(i_clk),
        .rsta(!i_rst_n),
        .ena(mux_en_bias),
        .wea(mux_we_bias),     
        .addra(mux_addr_bias),          
        .dina(mux_dina_bias),            
        .douta(i_data_bias),          
        .rsta_busy()  
    );
    //4. output_tmp feature memory(TMP) : 32비트, 주소공간 7비트
    output_tmp_2 output_tmp_mem (
        .clka(i_clk),           
        .rsta(!i_rst_n),        
        .ena(o_en_tmp),         
        .wea(o_we_tmp),         
        .addra(o_addr_tmp),     
        .dina(o_data_tmp),      
        .douta(i_data_tmp),     
        .rsta_busy() 
    );
    // =========================================================================
    // [Block 1] Weight Memory Datapath Mux
    // =========================================================================
    always_comb begin
        // 기본값 설정 (Latch 방지)
        mux_addr_wd = 16'd0; mux_en_wd = 1'b0; mux_we_wd = 1'b0; mux_dina_wd = 15'd0;
        
        if (i_init_mode) begin
            // TB 초기화 모드
            mux_addr_wd = i_tb_weight_addr;
            mux_en_wd   = 1'b1;
            mux_we_wd   = i_tb_weight_we;
            mux_dina_wd = i_tb_weight_data;
        end else begin
            // NPU 정상 동작 모드 (MAC 연산기와 연결)
            mux_addr_wd = o_addr_wd;
            mux_en_wd   = o_en_wd;
            mux_we_wd   = 1'b0;    // MAC은 Read Only
            mux_dina_wd = 15'd0; 
        end
    end

    // =========================================================================
    // [Block 2] Row_num Memory Datapath Mux
    // =========================================================================
    always_comb begin
        // 기본값 설정 (Latch 방지)
        mux_addr_row = 9'd0; mux_en_row = 1'b0; mux_we_row = 1'b0; mux_dina_row = 7'd0;
        
        if (i_init_mode) begin
            // TB 초기화 모드
            mux_addr_row = i_tb_rownum_addr;
            mux_en_row   = 1'b1;
            mux_we_row   = i_tb_rownum_we;
            mux_dina_row = i_tb_rownum_data;
        end else begin
            // NPU 정상 동작 모드 (MAC 연산기와 연결)
            mux_addr_row = o_addr_row;
            mux_en_row   = o_en_row;
            mux_we_row   = 1'b0;   // MAC은 Read Only
            mux_dina_row = 7'd0;
        end
    end

    // =========================================================================
    // [Block 3] Q_bias Memory Datapath Mux
    // =========================================================================
    always_comb begin
        // 기본값 설정 (Latch 방지)
        mux_addr_bias = 7'd0; mux_en_bias = 1'b0; mux_we_bias = 1'b0; mux_dina_bias = 32'd0;
        
        if (i_init_mode) begin
            // TB 초기화 모드
            mux_addr_bias = i_tb_bias_addr;
            mux_en_bias   = 1'b1;
            mux_we_bias   = i_tb_bias_we;
            mux_dina_bias = i_tb_bias_data;
        end else begin
            // NPU 정상 동작 모드 (MAC 연산기와 연결)
            mux_addr_bias = o_addr_bias;
            mux_en_bias   = o_en_bias;
            mux_we_bias   = 1'b0;  // MAC은 Read Only
            mux_dina_bias = 32'd0;
        end
    end
    wire [13:0] i_nnz;
    assign i_nnz= r_nnz[ctrl_cnt + (i_layer_num*4)];
    csr_mac128x512 u_mac_128x512 (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_start(i_start),
        .o_done(o_done),
        .i_quarter_cnt(i_quarter_cnt),

        .i_addr_base(r_addr_base),
        .i_addr_base_row(r_addr_base_row),
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



endmodule