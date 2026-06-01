## =========================================================
## Clock Signal (Basys 3 Board: 100MHz Oscillator -> Pin W5)
## =========================================================
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## =========================================================
## Configuration Bank Voltage Select (For Bitstream Safety)
## =========================================================
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

## =========================================================
## *참고: 나머지 신호(addr, din, dout 등)는 VIO가 제어하므로
##       물리적 핀(LED, Switch) 연결이 필요 없습니다.
## =========================================================