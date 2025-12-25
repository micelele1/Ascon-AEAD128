import serial
import json
import time

SERIAL_PORT = "COM3"      # sesuaikan
BAUDRATE = 115200

ser = serial.Serial(SERIAL_PORT, BAUDRATE, timeout=2)

def send_to_fpga(payload: dict) -> dict:
    message = json.dumps(payload).encode("utf-8") + b"\n"
    ser.write(message)

    time.sleep(0.5)
    response = ser.readline().decode("utf-8")
    return json.loads(response)
