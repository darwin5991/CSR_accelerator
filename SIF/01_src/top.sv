module top_matmul_system(
    input wire clk  // Basys3 Board Clock (100MHz)
    );
    
    // =========================================================
    // 1. 내부 연결 신호 정의
    // =========================================================
    
    // [중요] 32x32 행렬을 위해 주소선이 11비트로 확장되었습니다.
    // (AMEM 512 + BMEM 512 + OMEM 1024 = 2048 공간 -> 11비트 필요)
    wire [10:0] w_addr;     
    
    wire [31:0] w_din;      // PC -> FPGA 데이터
    wire [31:0] w_dout;     // FPGA -> PC 결과 데이터
    
    wire        w_cen;      // 칩 선택 (Chip Enable)
    wire        w_wen;      // 쓰기 선택 (Write Enable)
    wire        w_rstn;     // 리셋 (Active Low)
    wire        w_matmul_en;// 연산 시작 신호
    wire        w_done;     // 연산 완료 신호

    // =========================================================
    // 2. 32x32 행렬 연산 모듈 (DUT) 인스턴스
    // 이미지에 나온 이름: custom_matmul32x32
    // =========================================================
    custom_matmul32x32 DUT (
        .i_clk      (clk),          
        
        // VIO에서 들어오는 제어 신호들
        .i_rstn     (w_rstn),       
        .i_cen      (w_cen),        
        .i_wen      (w_wen),        
        .i_addr     (w_addr),       // 11비트 주소 연결
        .i_din      (w_din),        
        .i_matmul_en(w_matmul_en),  
        
        .i_fl       (3'd4),         // 소수점 위치 (고정값 4)
        
        // VIO로 나가는 결과 신호들
        .o_dout     (w_dout),       
        .o_done     (w_done)        
    );

    // =========================================================
    // 3. VIO IP 인스턴스
    // 이미지에 나온 이름: vio_0
    // =========================================================
    vio_0 u_vio (
        .clk        (clk),
        
        // Input Probes (FPGA -> PC 모니터링)
        .probe_in0  (w_dout),       // [31:0] 결과값
        .probe_in1  (w_done),       // [0:0]  완료 신호
        
        // Output Probes (PC -> FPGA 제어)
        .probe_out0 (w_rstn),       // [0:0]  리셋
        .probe_out1 (w_cen),        // [0:0]  칩 선택
        .probe_out2 (w_wen),        // [0:0]  쓰기 선택
        .probe_out3 (w_addr),       // [10:0] 주소 (11비트 확인 필수!)
        .probe_out4 (w_din),        // [31:0] 입력 데이터
        .probe_out5 (w_matmul_en)   // [0:0]  시작 신호
    );

endmodule