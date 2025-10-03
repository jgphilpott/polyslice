import time
import serial

port = serial.Serial("/dev/tty.usbserial-10", 115200)

port.write("G28\n".encode())

time.sleep(1)

port.close()