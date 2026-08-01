#!/bin/bash
clear
echo "DialPi Builder v0.1"
echo "--------------------"

echo -n "Updating package lists..."
if sudo apt-get update > /dev/null 2>&1; then
    echo "Done"
else
    echo "Failed"
    exit 1
fi

echo -n "Installing iptables, mgetty, ppp, and telnet packages..."
if sudo apt-get install -y iptables mgetty ppp inetutils-telnet > /dev/null 2>&1; then
    echo "Done"
else
    echo "Failed"
    exit 1
fi

echo -n "Configuring NAT via iptables..."
if sudo iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE > /dev/null 2>&1; then
    echo "Done"
else
    echo "Failed"
    exit 1
fi

echo -n "Installing iptables-persistent package..."
if sudo debconf-set-selections << 'EOF'
iptables-persistent iptables-persistent/autosave_v4 boolean true
iptables-persistent iptables-persistent/autosave_v6 boolean false
EOF
then
    if sudo apt-get install -y iptables-persistent > /dev/null 2>&1; then
        echo "Done"
    else
        echo "Failed"
        exit 1
    fi
else
    echo "Failed"
    exit 1
fi

echo -n "Enable IPv4 port forwarding..."
if sudo bash -c 'sed -i "/^#*.*net.ipv4.ip_forward/c\net.ipv4.ip_forward = 1" /etc/sysctl.conf || echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf' && sudo sysctl -p > /dev/null 2>&1; then
    echo "Done"
else
    echo "Failed"
    exit 1
fi

echo -n "Package clean-up..."
if sudo apt-get clean > /dev/null 2>&1; then
    echo "Done"
else
    echo "Failed"
    exit 1
fi

echo -n "Backup mgetty.config file..."
if sudo mv /etc/mgetty/mgetty.config /etc/mgetty/mgetty.orig > /dev/null 2>&1; then
    echo "Done"
else
    echo "Done (no existing file)"
fi

echo -n "Create mgetty.config file..."
if sudo tee /etc/mgetty/mgetty.config > /dev/null << 'EOF'
port ttyACM0
data-only yes
rings 2
speed 115200
term ansi
toggle-dtr no
issue-file /etc/issue.mgetty
login-prompt Enter Telnet host [port]:\040
debug 0
EOF
then
    echo "Done"
else
    echo "Failed"
    exit 1
fi

echo -n "Create telnet wrapper script..."
if sudo tee /usr/local/bin/telnet_wrapper.sh > /dev/null << 'EOF'
#!/bin/bash
read -r host port <<< "$1"
if [[ -n "$port" && "$port" =~ ^[0-9]+$ ]]; then
    /usr/bin/telnet "$host" "$port"
else
    /usr/bin/telnet "$host"
fi
pkill -f "mgetty /dev/ttyACM0"
exit 1
EOF
then
    if sudo chmod +x /usr/local/bin/telnet_wrapper.sh > /dev/null 2>&1; then
        echo "Done"
    else
        echo "Failed"
        exit 1
    fi
else
    echo "Failed"
    exit 1
fi

echo -n "Backup mgetty login.config file..."
if sudo mv /etc/mgetty/login.config /etc/mgetty/login.orig > /dev/null 2>&1; then
    echo "Done"
else
    echo "Done (no existing file)"
fi

echo -n "Create mgetty login.config file..."
if sudo tee /etc/mgetty/login.config > /dev/null << 'EOF'
/AutoPPP/ -     a_ppp   /usr/sbin/pppd
pi      -       -       /bin/login @
*       -       -       /usr/local/bin/telnet_wrapper.sh @
EOF
then
    if sudo chmod 600 /etc/mgetty/login.config > /dev/null 2>&1; then
        echo "Done"
    else
        echo "Failed"
        exit 1
    fi
else
    echo "Failed"
    exit 1
fi

echo -n "Create issue.mgetty file..."
if sudo rm /etc/issue.mgetty > /dev/null 2>&1; then
    : # File removed successfully or didn't exist
fi

if sudo tee /etc/issue.mgetty > /dev/null << 'EOF'
 _____     _         _           
|_   _|___| |___ ___| |_         
  | | | -_| |   | -_|  _|        
  |_| |___|_|_|_|___|_|          
 _____     _                     
|   __|___| |_ ___ _ _ _ ___ _ _ 
|  |  | .'|  _| -_| | | | .'| | |
|_____|__,|_| |___|_____|__,|_  |
                            |___|

DialPi/\s \D \T
EOF
then
    echo "Done"
else
    echo "Failed"
    exit 1
fi

echo -n "Create udev rule for modem hotplug..."
if sudo tee /etc/udev/rules.d/99-dialpi-modem.rules > /dev/null << 'EOF'
ACTION=="add", SUBSYSTEM=="tty", KERNEL=="ttyACM0", TAG+="systemd", ENV{SYSTEMD_WANTS}+="mgetty.service"
EOF
then
    if sudo udevadm control --reload-rules > /dev/null 2>&1 && sudo udevadm trigger > /dev/null 2>&1; then
        echo "Done"
    else
        echo "Failed"
        exit 1
    fi
else
    echo "Failed"
    exit 1
fi

echo -n "Create mgetty.service systemd unit file..."
sudo systemctl stop mgetty.service > /dev/null 2>&1
sudo systemctl disable mgetty.service > /dev/null 2>&1
sudo rm /lib/systemd/system/mgetty.service > /dev/null 2>&1

if sudo tee /lib/systemd/system/mgetty.service > /dev/null << 'EOF'
[Unit]
Description=External Modem
Documentation=man:mgetty(8)
BindsTo=dev-ttyACM0.device
After=dev-ttyACM0.device
ConditionPathExists=/dev/ttyACM0

[Service]
Type=simple
ExecStart=/sbin/mgetty /dev/ttyACM0
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
then
    if sudo systemctl daemon-reload > /dev/null 2>&1 && sudo systemctl enable mgetty.service > /dev/null 2>&1; then
        echo "Done"
    else
        echo "Failed"
        exit 1
    fi
else
    echo "Failed"
    exit 1
fi

echo -n "Starting mgetty.service..."
if [ -e /dev/ttyACM0 ]; then
    if sudo systemctl start mgetty.service > /dev/null 2>&1; then
        echo "Done"
    else
        echo "Failed"
        exit 1
    fi
else
    echo "Skipped (modem not currently plugged in; will start automatically on hotplug)"
fi

echo -n "Backup PPP options file..."
if sudo mv /etc/ppp/options /etc/ppp/options.orig > /dev/null 2>&1; then
    echo "Done"
else
    echo "Done (no existing file)"
fi

echo -n "Create PPP options file..."
if sudo tee /etc/ppp/options > /dev/null << 'EOF'
modem
crtscts
lcp-echo-interval 30
lcp-echo-failure 4
debug
192.192.1.1:192.192.1.2
ms-dns 8.8.8.8
asyncmap 0
passive
noipx
noipv6
noccp
EOF
then
    echo "Done"
else
    echo "Failed"
    exit 1
fi

echo -n "Checking if ttyACM0 exists..."
if [ -e /dev/ttyACM0 ]; then
    echo "Done"
else
    echo "Warning: /dev/ttyACM0 not found"
fi
echo
echo "DialPi setup complete!"
echo
