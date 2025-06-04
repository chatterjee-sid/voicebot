# bluetooth_bridge.py
import serial
from flask import Flask, request

app = Flask(__name__)

# Change COM port and baudrate accordingly
ser = serial.Serial('COM5', 9600, timeout=1)

@app.route('/send', methods=['POST'])
def send_command():
    command = request.json.get('command', '') + '\n'
    ser.write(command.encode())
    return {'status': 'sent', 'command': command.strip()}

if __name__ == '__main__':
    app.run(port=5000)
