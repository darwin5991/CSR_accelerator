module MAC(
    input wire i_clk,
    input wire i_rstn,
    input wire i_fin,
    input wire [2:0] i_fl,
    input wire [15:0] amem_dout,
    input wire [15:0] bmem_dout,
    
    // [수정 1] 카운터 4비트로 확장 (0~15까지 세어야 함)
    // 32개 원소 / 2(패킹) = 16 cycle
    input wire [3:0] i_cnt, 
    
    output wire [31:0] result,
    output wire next
    );

   // 16bit 수를 두개의 8bit씩 쪼개기 (기존 동일)
    wire signed [7:0] a_MSB = amem_dout[15:8]; 
    wire signed [7:0] a_LSB = amem_dout[7:0]; 
    wire signed [7:0] b_MSB = bmem_dout[15:8]; 
    wire signed [7:0] b_LSB = bmem_dout[7:0]; 

    reg signed [15:0] pipe_mul_MSB; 
    reg signed [15:0] pipe_mul_LSB;

    reg next_trigger;
    reg [1:0] next_shift;
    
    // [수정 2] 내부 파이프라인 카운터도 4비트로 확장
    reg [3:0] cnt_d1, cnt_d2; 

    wire signed [16:0] sum_adder = pipe_mul_MSB + pipe_mul_LSB; 
    reg signed [31:0] acc; 

    // 곱셈 파이프라인 (기존 동일)
    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            pipe_mul_MSB <= 16'd0;
            pipe_mul_LSB <= 16'd0;
        end 
        else begin
            pipe_mul_MSB <= a_MSB * b_MSB; 
            pipe_mul_LSB <= a_LSB * b_LSB;
        end
    end

    // 제어 신호 파이프라인
    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn || i_fin) begin 
            next_trigger <= 1'b0;
            next_shift <= 2'b0;
            cnt_d1 <= 4'd0; // [수정] 0 초기화
            cnt_d2 <= 4'd0; // [수정] 0 초기화
        end 
        else begin
            // [수정 3] 16번(0~15) 돌았을 때 트리거 발생
            if (i_cnt == 4'd15) 
                next_trigger <= 1'b1; 
            else 
                next_trigger <= 1'b0;
            
            next_shift <= {next_shift[0], next_trigger};
            cnt_d1 <= i_cnt;
            cnt_d2 <= cnt_d1;
        end
    end
    assign next = next_shift[1]; 

    // 누적기 (Accumulator)
    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn || i_fin) begin
            acc <= 32'd0;
        end 
        else begin
            // [수정 4] 첫 번째 사이클(0번) 데이터가 도착했을 때 리셋(덮어쓰기)
            if (cnt_d2 == 4'd0) begin
                acc <= {{15{sum_adder[16]}}, sum_adder}; 
            end 
            else begin
                acc <= acc + sum_adder;
            end
        end
    end
    
    // 고정 소수점 처리 (기존 동일)
    assign result = acc >>> i_fl;

endmodule