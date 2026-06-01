module tb_csr_matmul();
    // 테스트벤치 신호 정의
    reg         clk;
    reg         rstn;
    reg         cen;
    reg         wen;
    reg  [11:0] addr;
    wire [31:0] dout;
    reg         matmul_en;
    wire        done;

    // 기대값 저장 배열
    reg [31:0] expected_c [0:1023];
    reg [31:0] read_data;
    
    // 비교 결과 카운터
    integer match_count;
    integer mismatch_count;
    integer i;
    
    // DUT 인스턴스
    custom_csr_matmul DUT (
        .i_clk(clk),
        .i_rstn(rstn),
        .i_cen(cen),
        .i_wen(wen),
        .i_addr(addr),
        .i_din(32'd0),
        .i_matmul_en(matmul_en),
        .o_dout(dout),
        .o_done(done)
    );

    // 클럭 생성 (100MHz = 10ns 주기)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 기대값 로드 (HEX 파일 사용)
    initial begin
        $readmemh("C:/Users/darwin5991/Desktop/Verilog/sparse_c.hex", expected_c);
    end

    // 결과 읽기 태스크
    task read_result;
        input [9:0] index;
        output [31:0] data;
        begin
            @(posedge clk);
            cen = 0;
            wen = 1;  // 읽기
            addr = {2'b11, index};  // RAM_RES 주소 영역
            @(posedge clk);
            @(posedge clk);  // BRAM 레이턴시 대기
            data = dout;
            cen = 1;
        end
    endtask

    // 테스트 시퀀스
    initial begin
        // 초기화
        rstn = 0;
        matmul_en = 0;
        cen = 1;
        wen = 1;
        addr = 0;
        match_count = 0;
        mismatch_count = 0;
        #20;
        
        rstn = 1;
        #20;

        // 행렬 곱셈 시작
        $display("========================================");
        $display("CSR Matrix Multiplication Test Started");
        $display("========================================");
        $display("Time: %0t", $time);
        
        matmul_en = 1;
        #10;
        matmul_en = 0;

        // 완료 대기
        wait (done);
        $display("Computation Done! Time: %0t", $time);
        #100;

        // 결과 비교
        $display("");
        $display("========================================");
        $display("Result Comparison");
        $display("========================================");
        
        for (i = 0; i < 1024; i = i + 1) begin
            read_result(i, read_data);
            
            if (read_data !== expected_c[i]) begin
                if (mismatch_count < 20) begin
                    $display("MISMATCH [%2d][%2d]: Got=%h, Expected=%h", 
                             i/32, i%32, read_data, expected_c[i]);
                end
                mismatch_count = mismatch_count + 1;
            end else begin
                match_count = match_count + 1;
            end
        end
        
        // 최종 결과 출력
        $display("");
        $display("========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Total Elements: 1024");
        $display("Matched:        %0d", match_count);
        $display("Mismatched:     %0d", mismatch_count);
        
        if (mismatch_count == 0)
            $display("TEST PASSED!");
        else
            $display("TEST FAILED!");
        
        $display("========================================");
        
        #100;
        $finish;
    end

endmodule