from flask import Flask, request
import socket
import time
import hashlib

app = Flask(__name__)

@app.route('/')
def index():
    start_time = time.time()
    data = b"Load_Balancer_Stress_Test_Payload"
    for _ in range(8000):
        data = hashlib.sha256(data).digest()
    process_time = round((time.time() - start_time) * 1000, 2)
    hostname = socket.gethostname()
    local_ip = socket.gethostbyname(hostname)
    return f"""
    <html>
    <head><title>HAProxy Lab - {hostname}</title></head>
    <body style="font-family: Arial, sans-serif; text-align: center; margin-top: 50px;">
        <h2>Phản hồi từ Node: <span style="color: #d9534f;">{hostname}</span></h2>
        <p><b>Địa chỉ IP Backend:</b> {local_ip}:5000</p>
        <p><b>Client IP (X-Forwarded-For):</b> {request.headers.get('X-Forwarded-For', request.remote_addr)}</p>
        <p><b>Thời gian xử lý CPU:</b> {process_time} ms</p>
    </body>
    </html>
    """

@app.route('/health')
def health():
    return "OK", 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
