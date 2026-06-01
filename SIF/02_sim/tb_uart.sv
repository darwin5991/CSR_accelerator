`timescale 1ns / 1ps

module tb_top_uart_system();

    // =========================================================
    // 1. 테스트벤치 신호 정의
    // =========================================================
    reg         clk;
    reg         btnC;       // Reset 버튼 (Active High -> w_rstn = ~btnC)
    reg         RsRx;       // UART RX 입력 (PC -> FPGA)
    wire        RsTx;       // UART TX 출력 (FPGA -> PC)
    wire [3:0]  led;

    // UART 파라미터 (9600bps, 100MHz 클럭 기준)
    localparam CLKS_PER_BIT = 10416;
    localparam BIT_PERIOD   = CLKS_PER_BIT * 10; // 10ns * 10416 = 104160ns per bit

    // 수신 데이터 저장용
    reg [7:0]  received_bytes [0:4095];
    integer    rx_byte_cnt;
    reg [31:0] received_words [0:1023];

    // =========================================================
    // 2. DUT 인스턴스
    // =========================================================
    top_uart_system DUT (
        .clk(clk),
        .RsRx(RsRx),
        .RsTx(RsTx),
        .btnC(btnC),
        .led(led)
    );

    // =========================================================
    // 3. 클럭 생성 (100MHz = 10ns 주기)
    // =========================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // =========================================================
    // 4. UART TX Task (PC -> FPGA로 바이트 전송)
    // =========================================================
    task uart_send_byte(input [7:0] data);
        integer i;
        begin
            // Start bit (Low)
            RsRx = 0;
            #(BIT_PERIOD);
            
            // Data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                RsRx = data[i];
                #(BIT_PERIOD);
            end
            
            // Stop bit (High)
            RsRx = 1;
            #(BIT_PERIOD);
        end
    endtask

    // =========================================================
    // 5. UART RX Task (FPGA -> PC로 바이트 수신)
    // =========================================================
    task uart_receive_byte(output [7:0] data);
        integer i;
        begin
            // Start bit 감지 대기
            @(negedge RsTx);
            
            // Start bit 중간으로 이동
            #(BIT_PERIOD / 2);
            
            // Data bits 샘플링 (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                #(BIT_PERIOD);
                data[i] = RsTx;
            end
            
            // Stop bit 대기
            #(BIT_PERIOD);
        end
    endtask

    // =========================================================
    // 6. 자동 수신 프로세스 (백그라운드에서 실행)
    // =========================================================
    reg [7:0] rx_temp;
    
    initial begin
        rx_byte_cnt = 0;
        forever begin
            uart_receive_byte(rx_temp);
            received_bytes[rx_byte_cnt] = rx_temp;
            $display("[%0t] Received byte[%0d]: 0x%02X", $time, rx_byte_cnt, rx_temp);
            rx_byte_cnt = rx_byte_cnt + 1;
            
            // 4바이트마다 32비트 워드로 조합하여 출력
            if (rx_byte_cnt % 4 == 0) begin
                received_words[(rx_byte_cnt/4)-1] = {
                    received_bytes[rx_byte_cnt-4],  // Byte3 (MSB)
                    received_bytes[rx_byte_cnt-3],  // Byte2
                    received_bytes[rx_byte_cnt-2],  // Byte1
                    received_bytes[rx_byte_cnt-1]   // Byte0 (LSB)
                };
                $display("[%0t] Word[%0d]: 0x%08X", 
                    $time, (rx_byte_cnt/4)-1, received_words[(rx_byte_cnt/4)-1]);
            end
            
            // 1024개 워드 (4096바이트) 수신 완료 확인
            if (rx_byte_cnt >= 4096) begin
                $display("\n========================================");
                $display("All 1024 words received!");
                $display("========================================\n");
            end
        end
    end

    // =========================================================
    // 7. 메인 테스트 시퀀스
    // =========================================================
    // initial begin
    //     // 초기화
    //     RsRx = 1;   // UART Idle = High
    //     btnC = 1;   // Reset Active
        
    //     // 리셋 해제
    //     #1000;
    //     btnC = 0;
    //     #1000;
        
    //     $display("\n========================================");
    //     $display("Test Start: Sending 's' command...");
    //     $display("========================================\n");
        
    //     // 's' (0x73) 전송하여 연산 시작
    //     uart_send_byte(8'h73);
        
    //     $display("[%0t] 's' command sent, waiting for calculation...", $time);
        
    //     // LED 상태 모니터링
    //     wait(led[1] == 1);  // 연산 시작 확인
    //     $display("[%0t] Calculation started (LED[1] = 1)", $time);
        
    //     wait(led[1] == 0);  // 연산 완료 확인
    //     $display("[%0t] Calculation done (LED[1] = 0)", $time);
        
    //     // 데이터 전송 완료 대기 (4096 바이트 수신 대기)
    //     wait(rx_byte_cnt >= 4096);
    //     $display("[%0t] All data received!", $time);
        
    //     // 결과 요약 출력
    //     $display("\n========================================");
    //     $display("Test Complete!");
    //     $display("Total bytes received: %0d", rx_byte_cnt);
    //     $display("Total words received: %0d", rx_byte_cnt / 4);
    //     $display("========================================\n");
        
    //     // 처음 16개 워드 출력 (4x4 서브매트릭스)
    //     $display("First 16 words (4x4 result matrix):");
    //     for (int i = 0; i < 16; i = i + 1) begin
    //         $display("  C[%0d][%0d] = 0x%08X (%0d)", 
    //             i/4, i%4, received_words[i], $signed(received_words[i]));
    //     end
        
    //     $finish;
    // end
    initial begin
        // 초기화
        RsRx = 1;   // UART Idle = High
        btnC = 1;   // Reset Active
        
        // 리셋 해제
        #1000;
        btnC = 0;
        #1000;
        
        $display("\n========================================");
        $display("Test Start: Sending 's' command...");
        $display("========================================\n");
        
        // 's' (0x73) 전송하여 연산 시작
        uart_send_byte(8'h73);
        
        $display("[%0t] 's' command sent, waiting for calculation...", $time);
        
        // LED 상태 모니터링
        wait(led[1] == 1);  // 연산 시작 확인
        $display("[%0t] Calculation started (LED[1] = 1)", $time);
        
        wait(led[1] == 0);  // 연산 완료 확인
        $display("[%0t] Calculation done (LED[1] = 0)", $time);
        
        // 처음 64개 워드만 수신 대기 (256 바이트)
        wait(rx_byte_cnt >= 256);
        $display("[%0t] First 64 words received!", $time);
        
        // 결과 요약 출력
        $display("\n========================================");
        $display("Test Complete (Partial)!");
        $display("Total bytes received: %0d", rx_byte_cnt);
        $display("Total words received: %0d", rx_byte_cnt / 4);
        $display("========================================\n");
        
        // 처음 64개 워드 출력 (8x8 서브매트릭스)
        $display("First 64 words (8x8 result matrix):");
        for (int i = 0; i < 64; i = i + 1) begin
            $display("  C[%0d][%0d] = 0x%08X (%0d)", 
                i/8, i%8, received_words[i], $signed(received_words[i]));
        end
        
        $finish;
    end
    // =========================================================
    // 8. 타임아웃 (무한루프 방지)
    // =========================================================
    // initial begin
    //     // 최대 대기 시간 설정 (수신 완료 또는 타임아웃)
    //     fork
    //         begin
    //             // 정상 완료 대기
    //             wait(rx_byte_cnt >= 4096);
    //         end
    //         begin
    //             // 타임아웃: 마지막 수신 후 1초간 데이터 없으면 종료
    //             forever begin
    //                 @(rx_byte_cnt);  // rx_byte_cnt 변화 감지
    //                 #1000000000;     // 1초 대기 (1e9 ns)
    //             end
    //         end
    //     join_any
    //     disable fork;
        
    //     if (rx_byte_cnt < 4096) begin
    //         $display("\n[WARNING] Timeout: Only %0d bytes received (expected 4096)", rx_byte_cnt);
    //     end
    // end
    initial begin
        // 최대 대기 시간 설정 (수신 완료 또는 타임아웃)
        fork
            begin
                // 64개 워드 수신 완료 대기
                wait(rx_byte_cnt >= 256);
            end
            begin
                // 타임아웃: 마지막 수신 후 100ms간 데이터 없으면 종료
                forever begin
                    @(rx_byte_cnt);
                    #100000000;  // 100ms 대기
                end
            end
        join_any
        disable fork;
        
        if (rx_byte_cnt < 256) begin
            $display("\n[WARNING] Timeout: Only %0d bytes received (expected 256)", rx_byte_cnt);
        end
    end

    // =========================================================
    // 9. 상태 모니터링 (디버깅용)
    // =========================================================
    always @(posedge clk) begin
        // FSM 상태 변화 감지
        if (DUT.state !== $past(DUT.state)) begin
            $display("[%0t] State changed: %0d -> %0d", $time, $past(DUT.state), DUT.state);
        end
    end

endmodule