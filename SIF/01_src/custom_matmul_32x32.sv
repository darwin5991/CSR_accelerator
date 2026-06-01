`timescale 1ns / 1ps

module custom_matmul32x32(
    input   wire            i_clk,
    input   wire            i_rstn,
    
    // Top Module(Memory Controller) 연결용
    input   wire            i_cen,      // Active Low
    input   wire            i_wen,      // Active Low
    input   wire    [10:0]  i_addr,     // 11비트 주소
    input   wire    [31:0]  i_din,
    output  reg     [31:0]  o_dout,
    
    // 연산 제어 신호
    input   wire            i_matmul_en,
    input   wire    [2:0]   i_fl,       // Fixed-point shift bit
    output  reg             o_done      // 연산 완료 신호
    );

    // =========================================================
    // 1. 내부 메모리 신호 및 인스턴스
    // =========================================================
    reg         amem_cen, amem_wen;
    reg  [8:0]  amem_addr;
    reg  [15:0] amem_din;
    wire [15:0] amem_dout;

    reg         bmem_cen, bmem_wen;
    reg  [8:0]  bmem_addr;
    reg  [15:0] bmem_din;
    wire [15:0] bmem_dout;

    reg         omem_cen, omem_wen;
    reg  [9:0]  omem_addr;
    reg  [31:0] omem_din;
    wire [31:0] omem_dout;

    wire [31:0] result;
    wire        next; 

    // AMEM (Input A: 32x32=1024이나 2개씩 패킹 시 512 Depth)
    sram_16_512_A AMEM (
        .clka   (i_clk),
        .ena    (~amem_cen),      
        .wea    (~amem_wen),      
        .addra  (amem_addr),
        .dina   (amem_din),
        .douta  (amem_dout)
    );

    // BMEM (Input B: 512 Depth)
    sram_16_512_B BMEM (
        .clka   (i_clk),
        .ena    (~bmem_cen),
        .wea    (~bmem_wen),
        .addra  (bmem_addr),
        .dina   (bmem_din),
        .douta  (bmem_dout)
    );
    
    // OMEM (Output Result: 32x32=1024 Depth)
    sram_32_1024_O OMEM (
        .clka   (i_clk),
        .ena    (~omem_cen),
        .wea    (~omem_wen),
        .addra  (omem_addr),
        .dina   (omem_din),
        .douta  (omem_dout)
    );

    // =========================================================
    // 2. FSM 상태 및 카운터 정의
    // =========================================================
    localparam S_IDLE    = 2'b00;
    localparam S_COMPUTE = 2'b01;
    localparam S_DONE    = 2'b10;

    reg [1:0] current_state, next_state;

    reg [4:0] cnt_row_i;  // 0~31
    reg [4:0] cnt_col_j;  // 0~31
    reg [3:0] cnt_k;      // 0~15 (2개씩 패킹된 데이터를 16번 읽어 32회 연산)
    reg [9:0] cnt_w_addr; // 0~1023 (결과 메모리 주소)

    // =========================================================
    // 3. MAC (Multiply-Accumulate) 모듈 연결
    // =========================================================
    // [참고] MAC 내부에서 i_fin을 i_matmul_en의 반전이나 
    // 현재 상태가 S_COMPUTE가 아닐 때 초기화하도록 설계되어야 함
    MAC multiply_accumulate (
        .i_clk(i_clk),
        .i_rstn(i_rstn),
        .i_fin(o_done), 
        .i_fl(i_fl),
        .amem_dout(amem_dout),
        .bmem_dout(bmem_dout),
        .i_cnt(cnt_k),
        .result(result),
        .next(next)
    );

    // =========================================================
    // 4. State Transition & Counter Logic
    // =========================================================

    // always @(*) begin
    //     // next_state = current_state;
    //     case (current_state)
    //         S_IDLE: begin
    //             if (i_matmul_en) next_state = S_COMPUTE;
    //             else next_state = S_IDLE;
    //         end
    //         S_COMPUTE: begin
    //             if (next && (cnt_w_addr == 10'd1023)) next_state = S_DONE;
    //             else next_state = S_COMPUTE;
    //         end
    //         S_DONE: begin
    //             next_state = S_IDLE;
    //         end
    //     endcase
    // end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            cnt_row_i <= 0; cnt_col_j <= 0; cnt_k <= 0; cnt_w_addr <= 0;
            current_state <= S_IDLE;
        end 
        else begin
            // 항상 상태 전이 수행
            current_state <= next_state;
            
            if (current_state == S_COMPUTE) begin
                cnt_k <= cnt_k + 1;
                if (cnt_k == 4'd15) begin 
                    if (cnt_col_j == 31) begin
                        cnt_col_j <= 0;
                        if (cnt_row_i == 31) cnt_row_i <= 0; 
                        else cnt_row_i <= cnt_row_i + 1;
                    end 
                    else cnt_col_j <= cnt_col_j + 1;
                end
                if (next) cnt_w_addr <= cnt_w_addr + 1;
            end 
            else begin
                cnt_row_i <= 0; cnt_col_j <= 0; cnt_k <= 0; cnt_w_addr <= 0;
            end
        end
        // else if (current_state == S_COMPUTE) begin
        //     cnt_k <= cnt_k + 1;
        //     if (cnt_k == 4'd15) begin 
        //         if (cnt_col_j == 31) begin
        //             cnt_col_j <= 0;
        //             if (cnt_row_i == 31) cnt_row_i <= 0; 
        //             else cnt_row_i <= cnt_row_i + 1;
        //         end 
        //         else cnt_col_j <= cnt_col_j + 1;
        //     end
        //     if (next) cnt_w_addr <= cnt_w_addr + 1;
        // end 
        // else begin
        //     cnt_row_i <= 0; cnt_col_j <= 0; cnt_k <= 0; cnt_w_addr <= 0;
        //     current_state <= next_state;
        // end
    end

    // =========================================================
    // 5. Output & Memory Control Logic (Combinational)
    // =========================================================
    always @(*) begin
        // 기본값 세팅: 모든 메모리 Disable 및 Read 모드
        amem_cen = 1; amem_wen = 1; amem_addr = 0; amem_din = 0;
        bmem_cen = 1; bmem_wen = 1; bmem_addr = 0; bmem_din = 0;
        omem_cen = 1; omem_wen = 1; omem_addr = 0; omem_din = 0;

        o_done = 0; // 핵심 수정: 기본값은 0 (연산 전/중에는 Done 아님)
        o_dout = 0;

        case (current_state)
            S_IDLE: begin
                if (i_matmul_en) next_state = S_COMPUTE;
                else next_state = S_IDLE;
                o_done = 0; // 대기 중에는 끝난 것이 아님
                if (~i_cen) begin // 외부(Top)에서 메모리 접근 시
                    casex (i_addr[10:9]) 
                        2'b00: begin // AMEM (0~511)
                            amem_cen = i_cen; amem_wen = i_wen;
                            amem_addr = i_addr[8:0]; amem_din = i_din[15:0];
                            o_dout = {16'b0, amem_dout}; 
                        end
                        2'b01: begin // BMEM (512~1023)
                            bmem_cen = i_cen; bmem_wen = i_wen;
                            bmem_addr = i_addr[8:0]; bmem_din = i_din[15:0];
                            o_dout = {16'b0, bmem_dout};
                        end
                        2'b1x: begin // OMEM (1024~2047)
                            omem_cen = i_cen; omem_wen = i_wen;
                            omem_addr = i_addr[9:0]; omem_din = i_din; 
                            o_dout = omem_dout;
                        end
                    endcase
                end
            end

            S_COMPUTE: begin
                if (next && (cnt_w_addr == 10'd1023)) next_state = S_DONE;
                else next_state = S_COMPUTE;
                o_done = 0; 
                amem_cen = 0; amem_wen = 1;
                bmem_cen = 0; bmem_wen = 1;
                
                // 32x32 행렬곱 주소 계산
                amem_addr = (cnt_row_i * 16) + cnt_k;
                bmem_addr = (cnt_col_j * 16) + cnt_k;

                if (next) begin // MAC 연산 완료 시 결과 저장
                    omem_cen = 0; omem_wen = 0; 
                    omem_addr = cnt_w_addr;
                    omem_din = result;
                end
            end

            S_DONE: begin
                o_done = 1; // 연산이 완전히 끝난 이 상태에서만 1 출력
                next_state = S_IDLE;
            end
        endcase
    end

endmodule