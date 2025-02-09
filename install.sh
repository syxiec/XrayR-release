#!/bin/bash

rm -rf $0

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "  lỗi：${plain} Tập lệnh này phải được chạy với tư cách người dùng gốc！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "  Phiên bản hệ thống không được phát hiện, vui lòng liên hệ với tác giả kịch bản！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
  arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
  arch="arm64-v8a"
else
  arch="64"
  echo -e "  Không phát hiện được giản đồ, hãy sử dụng lược đồ mặc định: ${arch}${plain}"
fi

echo "  Ngành kiến ​​trúc: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "  Phần mềm này không hỗ trợ hệ thống 32-bit (x86), vui lòng sử dụng hệ thống 64-bit (x86_64), nếu phát hiện sai, vui lòng liên hệ với tác giả"
    exit 2
fi

os_version=""

# phiên bản của hệ điều hành
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "  Vui lòng sử dụng CentOS 7 trở lên！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "  Vui lòng sử dụng Ubuntu 16 trở lên！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "  Vui lòng sử dụng Debian 8 trở lên！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
	yum install openssl -y
        yum install wget curl unzip tar crontabs socat -y
	firewall-cmd --zone=public --add-port=80/tcp --permanent
	firewall-cmd --zone=public --add-port=443/tcp --permanent
	firewall-cmd --reload
    else
        apt update -y
	apt install openssl -y
        apt install wget curl unzip tar cron socat -y
	ufw allow 80
	ufw allow 443
    fi
}

# 0: đang chạy, 1: không chạy, 2: chưa cài đặt
check_status() {
    if [[ ! -f /etc/systemd/system/XrayR.service ]]; then
        return 2
    fi
    temp=$(systemctl status XrayR | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

install_acme() {
    curl https://get.acme.sh | sh
}

install_XrayR() {
    if [[ -e /usr/local/XrayR/ ]]; then
        rm /usr/local/XrayR/ -rf
    fi

    mkdir /usr/local/XrayR/ -p
	cd /usr/local/XrayR/

    if  [ $# == 0 ] ;then
        last_version=$(curl -Ls "https://api.github.com/repos/qtai2901/xrayr/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "  Không phát hiện được phiên bản XrayR, có thể đã vượt quá giới hạn Github API, vui lòng thử lại sau hoặc chỉ định phiên bản XrayR để cài đặt $ theo cách thủ công{plain}"
            exit 1
        fi
        echo -e "  Đã phát hiện phiên bản mới nhất của XrayR：${last_version}，bắt đầu cài đặt"
        wget -N --no-check-certificate -O /usr/local/XrayR/XrayR-linux.zip https://github.com/qtai2901/xrayr/releases/download/${last_version}/XrayR-linux-${arch}.zip
        if [[ $? -ne 0 ]]; then
            echo -e "  Không tải xuống được XrayR, hãy đảm bảo máy chủ của bạn có thể tải xuống tệp Github ${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/qtai2901/xrayr/releases/download/${last_version}/XrayR-linux-${arch}.zip"
        echo -e "  Bắt đầu cài đặt XrayR v$1"
        wget -N --no-check-certificate -O /usr/local/XrayR/XrayR-linux.zip ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "  Không tải xuống được XrayR v $ 1, hãy đảm bảo rằng phiên bản này tồn tại ${plain}"
            exit 1
        fi
    fi

    unzip XrayR-linux.zip
    rm XrayR-linux.zip -f
    chmod +x XrayR
    mkdir /etc/XrayR/ -p
    rm /etc/systemd/system/XrayR.service -f
    file="https://github.com/qtai2901/XrayR-release/raw/main/XrayR.service"
    wget -N --no-check-certificate -O /etc/systemd/system/XrayR.service ${file}
    #cp -f XrayR.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl stop XrayR
    systemctl enable XrayR
    echo -e "  XrayR ${last_version}${plain} Quá trình cài đặt hoàn tất, nó đã được thiết lập để bắt đầu tự động"
    cp geoip.dat /etc/XrayR/
    cp geosite.dat /etc/XrayR/ 

    if [[ ! -f /etc/XrayR/config.yml ]]; then
        cp config.yml /etc/XrayR/
        echo -e ""
        echo -e "  Cài đặt mới, vui lòng tham khảo hướng dẫn trước：https://github.com/XrayR-project/XrayR，Định cấu hình nội dung cần thiết"
    else
        systemctl start XrayR
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "  XrayR đã khởi động lại thành công${plain}"
        else
            echo -e "  XrayR có thể không khởi động được, vui lòng sử dụng XrayR log để kiểm tra thông tin nhật ký sau này, nếu không khởi động được, định dạng cấu hình có thể đã bị thay đổi, vui lòng vào wiki để kiểm tra：https://github.com/XrayR-project/XrayR/wiki${plain}"
        fi
    fi

    if [[ ! -f /etc/XrayR/dns.json ]]; then
        cp dns.json /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/route.json ]]; then
        cp route.json /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/custom_outbound.json ]]; then
        cp custom_outbound.json /etc/XrayR/
    fi
    curl -o /usr/bin/XrayR -Ls https://raw.githubusercontent.com/qtai2901/XrayR-release/main/XrayR.sh
    chmod +x /usr/bin/XrayR
    ln -s /usr/bin/XrayR /usr/bin/xrayr # chữ thường tương thích
    chmod +x /usr/bin/xrayr
    echo -e ""
    echo "------------[Đậu Đậu việt hóa]------------"
    echo "  Cách sử dụng tập lệnh quản lý XrayR: "
    echo "------------------------------------------"
    echo "  XrayR              - Hiển thị menu quản trị (nhiều chức năng hơn) "
    echo "  XrayR start        - Khởi động XrayR "
    echo "  XrayR stop         - Dừng XrayR"
    echo "  XrayR restart      - Khởi động lại XrayR"
    echo "  XrayR status       - Xem trạng thái XrayR"
    echo "  XrayR enable       - Bật tự động khởi động XrayR"
    echo "  XrayR disable      - Hủy tự động khởi động XrayR"
    echo "  XrayR log          - Xem nhật ký XrayR"
    echo "  XrayR update       - Cập nhật XrayR"
    echo "  XrayR update x.x.x - Cập nhật phiên bản XrayR"
    echo "  XrayR install      - Cài đặt XrayR"
    echo "  XrayR uninstall    - Gỡ cài đặt XrayR "
    echo "  XrayR version      - Xem phiên bản XrayR"
    echo "------------------------------------------"
}
clear
show_menu() {
    echo -e ""
    echo -e "
    Các tập lệnh quản lý XrayR，không hoạt động với docker${plain}
${green}------ [Đậu Đậu việt hóa] ------${plain}
    0. Chỉnh sửa tệp cấu hình
————————————————————————————————
    1. Cài đặt XrayR
    2. Cập nhật XrayR
    3. Gỡ cài đặt XrayR
————————————————————————————————
    4. Khởi động XrayR
    5. Dừng XrayR
    6. Khởi động lại XrayR
    7. Xem trạng thái XrayR
    8. Xem nhật ký XrayR
————————————————————————————————
    9. Bật tự động khởi động XrayR 
   10. Hủy tự động khởi động XrayR
————————————————————————————————
   11. Cài đặt bbr (hạt nhân mới nhất)
   12. Xem phiên bản XrayR
   13. Nâng cấp Tập lệnh XrayR
————————————————————————————————   
 "
 #Các bản cập nhật tiếp theo có thể được thêm vào chuỗi trên
    show_status
    echo && read -p "  Vui lòng nhập một lựa chọn [0-13]: " num

    case "${num}" in
        0) config
        ;;
        1) check_uninstall && install
        ;;
        2) check_install && update
        ;;
        3) check_install && uninstall
        ;;
        4) check_install && start
        ;;
        5) check_install && stop
        ;;
        6) check_install && restart
        ;;
        7) check_install && status
        ;;
        8) check_install && show_log
        ;;
        9) check_install && enable
        ;;
        10) check_install && disable
        ;;
        11) install_bbr
        ;;
        12) check_install && show_XrayR_version
        ;;
        13) update_shell
        ;;
        *) echo -e "  Vui lòng nhập số chính xác [0-13]${plain}"
        ;;
    esac
}


if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0
        ;;
        "stop") check_install 0 && stop 0
        ;;
        "restart") check_install 0 && restart 0
        ;;
        "status") check_install 0 && status 0
        ;;
        "enable") check_install 0 && enable 0
        ;;
        "disable") check_install 0 && disable 0
        ;;
        "log") check_install 0 && show_log 0
        ;;
        "update") check_install 0 && update 0 $2
        ;;
        "config") config $*
        ;;
        "install") check_uninstall 0 && install 0
        ;;
        "uninstall") check_install 0 && uninstall 0
        ;;
        "version") check_install 0 && show_XrayR_version 0
        ;;
        "update_shell") update_shell
        ;;
        *) show_usage
    esac
else
    show_menu
fi
