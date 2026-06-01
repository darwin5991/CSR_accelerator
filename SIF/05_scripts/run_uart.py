import serial
import struct
import time

# ==============================================================================
# 1. 환경 설정
# ==============================================================================
COM_PORT = 'COM4'
BAUD_RATE = 9600
TIMEOUT = None  # 결과 수신 시 데이터가 다 올 때까지 대기

# 데이터 파일 경로 (사용자 파일명에 맞게 수정하세요)
FILES = {
    'ptr': 'amem_ptr.txt',
    'col': 'amem_col.txt',
    'val': 'amem_val.txt',
    'dense': 'bmem.txt'
}

# RTL 주소 맵 기반 설정
# 2'b00 (0x000): PTR(0~63) & DENSE(64~), 2'b01 (0x400): COL, 2'b10 (0x800): VAL
ADDR_MAP = {
    'ptr': 0x000,
    'dense': 0x040, # PTR 33개 이후 영역
    'col': 0x400,
    'val': 0x800
}

def send_data_packet(ser, file_path, start_addr):
    """파일을 읽어 [주소(2바이트) + 데이터(4바이트)] 패킷으로 전송"""
    try:
        with open(file_path, 'r') as f:
            lines = [line.strip() for line in f if line.strip()]
        
        print(f"📤 {file_path} 전송 중... ({len(lines)}개)")
        for i, hex_val in enumerate(lines):
            addr = start_addr + i
            # 16진수 문자열 -> 정수 변환
            data = int(hex_val, 16)
            
            # 패킷 구성: 주소(H, 2바이트) + 데이터(I, 4바이트). Big-endian(>)
            # ※ FPGA UART RX 로직의 수신 순서에 따라 'I' 또는 'H' 순서를 맞춰야 함
            packet = struct.pack('>HI', addr, data)
            ser.write(packet)
            time.sleep(0.001) # 전송 안정화를 위한 미세 지연
        return True
    except Exception as e:
        print(f"❌ {file_path} 전송 에러: {e}")
        return False

def run_fpga_csr_matmul():
    try:
        ser = serial.Serial(port=COM_PORT, baudrate=BAUD_RATE, timeout=TIMEOUT)
        print(f"🔌 {COM_PORT} 연결 성공")
        time.sleep(2)

        # 1. CSR 데이터 전송 (PTR -> COL -> VAL -> DENSE 순서)
        send_data_packet(ser, FILES['ptr'], ADDR_MAP['ptr'])
        send_data_packet(ser, FILES['col'], ADDR_MAP['col'])
        send_data_packet(ser, FILES['val'], ADDR_MAP['val'])
        send_data_packet(ser, FILES['dense'], ADDR_MAP['dense'])

        # 2. 연산 시작 명령 전송
        ser.reset_input_buffer()
        print("🚀 모든 데이터 전송 완료. 시작 명령('s') 전송!")
        ser.write(b's')

        # 3. 결과 수신 (32x32 = 1024개, 4096바이트)
        EXPECTED_BYTES = 4096
        print(f"📥 결과 수신 대기 중...")
        
        start_time = time.time()
        raw_bytes = ser.read(EXPECTED_BYTES)
        end_time = time.time()
        
        print(f"🎉 수신 완료! ({end_time - start_time:.2f}초)")

        # 4. 결과 저장 (Q4.4 부호 확장 및 값 해석 포함 가능)
        output_filename = "omem_csr_results.txt"
        with open(output_filename, "w") as f:
            for i in range(1024):
                chunk = raw_bytes[i*4 : (i+1)*4]
                val_hex = chunk.hex()
                addr = 0xC00 + i # 결과 메모리(RES) 시작 주소
                f.write(f"Addr {addr:03X} : {val_hex}\n")

        print(f"✅ 작업 완료. 결과가 '{output_filename}'에 저장되었습니다.")
        ser.close()

    except Exception as e:
        print(f"❌ 시스템 에러: {e}")

if __name__ == "__main__":
    run_fpga_csr_matmul()