# DialPi

A shell build script to configure a Raspberry Pi as a dial-up provider (both Telnet and PPP), via USB-connected modem.

## What It Does

DialPi turns your Raspberry Pi into a dial-up server with a real modem. Vintage computers can dial in via traditional phone lines to access Telnet services or establish PPP connections for internet access. It's like running your own ISP from 1995.

![sl_s](https://github.com/user-attachments/assets/92f31014-fea1-4815-8ab5-592701f231c5)

![pstn_s](https://github.com/user-attachments/assets/752bb3b4-f8e2-4d3c-85f8-b8f680fb457c)


## Hardware Requirements

- **Raspberry Pi Zero 2 W** (tested) or similar model
- **USB modem** (appears as `/dev/ttyACM0`)
- **Phone line or line simulator** (can also test with direct modem-to-modem connection, if supported by the modems-in-question)
- **WiFi connection** (for routing internet to dial-in clients)

## What Gets Installed

- **mgetty** - Handles incoming modem calls and presents login prompt
- **pppd** - PPP daemon for dial-up internet connections
- **iptables** - NAT configuration to share WiFi connection
- **Telnet** - For outbound Telnet connections from dial-in users

## Installation

1. Flash a fresh Raspberry Pi OS Lite image to your SD card
2. Configure WiFi and enable SSH
3. Connect your USB modem (verify it appears as `/dev/ttyACM0`)
4. Copy `dialpi.sh` to your Raspberry Pi
5. Run the script:
```bash
chmod +x dialpi.sh
./dialpi.sh
```

The script will automatically install and configure everything needed.

## Default Configuration

- **Modem device**: `/dev/ttyACM0`
- **Answer after**: 2 rings
- **Modem speed**: 115200 (DTE speed to modem)
- **PPP IP range**: 192.192.1.1/192.192.1.2

## Usage

### Dialing In

DialPi automatically detects the type of connection and responds accordingly:

**Terminal/Telnet Mode:**
When dialing in with a terminal emulator, you'll see a custom ASCII art welcome screen and a prompt:

```
Enter Telnet host [port]:
```

**Options at the prompt:**
1. **Telnet to a remote host**: Type `hostname` or `hostname port`
   - Example: `bbs.example.com` or `bbs.example.com 2323`

2. **Login as pi user**: Type `pi` and use the pi account password
   - Provides shell access to the Raspberry Pi

**PPP Mode:**
When dialing in with a PPP client (Dial-Up Networking, etc.), mgetty automatically detects the PPP negotiation and initiates the connection - no manual input needed. Simply configure your vintage computer's PPP dialer and connect.

*Note: PPP authentication is not configured, so you can enter any username/password in your client's dial-up settings - they won't be validated.*

### Testing Without Phone Lines

You can test with two modems connected back-to-back:
- Connect one modem's phone line to another's
- Dial from vintage computer through first modem
- Second modem (on DialPi) will answer

## Customization

### Change Modem Device

If your modem appears as something other than `/dev/ttyACM0`, edit:
- `/etc/mgetty/mgetty.config` - change `port ttyACM0`
- `/lib/systemd/system/mgetty.service` - change device references

Then run:
```bash
sudo systemctl daemon-reload
sudo systemctl restart mgetty
```

### Modify Ring Count

Edit `/etc/mgetty/mgetty.config`:
```
rings 2    # Change to desired number of rings
```

### Change Welcome Screen

Edit `/etc/issue.mgetty` to customize the ASCII art banner.

### PPP IP Addresses

Edit `/etc/ppp/options`:
```
192.192.1.1:192.192.1.2    # server:client format
```

### DNS Servers for PPP Clients

Edit `/etc/ppp/options`:
```
ms-dns 8.8.8.8    # Change to your preferred DNS
```

## Troubleshooting

**Modem not detected:**
- Check device exists: `ls -l /dev/ttyACM*`
- Verify USB modem is connected and powered
- Check service status: `sudo systemctl status mgetty`

**Modem doesn't answer:**
- Verify phone line is connected
- Check modem is in auto-answer mode
- View logs: `sudo journalctl -u mgetty -f`

**PPP won't connect:**
- Enable debug mode in `/etc/ppp/options` (uncomment `debug`)
- Check system logs: `sudo journalctl -f`
- Verify NAT: `sudo iptables -t nat -L`

**No internet after PPP connection:**
- Check IP forwarding: `cat /proc/sys/net/ipv4/ip_forward` (should be 1)
- Verify iptables NAT rule: `sudo iptables -t nat -L POSTROUTING`

## Service Management

```bash
sudo systemctl status mgetty     # Check status
sudo systemctl restart mgetty    # Restart after config changes
sudo systemctl stop mgetty       # Stop service
sudo systemctl start mgetty      # Start service
```

## Technical Details

- mgetty monitors `/dev/ttyACM0` and answers incoming calls
- Login prompt accepts three input types: hostnames (Telnet), `/AutoPPP/` (PPP), or `pi` (shell)
- PPP connections are authenticated with any username/password
- NAT shares WiFi internet connection with dial-in PPP clients
- Service automatically restarts if modem disconnects and reconnects

## File Locations

- **Configuration**: `/etc/mgetty/mgetty.config`
- **Login routing**: `/etc/mgetty/login.config`
- **Welcome screen**: `/etc/issue.mgetty`
- **PPP options**: `/etc/ppp/options`
- **Telnet wrapper**: `/usr/local/bin/telnet_wrapper.sh`

## License

This script is provided as-is for hobbyist and educational use.

## Credits

Built for retro computing enthusiasts and vintage dial-up nostalgia.
