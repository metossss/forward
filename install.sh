#!/bin/bash

set -e

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Remove old files and configurations
sudo rm -f /usr/local/bin/dnsforwarder
sudo rm -f /etc/bind/named.conf.options
sudo rm -f /etc/bind/allowed-ips.acl

# Update system packages
sudo apt-get update
sudo apt-get install -y bind9 bind9utils bind9-doc python3 python3-pip git

# Install Flask
sudo pip3 install flask

# Add hostname to /etc/hosts
echo "127.0.0.1 $(hostname)" | sudo tee -a /etc/hosts

# Backup default named.conf file
sudo cp /etc/bind/named.conf /etc/bind/named.conf.backup

# Create allowed IP list file
sudo bash -c 'cat > /etc/bind/allowed-ips.acl << EOF
acl "allowed_ips" {
    192.168.1.0/24;
    10.0.0.1;
    localhost;
};
EOF'

# Configure BIND
sudo bash -c 'cat > /etc/bind/named.conf.options << EOF
include "/etc/bind/allowed-ips.acl";

options {
    directory "/var/cache/bind";
    forwarders {
        178.22.122.100;
        185.51.200.2;
    };
    dnssec-validation auto;
    auth-nxdomain no;
    listen-on-v6 { any; };
    allow-query { allowed_ips; };
    allow-recursion { allowed_ips; };
    allow-query-cache { allowed_ips; };
    max-cache-size 512M;
    recursive-clients 10000;
};
EOF'

# New method to clone or update the repository
REPO_URL="https://github.com/smaghili/dnsforwarder.git"
INSTALL_DIR="/opt/dnsforwarder"
SCRIPT_PATH="/usr/local/bin/dnsforwarder"

# Function to clone or update the repository and set up the script
setup_dns_proxy() {
    if [ ! -d "$INSTALL_DIR" ]; then
        sudo git clone "$REPO_URL" "$INSTALL_DIR"
    else
        (cd "$INSTALL_DIR" && sudo git pull)
    fi
    sudo cp "$INSTALL_DIR/dns_proxy.py" "$SCRIPT_PATH"
    sudo chmod +x "$SCRIPT_PATH"
    echo "DNS Forwarder repository setup completed."
}

# Call the setup function
setup_dns_proxy

# The rest of the script remains unchanged
# ...

# Create the dnsforwarder control script
sudo bash -c 'cat > /usr/local/bin/dnsforwarder << EOF
#!/bin/bash

CONFIG_FILE="/etc/bind/named.conf.options"
ALLOWED_IPS_FILE="/etc/bind/allowed-ips.acl"

update_forwarders() {
    local dns_servers="\$1"
    sudo sed -i "/forwarders {/,/};/c\\    forwarders {\n        \$dns_servers\n    };" "\$CONFIG_FILE"
    echo "Forwarders updated to: \$dns_servers"
    sudo systemctl restart named
    echo "BIND9 service restarted."
}

set_custom_dns() {
    read -p "Enter primary DNS server: " primary_dns
    read -p "Enter secondary DNS server (press Enter to skip): " secondary_dns
    if [ -z "\$secondary_dns" ]; then
        update_forwarders "\$primary_dns;"
    else
        update_forwarders "\$primary_dns; \$secondary_dns;"
    fi
}

add_allowed_ip() {
    local ip="\$1"
    if ! grep -q "\$ip;" "\$ALLOWED_IPS_FILE"; then
        sudo sed -i "/};/i \    \$ip;" "\$ALLOWED_IPS_FILE"
        echo "IP \$ip added to allowed list."
        sudo systemctl restart named
        echo "BIND9 service restarted."
    else
        echo "IP \$ip is already in the allowed list."
    fi
}

remove_allowed_ip() {
    local ip="\$1"
    if grep -q "\$ip;" "\$ALLOWED_IPS_FILE"; then
        sudo sed -i "/\$ip;/d" "\$ALLOWED_IPS_FILE"
        echo "IP \$ip removed from allowed list."
        sudo systemctl restart named
        echo "BIND9 service restarted."
    else
        echo "IP \$ip is not in the allowed list."
    fi
}

list_allowed_ips() {
    echo "Allowed IPs:"
    cat "\$ALLOWED_IPS_FILE"
}

enable_ip_limit() {
    sudo sed -i "s/allow-query { any; };/allow-query { allowed_ips; };/" "\$CONFIG_FILE"
    sudo sed -i "s/allow-recursion { any; };/allow-recursion { allowed_ips; };/" "\$CONFIG_FILE"
    sudo sed -i "s/allow-query-cache { any; };/allow-query-cache { allowed_ips; };/" "\$CONFIG_FILE"
    echo "IP restriction enabled. Only allowed IPs can access the DNS server."
    sudo systemctl restart named
    echo "BIND9 service restarted."
}

disable_ip_limit() {
    sudo sed -i "s/allow-query { allowed_ips; };/allow-query { any; };/" "\$CONFIG_FILE"
    sudo sed -i "s/allow-recursion { allowed_ips; };/allow-recursion { any; };/" "\$CONFIG_FILE"
    sudo sed -i "s/allow-query-cache { allowed_ips; };/allow-query-cache { any; };/" "\$CONFIG_FILE"
    echo "IP restriction disabled. All IPs are now allowed."
    sudo systemctl restart named
    echo "BIND9 service restarted."
}

case "\$1" in
    start)
        sudo systemctl start named
        echo "DNS forwarder started."
        ;;
    stop)
        sudo systemctl stop named
        echo "DNS forwarder stopped."
        ;;
    restart)
        sudo systemctl restart named
        echo "DNS forwarder restarted."
        ;;
    status)
        sudo systemctl status named
        ;;
    set)
        case "\$2" in
            shekan)
                update_forwarders "178.22.122.100; 185.51.200.2;"
                ;;
            radar)
                update_forwarders "10.202.10.10; 10.202.10.11;"
                ;;
            anti403)
                update_forwarders "10.202.10.202; 10.202.10.102;"
                ;;
            custom)
                set_custom_dns
                ;;
            *)
                echo "Usage: dnsforwarder set {shekan|radar|anti403|custom}"
                exit 1
                ;;
        esac
        ;;
    allow)
        if [ -z "\$2" ]; then
            echo "Usage: dnsforwarder allow <ip>"
            exit 1
        fi
        add_allowed_ip "\$2"
        ;;
    deny)
        if [ -z "\$2" ]; then
            echo "Usage: dnsforwarder deny <ip>"
            exit 1
        fi
        remove_allowed_ip "\$2"
        ;;
    list)
        list_allowed_ips
        ;;
    enable)
        if [ "\$2" = "iplimit" ]; then
            enable_ip_limit
        else
            echo "Usage: dnsforwarder enable iplimit"
            exit 1
        fi
        ;;
    disable)
        if [ "\$2" = "iplimit" ]; then
            disable_ip_limit
        else
            echo "Usage: dnsforwarder disable iplimit"
            exit 1
        fi
        ;;
    *)
        echo "Usage: dnsforwarder {start|stop|restart|status|set {shekan|radar|anti403|custom}|allow <ip>|deny <ip>|list|enable iplimit|disable iplimit}"
        exit 1
        ;;
esac

exit 0
EOF'

# Make the control script executable
sudo chmod +x /usr/local/bin/dnsforwarder

# Create directory for web panel
sudo mkdir -p /opt/dns-panel

# Get username and password for web panel
read -p "Enter username for web panel: " ADMIN_USERNAME
read -s -p "Enter password for web panel: " ADMIN_PASSWORD
echo

# Create config file for web panel
sudo bash -c "cat > /opt/dns-panel/config.py << EOF
ADMIN_USERNAME = '$ADMIN_USERNAME'
ADMIN_PASSWORD = '$ADMIN_PASSWORD'
EOF"

# Copy existing web panel files
sudo cp $INSTALL_DIR/webpanel.py /opt/dns-panel/
sudo mkdir -p /opt/dns-panel/templates
sudo cp $INSTALL_DIR/templates/index.html /opt/dns-panel/templates/
sudo cp $INSTALL_DIR/templates/login.html /opt/dns-panel/templates/

# Verify that files were copied successfully
if [ ! -f "/opt/dns-panel/webpanel.py" ]; then
    echo "ERROR: Failed to copy webpanel.py. Please make sure the file exists in the repository."
    exit 1
fi

if [ ! -f "/opt/dns-panel/templates/index.html" ] || [ ! -f "/opt/dns-panel/templates/login.html" ]; then
    echo "ERROR: Failed to copy HTML template files. Please make sure the files exist in the repository."
    exit 1
fi

echo "Web panel files copied successfully."

# Create systemd service for web panel
sudo bash -c 'cat > /etc/systemd/system/dns-panel.service << EOF
[Unit]
Description=DNS Forwarder Web Panel
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/dns-panel/webpanel.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF'

# Ensure BIND9 is running and enabled
sudo systemctl start named
sudo systemctl enable named

# Reload systemd, enable and start web panel service
sudo systemctl daemon-reload
sudo systemctl enable dns-panel
sudo systemctl start dns-panel

# Verify that BIND9 is running
if ! systemctl is-active --quiet named; then
    echo "ERROR: BIND9 (named) service is not running. Please check the logs for more information."
    exit 1
fi

# Print the IP of the server
echo "BIND DNS Server and Web Panel are configured and running."
echo "Set your clients to use this server's IP as their primary DNS:"
hostname -I | awk '{print $1}'
echo "Access the web panel at: http://$(hostname -I | awk '{print $1}'):5000"
echo "Installation complete. You can now use 'dnsforwarder' command to control the DNS forwarder."
echo "To manage IP restrictions, use:"
echo "  dnsforwarder enable iplimit     # To enable IP restriction"
echo "  dnsforwarder disable iplimit    # To disable IP restriction"
echo "  dnsforwarder allow <ip>         # To add an IP to the allowed list"
echo "  dnsforwarder deny <ip>          # To remove an IP from the allowed list"
echo "  dnsforwarder list               # To list allowed IPs"

# Verify that dnsforwarder command is working
if ! command_exists dnsforwarder; then
    echo "ERROR: dnsforwarder command is not available. Please check the installation logs."
    exit 1
fi

echo "Testing dnsforwarder command..."
dnsforwarder status

echo "Installation and configuration complete."
