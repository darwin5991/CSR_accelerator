### Clock signal (100 MHz)
#set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { i_clk }];
#create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { i_clk }];

### Reset Button (보통 CPU_RESET 버튼은 C12 핀, 하이 액티브/로우 액티브 확인 필요)
### 아래는 Nexys A7의 CPU_RESET 버튼(N17 - 하이 액티브 기준) 예시입니다.
#set_property -dict { PACKAGE_PIN N17   IOSTANDARD LVCMOS33 } [get_ports { i_rst }];

### UART Interface
## USB-RS232 Interface
## FPGA_TXD (FPGA에서 나가는 선 -> PC가 받는 RX)
#set_property -dict { PACKAGE_PIN D4    IOSTANDARD LVCMOS33 } [get_ports { o_tx_serial }];
## FPGA_RXD (PC에서 들어오는 선 -> FPGA가 받는 RX)
#set_property -dict { PACKAGE_PIN C4    IOSTANDARD LVCMOS33 } [get_ports { i_rx_serial }];



## Clock Signal (100MHz)
set_property PACKAGE_PIN W5 [get_ports i_clk]
set_property IOSTANDARD LVCMOS33 [get_ports i_clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports i_clk]

## Reset Button (Center Button)
set_property PACKAGE_PIN U18 [get_ports i_rst]
set_property IOSTANDARD LVCMOS33 [get_ports i_rst]

## USB-RS232 Interface
## FPGA 입장에서 수신(RX)은 B18, 송신(TX)은 A18 핀입니다.
set_property PACKAGE_PIN B18 [get_ports i_rx_serial]
set_property IOSTANDARD LVCMOS33 [get_ports i_rx_serial]

set_property PACKAGE_PIN A18 [get_ports o_tx_serial]
set_property IOSTANDARD LVCMOS33 [get_ports o_tx_serial]

## Configuration Voltage
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]





# ## LEDs (0~3번)
# set_property PACKAGE_PIN U16 [get_ports {led[0]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]

# set_property PACKAGE_PIN E19 [get_ports {led[1]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]

# set_property PACKAGE_PIN U19 [get_ports {led[2]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]

# set_property PACKAGE_PIN V19 [get_ports {led[3]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]