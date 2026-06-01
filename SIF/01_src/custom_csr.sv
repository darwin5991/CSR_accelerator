`timescale 1ns / 1ps

module custom_csr_matmul(
    input   wire            i_clk,
    input   wire            i_rstn,
    input   wire            i_cen,
    input   wire            i_wen,
    input   wire    [11:0]  i_addr,
    input   wire    [31:0]  i_din,
    output  reg     [31:0]  o_dout,
    input   wire            i_matmul_en,
    output  reg             o_done
);

    // 1. BRAM 인스턴스
    reg [5:0] ptr_addr; reg ptr_cen, ptr_wen; wire [15:0] ptr_dout;
    sram_ptr_33 RAM_PTR (.clka(i_clk), .ena(~ptr_cen), .wea(~ptr_wen), .addra(ptr_addr), .dina(i_din[15:0]), .douta(ptr_dout));

    reg [9:0] dns_addr; reg dns_cen, dns_wen; wire [15:0] dns_dout;
    sram_dense_1024 RAM_DENSE (.clka(i_clk), .ena(~dns_cen), .wea(~dns_wen), .addra(dns_addr), .dina(i_din[15:0]), .douta(dns_dout));

    reg [9:0] col_addr; reg col_cen, col_wen; wire [15:0] col_dout;
    sram_col_1024 RAM_COL (.clka(i_clk), .ena(~col_cen), .wea(~col_wen), .addra(col_addr), .dina(i_din[15:0]), .douta(col_dout));

    reg [9:0] val_addr; reg val_cen, val_wen; wire [15:0] val_dout;
    sram_val_1024 RAM_VAL (.clka(i_clk), .ena(~val_cen), .wea(~val_wen), .addra(val_addr), .dina(i_din[15:0]), .douta(val_dout));

    reg [9:0] res_addr; reg res_cen, res_wen; reg [31:0] res_din; wire [31:0] res_dout;
    sram_res_1024 RAM_RES (.clka(i_clk), .ena(~res_cen), .wea(~res_wen), .addra(res_addr), .dina(res_din), .douta(res_dout));

    // 2. FSM - 레이턴시 대기 상태 추가
    typedef enum reg [4:0] {
        S_IDLE, 
        S_FETCH_PTR_S, S_WAIT_PTR_S1, S_WAIT_PTR_S2,  // 2클럭 대기
        S_FETCH_PTR_E, S_WAIT_PTR_E1, S_WAIT_PTR_E2,  // 2클럭 대기
        S_CHECK_K, 
        S_FETCH_CSR, S_WAIT_CSR1, S_WAIT_CSR2,        // 2클럭 대기
        S_FETCH_DNS, S_WAIT_DNS1, S_WAIT_DNS2,        // 2클럭 대기
        S_CALC, S_SAVE_VAL, S_DONE
    } state_t;

    state_t state;
    reg [4:0]  row_idx;
    reg [4:0]  col_b_idx;
    reg [15:0] k_start, k_end, k_curr;
    
    // CSR 데이터를 래치할 레지스터
    reg [4:0]  col_idx_latched;
    reg signed [7:0] val_latched;
    reg byte_sel;  // 0: 하위 8비트, 1: 상위 8비트

    // Fixed-point 연산
    reg signed [31:0] acc;
    wire signed [7:0] dns_fixed = byte_sel ? $signed(dns_dout[15:8]) : $signed(dns_dout[7:0]);
    wire signed [15:0] product = val_latched * dns_fixed;

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            state <= S_IDLE; 
            o_done <= 0; 
            row_idx <= 0; 
            col_b_idx <= 0; 
            acc <= 0; 
            k_curr <= 0;
            k_start <= 0;
            k_end <= 0;
            col_idx_latched <= 0;
            val_latched <= 0;
            byte_sel <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    o_done <= 0; 
                    row_idx <= 0; 
                    col_b_idx <= 0;
                    acc <= 0;
                    if (i_matmul_en) state <= S_FETCH_PTR_S;
                end
                
                // ===== row_ptr[row_idx] 읽기 (2클럭 대기) =====
                S_FETCH_PTR_S: state <= S_WAIT_PTR_S1;
                S_WAIT_PTR_S1: state <= S_WAIT_PTR_S2;  // 추가 대기
                S_WAIT_PTR_S2: begin
                    k_start <= ptr_dout;
                    k_curr <= ptr_dout;
                    state <= S_FETCH_PTR_E;
                end
                
                // ===== row_ptr[row_idx + 1] 읽기 (2클럭 대기) =====
                S_FETCH_PTR_E: state <= S_WAIT_PTR_E1;
                S_WAIT_PTR_E1: state <= S_WAIT_PTR_E2;  // 추가 대기
                S_WAIT_PTR_E2: begin
                    k_end <= ptr_dout;
                    acc <= 0;
                    state <= S_CHECK_K;
                end

                // ===== 루프 조건 확인 =====
                S_CHECK_K: begin
                    if (k_curr < k_end) 
                        state <= S_FETCH_CSR;
                    else 
                        state <= S_SAVE_VAL;
                end

                // ===== CSR 데이터 읽기 (2클럭 대기) =====
                S_FETCH_CSR: state <= S_WAIT_CSR1;
                S_WAIT_CSR1: state <= S_WAIT_CSR2;  // 추가 대기
                S_WAIT_CSR2: begin
                    col_idx_latched <= col_dout[4:0];
                    val_latched <= $signed(val_dout[7:0]);
                    byte_sel <= col_dout[0];  // 열 인덱스의 LSB로 바이트 선택
                    state <= S_FETCH_DNS;
                end
                
                // ===== Dense 데이터 읽기 (2클럭 대기) =====
                S_FETCH_DNS: state <= S_WAIT_DNS1;
                S_WAIT_DNS1: state <= S_WAIT_DNS2;  // 추가 대기
                S_WAIT_DNS2: state <= S_CALC;

                // ===== 곱셈 누적 =====
                S_CALC: begin
                    acc <= acc + $signed({{16{product[15]}}, product});
                    k_curr <= k_curr + 1;
                    state <= S_CHECK_K;
                end

                // ===== 결과 저장 및 루프 제어 =====
                S_SAVE_VAL: begin
                    if (col_b_idx == 31) begin
                        if (row_idx == 31) begin
                            state <= S_DONE;
                        end else begin
                            row_idx <= row_idx + 1;
                            col_b_idx <= 0;
                            state <= S_FETCH_PTR_S;
                        end
                    end else begin
                        col_b_idx <= col_b_idx + 1;
                        k_curr <= k_start;
                        acc <= 0;
                        state <= S_CHECK_K;
                    end
                end

                S_DONE: begin 
                    o_done <= 1; 
                    state <= S_IDLE; 
                end
                
                default: state <= S_IDLE;
            endcase
        end
    end

    // 3. BRAM 제어 신호 (조합 논리)
    always @(*) begin
        // 기본값: 모든 BRAM 비활성화
        ptr_cen = 1; ptr_wen = 1; ptr_addr = 0;
        dns_cen = 1; dns_wen = 1; dns_addr = 0;
        col_cen = 1; col_wen = 1; col_addr = 0;
        val_cen = 1; val_wen = 1; val_addr = 0;
        res_cen = 1; res_wen = 1; res_addr = 0; res_din = 0;
        o_dout = 0;

        if (state == S_IDLE) begin
            // CPU 접근 모드
            if (!i_cen) begin
                case (i_addr[11:10])
                    2'b00: begin
                        if (i_addr[9:6] == 0) begin 
                            ptr_cen = 0; ptr_wen = i_wen; 
                            ptr_addr = i_addr[5:0]; 
                            o_dout = {16'b0, ptr_dout}; 
                        end else begin 
                            dns_cen = 0; dns_wen = i_wen; 
                            dns_addr = i_addr[9:0]; 
                            o_dout = {16'b0, dns_dout}; 
                        end
                    end
                    2'b01: begin 
                        col_cen = 0; col_wen = i_wen; 
                        col_addr = i_addr[9:0]; 
                        o_dout = {16'b0, col_dout}; 
                    end
                    2'b10: begin 
                        val_cen = 0; val_wen = i_wen; 
                        val_addr = i_addr[9:0]; 
                        o_dout = {16'b0, val_dout}; 
                    end
                    2'b11: begin 
                        res_cen = 0; res_wen = 1; 
                        res_addr = i_addr[9:0]; 
                        o_dout = res_dout; 
                    end
                endcase
            end
        end else begin
            // 행렬 곱셈 모드
            case (state)
                S_FETCH_PTR_S, S_WAIT_PTR_S1, S_WAIT_PTR_S2: begin 
                    ptr_cen = 0; 
                    ptr_addr = {1'b0, row_idx}; 
                end
                
                S_FETCH_PTR_E, S_WAIT_PTR_E1, S_WAIT_PTR_E2: begin 
                    ptr_cen = 0; 
                    ptr_addr = {1'b0, row_idx} + 1; 
                end
                
                S_FETCH_CSR, S_WAIT_CSR1, S_WAIT_CSR2: begin 
                    col_cen = 0; 
                    col_addr = k_curr[9:0]; 
                    val_cen = 0; 
                    val_addr = k_curr[9:0]; 
                end
                
                S_FETCH_DNS, S_WAIT_DNS1, S_WAIT_DNS2: begin 
                    dns_cen = 0; 
                    // B^T[col_b_idx][col_idx_latched]
                    // BRAM 주소 = (col_b_idx × 32 + col_idx_latched) / 2
                    dns_addr = {col_b_idx, col_idx_latched[4:1]}; 
                end
                
                S_SAVE_VAL: begin
                    res_cen = 0; 
                    res_wen = 0;  // 쓰기 활성화
                    res_addr = {row_idx, col_b_idx};
                    // res_addr = {row_idx, 5'b00000};
                    res_din = acc;
                end
                
                default: ;
            endcase
        end
    end
endmodule

