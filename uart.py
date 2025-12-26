import serial

SERIAL_PORT = "COM3"
BAUDRATE = 115200
TIMEOUT = 2
FRAME_SIZE = 64

class FPGAConnectionError(Exception):
    pass

class FPGAProtocolError(Exception):
    pass


def send_to_fpga(frame: bytes) -> bytes:
    if len(frame) != FRAME_SIZE:
        raise ValueError("Frame must be exactly 64 bytes")

    try:
        ser = serial.Serial(SERIAL_PORT, BAUDRATE, timeout=TIMEOUT)
    except serial.SerialException:
        raise FPGAConnectionError("FPGA not connected")

    try:
        # Kirim frame 64 byte
        ser.write(frame)

        # Terima output 64 byte
        response = ser.read(FRAME_SIZE)
        if len(response) != FRAME_SIZE:
            raise FPGAProtocolError("Incomplete response from FPGA")

        return response

    finally:
        ser.close()
