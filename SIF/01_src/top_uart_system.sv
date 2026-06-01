`timescale 1ns / 1ps

module top_uart_system(
    input  wire clk,      // 시스템 클럭 (100MHz 가정)
    input  wire RsRx,     // UART 수신 포트
    output wire RsTx,     // UART 송신 포트
    input  wire btnC,     // 리셋 버튼 (Active High)
    output wire [3:0] led // 상태 표시 LED
);

    // =============================================================
    // 1. 신호 및 레지스터 정의
    // =============================================================
    wire w_rstn = ~btnC; // 내부적으로 Active Low 사용
    
    // UART 통신 신호
    wire [7:0] rx_byte;
    wire       rx_dv;
    reg  [7:0] tx_byte;
    reg        tx_dv;
    wire       tx_active;
    wire       tx_done;

    // CSR Matmul 코어 연결 신호
    reg  [11:0] core_addr;
    wire [31:0] core_dout;
    reg         core_cen;
    reg         core_wen;
    reg         core_matmul_en;
    wire        core_done;
    reg  [31:0] core_din;

    // FSM 상태 정의
    typedef enum reg [3:0] {
        S_IDLE,         // 's' 명령 대기
        S_CALC_START,   // 연산 시작 펄스
        S_CALC_WAIT,    // 연산 완료 대기
        S_READ_MEM,     // 결과 메모리 주소 설정
        S_WAIT_MEM,     // 메모리 출력 대기 (1-cycle)
        S_TX_BYTE3,     // 32비트 데이터 중 [31:24] 전송
        S_TX_BYTE2,     // 32비트 데이터 중 [23:16] 전송
        S_TX_BYTE1,     // 32비트 데이터 중 [15:8] 전송
        S_TX_BYTE0,     // 32비트 데이터 중 [7:0] 전송
        S_NEXT_ADDR     // 다음 주소로 이동 확인
    } state_t;

    state_t state;
    reg [9:0]  read_cnt;   // 1024개 데이터를 세기 위한 10비트 카운터
    reg [31:0] latch_data; // 메모리에서 읽은 32비트 데이터 임시 보관

    // =============================================================
    // 2. 모듈 인스턴스 (UART 및 CSR 코어)
    // =============================================================
    
    // UART 수신부 (Baud Rate: 9600, 100MHz 기준 CLKS_PER_BIT = 10416)
    uart_rx #(.CLKS_PER_BIT(10416)) u_rx (
        .i_clk(clk), .i_rx_serial(RsRx), .o_rx_dv(rx_dv), .o_rx_byte(rx_byte)
    );

    // UART 송신부
    uart_tx #(.CLKS_PER_BIT(10416)) u_tx (
        .i_clk(clk), .i_tx_dv(tx_dv), .i_tx_byte(tx_byte), .o_tx_active(tx_active), .o_tx_serial(RsTx), .o_tx_done(tx_done)
    );

    // CSR 행렬 곱셈 코어 (BRAM 5개 사용 버전)
    custom_csr_matmul DUT (
        .i_clk(clk),
        .i_rstn(w_rstn),
        .i_cen(core_cen),
        .i_wen(core_wen),
        .i_addr(core_addr),
        .i_din(core_din),
        .o_dout(core_dout),
        .i_matmul_en(core_matmul_en),
        .o_done(core_done)
    );

    // =============================================================
    // 3. 통합 제어 FSM
    // =============================================================
    always @(posedge clk or negedge w_rstn) begin
        if (!w_rstn) begin
            state <= S_IDLE;
            core_matmul_en <= 0;
            core_cen <= 1;
            core_wen <= 1;
            tx_dv <= 0;
            read_cnt <= 0;
            core_addr <= 0;
            core_din <= 0;
        end else begin
            case (state)
                // 1. 대기 상태: Python이 's'(0x73)를 보낼 때까지 대기
                S_IDLE: begin
                    core_matmul_en <= 0;
                    core_cen <= 1;
                    read_cnt <= 0;
                    tx_dv <= 0;
                    if (rx_dv && rx_byte == 8'h73) begin 
                        state <= S_CALC_START;
                    end
                end

                // 2. 연산 시작: 코어에 시작 신호 인가
                S_CALC_START: begin
                    core_matmul_en <= 1;
                    state <= S_CALC_WAIT;
                end

                // 3. 연산 대기: 코어가 o_done을 띄울 때까지 대기
                S_CALC_WAIT: begin
                    core_matmul_en <= 0;
                    if (core_done) state <= S_READ_MEM;
                end

                // 4. 결과 읽기: 결과 메모리(0xC00번지부터 시작) 주소 지정
                S_READ_MEM: begin
                    core_cen <= 0;
                    core_wen <= 1; // Read Mode
                    // custom_csr_matmul의 주소 맵핑에 따라 결과 램은 0xC00 (3072)부터 시작
                    core_addr <= 12'hC00 + read_cnt; 
                    state <= S_WAIT_MEM;
                end

                // 5. 대기: BRAM 출력 데이터가 안정화될 때까지 1클럭 대기
                S_WAIT_MEM: begin
                    state <= S_TX_BYTE3;
                end

                // 6. 데이터 전송 (MSB -> LSB 순서로 4바이트 전송)
                S_TX_BYTE3: begin
                    latch_data <= core_dout; // 32비트 값 래치
                    tx_byte <= core_dout[31:24];
                    tx_dv <= 1;
                    state <= S_TX_BYTE2;
                end
                
                S_TX_BYTE2: begin
                    tx_dv <= 0;
                    if (tx_done) begin
                        tx_byte <= latch_data[23:16];
                        tx_dv <= 1;
                        state <= S_TX_BYTE1;
                    end
                end

                S_TX_BYTE1: begin
                    tx_dv <= 0;
                    if (tx_done) begin
                        tx_byte <= latch_data[15:8];
                        tx_dv <= 1;
                        state <= S_TX_BYTE0;
                    end
                end

                S_TX_BYTE0: begin
                    tx_dv <= 0;
                    if (tx_done) begin
                        tx_byte <= latch_data[7:0];
                        tx_dv <= 1;
                        state <= S_NEXT_ADDR;
                    end
                end

                // 7. 다음 데이터 확인: 1024개 모두 보냈는지 체크
                S_NEXT_ADDR: begin
                    tx_dv <= 0;
                    if (tx_done) begin
                        if (read_cnt == 1023) begin
                            state <= S_IDLE; // 전송 완료
                        end else begin
                            read_cnt <= read_cnt + 1;
                            state <= S_READ_MEM;
                        end
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    // =============================================================
    // 4. 디버그 LED 설정
    // =============================================================
    assign led[0] = (state != S_IDLE);    // 연산 및 전송 중 불 켜짐
    assign led[1] = core_done;            // 연산 완료 시 불 켜짐
    assign led[2] = tx_active;            // UART 전송 중 깜빡임
    assign led[3] = w_rstn;               // 리셋 해제 상태 표시

endmodule