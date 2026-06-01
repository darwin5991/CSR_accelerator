module uart_tx #(
    parameter CLKS_PER_BIT = 10416 // 100MHz / 9600 baud
    )(
    input       i_clk,
    input       i_tx_dv,    // 전송 시작 신호
    input [7:0] i_tx_byte,  // 보낼 데이터 1바이트
    output      o_tx_active,// 전송 중임
    output reg  o_tx_serial,// TX 핀으로 나가는 신호
    output      o_tx_done   // 전송 끝
    );
 
    localparam s_IDLE         = 3'b000;
    localparam s_TX_START_BIT = 3'b001;
    localparam s_TX_DATA_BITS = 3'b010;
    localparam s_TX_STOP_BIT  = 3'b011;
    localparam s_CLEANUP      = 3'b100;
   
    reg [2:0] r_SM_Main = 0;
    reg [13:0] r_Clk_Count = 0;
    reg [2:0] r_Bit_Index = 0;
    reg [7:0] r_Tx_Data = 0;
    reg r_Tx_Done = 0;
    reg r_Tx_Active = 0;
     
    assign o_tx_active = r_Tx_Active;
    assign o_tx_done   = r_Tx_Done;
   
    always @(posedge i_clk) begin
        case (r_SM_Main)
            s_IDLE : begin
                o_tx_serial <= 1'b1;
                r_Tx_Done   <= 1'b0;
                r_Clk_Count <= 0;
                r_Bit_Index <= 0;
                
                if (i_tx_dv == 1'b1) begin
                    r_Tx_Active <= 1'b1;
                    r_Tx_Data   <= i_tx_byte;
                    r_SM_Main   <= s_TX_START_BIT;
                end else begin
                    r_Tx_Active <= 1'b0;
                    r_SM_Main   <= s_IDLE;
                end
            end
            s_TX_START_BIT : begin
                o_tx_serial <= 1'b0;
                if (r_Clk_Count < CLKS_PER_BIT-1) begin
                    r_Clk_Count <= r_Clk_Count + 1;
                    r_SM_Main   <= s_TX_START_BIT;
                end else begin
                    r_Clk_Count <= 0;
                    r_SM_Main   <= s_TX_DATA_BITS;
                end
            end
            s_TX_DATA_BITS : begin
                o_tx_serial <= r_Tx_Data[r_Bit_Index];
                if (r_Clk_Count < CLKS_PER_BIT-1) begin
                    r_Clk_Count <= r_Clk_Count + 1;
                    r_SM_Main   <= s_TX_DATA_BITS;
                end else begin
                    r_Clk_Count <= 0;
                    if (r_Bit_Index < 7) begin
                        r_Bit_Index <= r_Bit_Index + 1;
                        r_SM_Main   <= s_TX_DATA_BITS;
                    end else begin
                        r_Bit_Index <= 0;
                        r_SM_Main   <= s_TX_STOP_BIT;
                    end
                end
            end
            s_TX_STOP_BIT : begin
                o_tx_serial <= 1'b1;
                if (r_Clk_Count < CLKS_PER_BIT-1) begin
                    r_Clk_Count <= r_Clk_Count + 1;
                    r_SM_Main   <= s_TX_STOP_BIT;
                end else begin
                    r_Tx_Done   <= 1'b1;
                    r_Clk_Count <= 0;
                    r_SM_Main   <= s_CLEANUP;
                    r_Tx_Active <= 1'b0;
                end
            end
            s_CLEANUP : begin
                r_Tx_Done <= 1'b1;
                r_SM_Main <= s_IDLE;
            end
            default : r_SM_Main <= s_IDLE;
        endcase
    end
endmodule