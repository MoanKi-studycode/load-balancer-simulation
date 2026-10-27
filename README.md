# Thiết Lập và Đánh Giá Hiệu Năng Cân Bằng Tải với HAProxy trên Ubuntu Server

Dự án học phần **Linux Server và Quản trị Mạng** — **Nhóm 3 (Trường Đại học Nha Trang)**.

Hệ thống mô phỏng và kiểm chứng thực nghiệm cụm cân bằng tải tầng ứng dụng (Layer 7 HTTP Load Balancing) sử dụng **HAProxy** đứng trước 3 máy chủ **Flask + Gunicorn** trên nền tảng **Ubuntu Server LTS**, kết hợp cô lập mạng bằng tường lửa **UFW**, giới hạn tài nguyên bằng **systemd cgroups**, quản trị tập trung qua **Parallel-SSH** và kiểm thử chịu tải bằng **Locust**.

## Thông Tin Nhóm Thực Hiện

| Họ và tên | Mã số sinh viên | Vai trò & Phụ trách |
| :--- | :--- | :--- |
| **Trần Anh Tín** | 61131274 | Trưởng nhóm — Cấu hình cụm Ubuntu + HAProxy, chạy demo, tổng hợp báo cáo |
| **Trần Thanh Phúc** | 63132460 | Thành viên — Cấu hình cụm Ubuntu + HAProxy, kiểm thử chịu tải, viết báo cáo |
| **Nguyễn Trần Quốc Huy** | 61133083 | Thành viên — Cấu hình cụm Ubuntu + HAProxy, kịch bản demo, viết báo cáo |

* **Giảng viên hướng dẫn:** Nguyễn Mạnh Cương
* **Đơn vị:** Khoa Công nghệ Thông tin — Trường Đại học Nha Trang

## Mục Tiêu Kỹ Thuật

1. **Chia tải đồng đều (Round Robin):** Phân phối đều lưu lượng ~90 RPS (150 người dùng đồng thời) sang 3 máy chủ Backend (~30 RPS/máy), duy trì thời gian phản hồi ở mức vài chục mili-giây và tỷ lệ lỗi `0%`.
2. **Tự động phát hiện và cách ly lỗi (Health Check & Failover):** Kiểm tra sức khỏe định kỳ mỗi `1000ms` qua endpoint `GET /health`. Tự động tách máy chủ sập ra khỏi cụm sau 2 giây (`fall 2`) và chống hiện tượng chớp tắt (flapping) bằng ngưỡng phục hồi `rise 4`.
3. **Duy trì phiên làm việc (Sticky Sessions):** Định tuyến cố định người dùng về đúng máy chủ thông qua Cookie `SERVERID` (`insert indirect nocache`), kết hợp `option redispatch` để tự động chuyển tiếp sang máy chủ khác ngay lập tức khi máy giữ phiên gặp sự cố.
4. **Cô lập bảo mật và quản trị tập trung:** Khóa chặt cổng ứng dụng `5000/tcp` bằng tường lửa **UFW** (chỉ cho phép IP `192.168.56.10` của `lb-master` đi vào), ép trần phần cứng bằng **cgroups** (`CPUQuota=30%`, `MemoryMax=128M`) và điều khiển đồng loạt cụm máy chủ qua **Parallel-SSH**.

## Kiến Trúc Cụm Máy Chủ & Quy Hoạch IP

Hệ thống gồm **04 máy ảo Ubuntu Server LTS** (mỗi máy `1 vCPU`, `640 MB RAM`) kết nối qua dải mạng nội bộ `192.168.56.0/24`:

| Tên máy (Hostname) | Vai trò | Địa chỉ IP | Cổng dịch vụ | Dịch vụ chạy |
| :--- | :--- | :--- | :--- | :--- |
| **lb-master** | Load Balancer + Quản trị cụm | `192.168.56.10` | `80/tcp`, `8404/tcp` | HAProxy, Parallel-SSH |
| **web-01** | Backend Web Server 1 (`node1`) | `192.168.56.11` | `5000/tcp` (UFW khóa) | Flask + Gunicorn (2 workers), UFW |
| **web-02** | Backend Web Server 2 (`node2`) | `192.168.56.12` | `5000/tcp` (UFW khóa) | Flask + Gunicorn (2 workers), UFW |
| **web-03** | Backend Web Server 3 (`node3`) | `192.168.56.13` | `5000/tcp` (UFW khóa) | Flask + Gunicorn (2 workers), UFW |
| **Host Machine** | Máy vật lý phát tải & giám sát | `192.168.56.1` | `8089/tcp` (Locust UI) | Locust, Trình duyệt, SSH Client |

## Cấu Trúc Thư Mục Repository

Toàn bộ các tệp cấu hình, kịch bản điều khiển và tài liệu báo cáo trong dự án được tổ chức theo cấu trúc thư mục sau:

```text
haproxy-load-balancer-lab/
├── README.md                           # Tài liệu giới thiệu và hướng dẫn triển khai dự án
├── .gitignore                          # Bỏ qua các tệp tạm (__pycache__, *.pyc, .DS_Store)
├── config/
│   ├── sysctl-tuning.conf              # Tinh chỉnh thông số mạng nhân Linux trên cả 4 máy ảo
│   └── hosts.example                   # Cấu hình ánh xạ tên miền nội bộ (/etc/hosts)
├── backend/
│   ├── app.py                          # Ứng dụng Flask mô phỏng tải CPU (SHA-256) và /health
│   ├── flask-web.service               # Unit file systemd chạy Gunicorn kèm giới hạn cgroups
│   └── setup-ufw.sh                    # Kịch bản thiết lập tường lửa UFW cô lập cổng 5000
├── haproxy/
│   ├── haproxy.cfg                     # Cấu hình HAProxy trên lb-master (Round Robin, Sticky, Stats)
│   └── backends.txt                    # Danh sách các nút Backend phục vụ Parallel-SSH
├── scripts/
│   ├── cluster-aliases.sh              # Các phím tắt điều khiển cụm (mode-1node, mode-3nodes...)
│   └── demo-sticky.sh                  # Kịch bản kiểm thử tự động 5 bước Sticky Session & Failover
├── locust/
│   └── locustfile.py                   # Kịch bản bắn tải cố định ~90 RPS từ máy vật lý
└── docs/
    ├── BaoCaoDuAn_LoadBalancer_HAProxy_Nhom3.docx
    ├── Load_Balancer_bang_HAProxy_Nhom3.pptx
    └── images/                         # Thư mục lưu ảnh chụp màn hình thực nghiệm
```

## Chi Tiết Các Tệp Cấu Hình Cốt Lõi

### 1. Ứng dụng Backend (`backend/app.py`)

Ứng dụng Flask mô phỏng tác vụ tính toán CPU thực tế bằng vòng lặp băm `SHA-256` (`8.000` vòng, tiêu tốn ~25–30ms CPU/request) và cung cấp điểm cuối `/health` gọn nhẹ cho HAProxy:

```python
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
    return (
        f"<html><head><title>HAProxy Lab - {hostname}</title></head>"
        f"<body style='font-family: Arial, sans-serif; text-align: center; margin-top: 50px;'>"
        f"<h2>Phản hồi từ Node: <span style='color: #d9534f;'>{hostname}</span></h2>"
        f"<p><b>Địa chỉ IP Backend:</b> {local_ip}:5000</p>"
        f"<p><b>Client IP (X-Forwarded-For):</b> {request.headers.get('X-Forwarded-For', request.remote_addr)}</p>"
        f"<p><b>Thời gian xử lý CPU:</b> {process_time} ms</p>"
        f"</body></html>"
    )

@app.route('/health')
def health():
    return "OK", 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

### 2. Dịch vụ Systemd & Giới hạn Cgroups (`backend/flask-web.service`)

Đóng gói ứng dụng với **Gunicorn** (`2 workers`) và khóa trần tài nguyên mỗi máy ở mức `30% CPU` và `128 MB RAM`:

```ini
[Unit]
Description=Gunicorn instance to serve Flask Load Balancing Lab App
After=network.target

[Service]
User=ubuntu
Group=www-data
WorkingDirectory=/home/ubuntu/webapp
ExecStart=/usr/bin/python3 -m gunicorn --workers 2 --bind 0.0.0.0:5000 app:app
Restart=always
RestartSec=2
CPUQuota=30%
MemoryMax=128M

[Install]
WantedBy=multi-user.target
```

### 3. Kịch bản cô lập tường lửa UFW (`backend/setup-ufw.sh`)

Chặn mọi truy cập trực tiếp từ bên ngoài vào cổng `5000/tcp`, chỉ cho phép duy nhất IP của `lb-master` (`192.168.56.10`) đi qua:

```bash
#!/usr/bin/env bash
set -e
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow from 192.168.56.10 to any port 5000 proto tcp
sudo ufw --force enable
sudo ufw status numbered
```

### 4. Cấu hình Bộ cân bằng tải (`haproxy/haproxy.cfg`)

Cấu hình trên máy `lb-master` (`192.168.56.10`) với thuật toán `roundrobin`, Cookie `SERVERID`, `option redispatch`, kiểm tra sức khỏe `GET /health` và bảng giám sát tại cổng `8404`:

```haproxy
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    maxconn 4096

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    timeout connect 5000ms
    timeout client  50000ms
    timeout server  50000ms

frontend http_front
    bind *:80
    option forwardfor
    default_backend flask_cluster

backend flask_cluster
    balance roundrobin
    cookie SERVERID insert indirect nocache
    option redispatch
    option httpchk GET /health
    http-check expect status 200
    server node1 192.168.56.11:5000 check cookie node1 inter 1000ms fall 2 rise 4
    server node2 192.168.56.12:5000 check cookie node2 inter 1000ms fall 2 rise 4
    server node3 192.168.56.13:5000 check cookie node3 inter 1000ms fall 2 rise 4

listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /stats
    stats refresh 2s
    stats auth admin:admin123
    stats admin if TRUE
```

### 5. Phím tắt điều khiển cụm (`scripts/cluster-aliases.sh`)

Bổ sung vào `~/.bashrc` trên `lb-master` để chuyển đổi kịch bản nhanh trong lúc thuyết trình:

```bash
alias mode-1node='ssh web-01 "sudo systemctl restart flask-web" && ssh web-02 "sudo systemctl stop flask-web" && ssh web-03 "sudo systemctl stop flask-web"'
alias mode-3nodes='parallel-ssh -h ~/backends.txt -i "sudo systemctl restart flask-web"'
alias cluster-status='parallel-ssh -h ~/backends.txt -i "systemctl is-active flask-web"'
alias demo-ufw='echo "=== 1. Goi truc tiep web-01:5000 (Bi UFW chan) ===" && curl -m 3 -v http://192.168.56.11:5000 ; echo -e "\n=== 2. Goi qua HAProxy Cong 80 (Chia tai Round Robin) ===" && for i in {1..6}; do curl -s http://192.168.56.10 | grep "Phản hồi từ Node"; done'
```

### 6. Kịch bản kiểm thử 5 bước Sticky & Failover (`scripts/demo-sticky.sh`)

Đặt tại `/usr/local/bin/demo-sticky` trên `lb-master` để minh họa trực tiếp cơ chế giữ phiên bằng Cookie `SERVERID`, tự động chuyển đổi dự phòng (`option redispatch`) và ngưỡng chống chớp tắt (`rise 4`):

```bash
#!/usr/bin/env bash
rm -f /tmp/cookie_ sticky.txt
echo "=================================================================="
echo "[BƯỚC 1] Đảm bảo cả 3 Node Backend đang chạy bình thường..."
parallel-ssh -h ~/backends.txt "sudo systemctl restart flask-web" >/dev/null
sleep 5
echo "-> Đã bật cả 3 Node (web-01, web-02, web-03)!"

echo ""
echo "[BƯỚC 2] Người dùng A truy cập lần đầu và lưu Cookie (Sticky Session):"
for i in {1..6}; do
    NODE=$(curl -s -c /tmp/cookie_sticky.txt -b /tmp/cookie_sticky.txt http://192.168.56.10 | grep -oP 'web-0[1-3]')
    COOKIE_VAL=$(grep SERVERID /tmp/cookie_sticky.txt 2>/dev/null | awk '{print $7}')
    echo "   Lần gọi $i (Cookie SERVERID=$COOKIE_VAL) --> Phản hồi từ: $NODE"
done

PINNED_NODE=$(curl -s -b /tmp/cookie_sticky.txt http://192.168.56.10 | grep -oP 'web-0[1-3]')
echo ""
echo "[BƯỚC 3] Giả lập sự cố: Tắt dịch vụ trên $PINNED_NODE (Node đang giữ phiên)..."
ssh "$PINNED_NODE" "sudo systemctl stop flask-web"
sleep 3
echo "-> Đã dừng $PINNED_NODE! Người dùng A tiếp tục tải lại trang với Cookie cũ:"
for i in {1..4}; do
    NEW_NODE=$(curl -s -c /tmp/cookie_sticky.txt -b /tmp/cookie_sticky.txt http://192.168.56.10 | grep -oP 'web-0[1-3]')
    echo "   Failover lần $i --> Tự động chuyển sang: $NEW_NODE (Không lỗi 503!)"
done

echo ""
echo "[BƯỚC 4] Khôi phục lại $PINNED_NODE và kiểm tra cơ chế rise 4 (~4 giây):"
ssh "$PINNED_NODE" "sudo systemctl start flask-web"
sleep 5
echo "-> $PINNED_NODE đã UP trở lại! Người dùng A tiếp tục truy cập:"
for i in {1..3}; do
    CUR_NODE=$(curl -s -b /tmp/cookie_sticky.txt http://192.168.56.10 | grep -oP 'web-0[1-3]')
    echo "   Truy cập lần $i --> Vẫn giữ ổn định tại: $CUR_NODE"
done

echo ""
echo "[BƯỚC 5] Các người dùng mới hoàn toàn (không kèm Cookie) truy cập vào cụm:"
for i in {1..6}; do
    RR_NODE=$(curl -s http://192.168.56.10 | grep -oP 'web-0[1-3]')
    echo "   Khách mới $i --> Chia đều Round Robin vào: $RR_NODE"
done
echo "=================================================================="
```

### 7. Kịch bản kiểm thử chịu tải (`locust/locustfile.py`)

Chạy trên máy vật lý để phát lưu lượng cố định `90 RPS` (`150 users × 0.6 req/s`) và xóa Cookie sau mỗi lượt gọi nhằm mô phỏng 150 người dùng độc lập:

```python
from locust import HttpUser, task, constant_throughput

class WebsiteUser(HttpUser):
    wait_time = constant_throughput(0.6)

    @task
    def hit_homepage(self):
        self.client.cookies.clear()
        self.client.get("/")
```

## Kết Quả Thực Nghiệm Đối Chiếu

Thực nghiệm được tiến hành dưới cùng mức tải đầu vào **150 Concurrent Users** (nhu cầu cố định **~90 RPS**):

| Chỉ số đo lường | Kịch bản 2: `mode-1node` (1 máy đơn lẻ) | Kịch bản 3: `mode-3nodes` (Cụm 3 máy qua HAProxy) |
| :--- | :--- | :--- |
| **Trạng thái trên HAProxy Stats** | Chớp tắt xanh – đỏ liên tục (*flapping*), báo lỗi `L7TOUT in 1000ms` | Cả 3 node xanh lá ổn định (`L7OK/200`), cột `Dwn` đứng yên |
| **Lưu lượng đáp ứng (Total RPS)** | Kẹt ở ngưỡng **40–50 RPS** (vỡ trận khi chạm trần CPU 30%) | Đáp ứng trọn vẹn **~90 RPS** (~30 req/s chia đều mỗi máy) |
| **Hàng đợi Socket (`Recv-Q`)** | Ứ đọng **796 yêu cầu** tại cổng `5000` của `web-01` | Giải phóng hoàn toàn (`Recv-Q = 0`) |
| **Thời gian phản hồi trung vị** | Vọt lên **2.300 ms – 11.000 ms** | Giảm sâu về mức **30 ms – 60 ms** |
| **Tỷ lệ lỗi HTTP 503** | Xuất hiện lỗi `503 Service Unavailable` liên tục | **0%** (`0 Failures/s`) |
