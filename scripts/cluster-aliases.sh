alias mode-1node='ssh web-01 "sudo systemctl restart flask-web" && ssh web-02 "sudo systemctl stop flask-web" && ssh web-03 "sudo systemctl stop flask-web"'
alias mode-3nodes='parallel-ssh -h ~/backends.txt -i "sudo systemctl restart flask-web"'
alias cluster-status='parallel-ssh -h ~/backends.txt -i "systemctl is-active flask-web"'
alias demo-ufw='echo "=== 1. Goi truc tiep web-01:5000 (Bi UFW chan) ===" && curl -m 3 -v http://192.168.56.11:5000 ; echo -e "\n=== 2. Goi qua HAProxy Cong 80 (Chia tai Round Robin) ===" && for i in {1..6}; do curl -s http://192.168.56.10 | grep "Phản hồi từ Node"; done'
