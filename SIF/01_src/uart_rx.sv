module uart_rx #(
    parameter CLKS_PER_BIT = 10416 // 100MHz / 9600 baud
    )(
    input        i_clk,
    input        i_rx_serial,
    output       o_rx_dv,   // 데이터 받았다는 신호 (1클럭 펄스)
    output [7:0] o_rx_byte  // 받은 데이터 1바이트
    );
    
    localparam s_IDLE = 3'b000;
    localparam s_RX_START_BIT = 3'b001;
    localparam s_RX_DATA_BITS = 3'b010;
    localparam s_RX_STOP_BIT  = 3'b011;
    localparam s_CLEANUP      = 3'b100;
   
    reg [2:0] r_SM_Main = 0;
    reg [13:0] r_Clk_Count = 0;
    reg [2:0] r_Bit_Index = 0;
    reg [7:0] r_Rx_Byte = 0;
    reg r_Rx_DV = 0;
    
    assign o_rx_dv   = r_Rx_DV;
    assign o_rx_byte = r_Rx_Byte;
    
    always @(posedge i_clk) begin
        case (r_SM_Main)
            s_IDLE : begin
                r_Rx_DV       <= 1'b0;
                r_Clk_Count   <= 0;
                r_Bit_Index   <= 0;
                if (i_rx_serial == 1'b0) r_SM_Main <= s_RX_START_BIT;
                else                     r_SM_Main <= s_IDLE;
            end
            s_RX_START_BIT : begin
                if (r_Clk_Count == (CLKS_PER_BIT-1)/2) begin
                    if (i_rx_serial == 1'b0) begin
                        r_Clk_Count <= 0;
                        r_SM_Main   <= s_RX_DATA_BITS;
                    end else r_SM_Main <= s_IDLE;
                end else begin
                    r_Clk_Count <= r_Clk_Count + 1;
                    r_SM_Main   <= s_RX_START_BIT;
                end
            end
            s_RX_DATA_BITS : begin
                if (r_Clk_Count < CLKS_PER_BIT-1) begin
                    r_Clk_Count <= r_Clk_Count + 1;
                    r_SM_Main   <= s_RX_DATA_BITS;
                end else begin
                    r_Clk_Count          <= 0;
                    r_Rx_Byte[r_Bit_Index] <= i_rx_serial;
                    if (r_Bit_Index < 7) begin
                        r_Bit_Index <= r_Bit_Index + 1;
                        r_SM_Main   <= s_RX_DATA_BITS;
                    end else begin
                        r_Bit_Index <= 0;
                        r_SM_Main   <= s_RX_STOP_BIT;
                    end
                end
            end
            s_RX_STOP_BIT : begin
                if (r_Clk_Count < CLKS_PER_BIT-1) begin
                    r_Clk_Count <= r_Clk_Count + 1;
                    r_SM_Main   <= s_RX_STOP_BIT;
                end else begin
                    r_Rx_DV     <= 1'b1;
                    r_Clk_Count <= 0;
                    r_SM_Main   <= s_CLEANUP;
                end
            end
            s_CLEANUP : begin
                r_SM_Main <= s_IDLE;
                r_Rx_DV   <= 1'b0;
            end
            default : r_SM_Main <= s_IDLE;
        endcase
    end
endmodule