import serial
import json

SERIAL_PORT = "COM3"
BAUDRATE = 115200
TIMEOUT = 2

class FPGAConnectionError(Exception):
    pass

def send_to_fpga(payload: dict) -> dict:
    try:
        ser = serial.Serial(SERIAL_PORT, BAUDRATE, timeout=TIMEOUT)
    except serial.SerialException:
        raise FPGAConnectionError("FPGA not connected")

    try:
        ser.write((json.dumps(payload) + "\n").encode())

        response = ser.readline().decode().strip()
        if not response:
            raise FPGAConnectionError("No response from FPGA")

        return json.loads(response)

    finally:
        ser.close()
