`timescale 1ns / 1ps

module mm_tester32(
    input  wire        i_clk,       
    
    // SRAM 제어 신호
    output reg         o_cen,       
    output reg         o_wen,       
    output reg  [10:0] o_addr,      // [변경] 11비트 주소 (2048 공간)
    output reg  [31:0] o_din,       
    
    input  wire [31:0] i_dout,      
    
    output reg         o_rstn,      
    output reg         o_matmul_en, 
    output reg  [2:0]  o_fl,        
    input  wire        i_done       
    );

    // =================================================================
    // 1. 내부 메모리 변수 (32x32 크기에 맞춤)
    // =================================================================
    reg [15:0] amem_data [0:511];   // [수정] 512 Depth
    reg [15:0] bmem_data [0:511];   // [수정] 512 Depth
    reg [31:0] omem_golden [0:1023];// [수정] 1024 Depth (결과값)

    reg [256*8:1] aram_dir;
    reg [256*8:1] bram_dir;
    reg [256*8:1] oram_dir;

    integer i;
    integer err_cnt;

    // =================================================================
    // 2. 메인 테스트 프로세스
    // =================================================================
    initial begin
        // --- 0. 초기화 ---
        o_cen       = 1;
        o_wen       = 1; 
        o_addr      = 0;
        o_din       = 0;
        o_rstn      = 1;
        o_matmul_en = 0;
        o_fl        = 3'd4;
        err_cnt     = 0;

        // --- 파일 로드 (경로 확인 필수!) ---
        // .hex 파일이 없으면 .coe 파일 내용을 복사해서 .hex로 저장해서 쓰세요.
        // 혹은 $readmemh는 .txt 파일도 읽을 수 있습니다 (내용이 hex값만 있다면).
        $sformat(aram_dir, "C:/Users/kwang/Desktop/VSCODE/verilog_study/MYPROJECT/amem32.hex"); 
        $sformat(bram_dir, "C:/Users/kwang/Desktop/VSCODE/verilog_study/MYPROJECT/bmem32.hex");
        $sformat(oram_dir, "C:/Users/kwang/Desktop/VSCODE/verilog_study/MYPROJECT/golden_omem_hex_only.txt"); 
        
        // *주의: golden_omem.txt가 "Addr... : val" 형식이면 $readmemh로 못 읽습니다.
        // 값만 있는 순수한 hex 파일이 필요합니다.
        
        $readmemh(aram_dir, amem_data);
        $readmemh(bram_dir, bmem_data);
        $readmemh(oram_dir, omem_golden);
        
        $display(" [INFO] Hex Files Loaded. Starting 32x32 Verification...");

        // --- 1. 리셋 ---
        repeat(5) @(posedge i_clk);
        o_rstn = 0;
        repeat(5) @(posedge i_clk);
        o_rstn = 1;
        repeat(5) @(posedge i_clk);

        // --- 2. 데이터 쓰기 (Initialization) ---
        
        // (1) Matrix A 쓰기 (0~511번지)
        $display("[Time %0t] Writing AMEM (0~511)...", $time);
        for (i = 0; i < 512; i = i + 1) begin 
            @(posedge i_clk);
            o_cen   = 0; 
            o_wen   = 0;
            // 상위비트 00 + 9비트 주소 -> 11비트
            o_addr  = {2'b00, i[8:0]};
            o_din   = {16'b0, amem_data[i]};
        end
        @(posedge i_clk); o_cen = 1; o_wen = 1; 

        // (2) Matrix B 쓰기 (512~1023번지)
        $display("[Time %0t] Writing BMEM (0~511)...", $time);
        for (i = 0; i < 512; i = i + 1) begin 
            @(posedge i_clk);
            o_cen   = 0; 
            o_wen   = 0;
            // 상위비트 01 + 9비트 주소 -> 11비트
            o_addr  = {2'b01, i[8:0]};
            o_din   = {16'b0, bmem_data[i]};
        end
        @(posedge i_clk); o_cen = 1; o_wen = 1;

        $display("[INFO] Data Loading Complete.");
        repeat(10) @(posedge i_clk);

        // --- 3. 연산 수행 ---
        $display("[Time %0t] Start Matrix Multiplication...", $time);
        @(posedge i_clk);
        o_matmul_en = 1; 
        @(posedge i_clk);
        o_matmul_en = 0; 

        wait(i_done == 0); // Busy
        wait(i_done == 1); // Done
        
        $display("[Time %0t] Computation Completed.", $time);
        repeat(10) @(posedge i_clk);

        // --- 4. 결과 검증 ---
        $display("[Time %0t] Verifying OMEM Results...", $time);
        
        // (3) OMEM 읽기 (1024~2047번지 -> 총 1024개 데이터)
        for (i = 0; i < 1024; i = i + 1) begin
            @(posedge i_clk);
            o_cen   = 0;
            o_wen   = 1; // Read
            
            // 상위비트 10 + 9비트(안됨) -> 그냥 10비트 주소 사용 (1024 + i)
            // 즉, i가 0이면 1024(0x400), i가 1023이면 2047(0x7FF)
            o_addr  = 1024 + i;
            
            // Read Latency Wait
            @(posedge i_clk); 
            @(posedge i_clk);

            if (i_dout !== omem_golden[i]) begin
                $display("ERROR [Addr %0d]: Exp 0x%h, Got 0x%h", i, omem_golden[i], i_dout);
                err_cnt = err_cnt + 1;
            end
        end

        @(posedge i_clk);
        o_cen = 1;

        // --- 5. 최종 결과 ---
        if (err_cnt == 0) $display(" [SUCCESS] All 1024 outputs matched!");
        else              $display(" [FAILURE] Found %0d mismatches.", err_cnt);
        $finish;
    end
endmodule