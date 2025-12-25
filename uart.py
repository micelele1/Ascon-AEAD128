import serial
import json
import time

SERIAL_PORT = "COM5"
BAUDRATE = 115200

def send_to_fpga(payload: dict) -> dict:
    try:
        ser = serial.Serial(SERIAL_PORT, BAUDRATE, timeout=2)
        message = json.dumps(payload).encode() + b"\n"
        ser.write(message)

        time.sleep(0.5)
        response = ser.readline().decode().strip()
        ser.close()

        if not response:
            return {
                "status": "error",
                "message": "No response from FPGA"
            }

        return json.loads(response)

    except Exception as e:
        return {
            "status": "error",
            "message": f"FPGA not connected: {str(e)}"
        }
