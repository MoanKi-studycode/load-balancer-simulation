#!/usr/bin/env bash
rm -f /tmp/cookie_sticky.txt
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
