#!/bin/bash

InterfaceName="eth0"
NewIP="192.168.16.21/24"
Gateway="192.168.16.2"
DNSserver="192.168.16.2"
Hostname="server1"

# Check if the netplan configuration file exists
if [ -f "/etc/netplan/01-netcfg.yaml" ]; then
# Checking if the configuration is already there
    if grep -qF "$InterfaceName" /etc/netplan/01-netcfg.yaml; then
        echo "The configuration is already there for $InterfaceName"
    else
        sudo tee -a /etc/netplan/01-netcfg.yaml >/dev/null <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    ${InterfaceName}:
      addresses:
        - ${NewIP}
      routes:
        - to: 0.0.0.0/0
          via: ${Gateway}
      nameservers:
        addresses:
          - ${DNSserver}
EOF
        echo "The configuration has been updated for interface $InterfaceName"
        sudo netplan apply
    fi
#Creating file for netplan configuration
else
    sudo tee /etc/netplan/01-netcfg.yaml >/dev/null <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    ${InterfaceName}:
      addresses:
        - ${NewIP}
      routes:
        - to: 0.0.0.0/0
          via: ${Gateway}
      nameservers:
        addresses:
          - ${DNSserver}
EOF
    echo "Netplan configuration file created for interface $InterfaceName"
    sudo netplan apply
fi

# Updating the /etc/hosts file
if grep -qF "$Hostname" /etc/hosts && grep -qF "$NewIP" /etc/hosts; then
    echo "The IP address $NewIP already exists in /etc/hosts for the hostname $Hostname"
else
    sudo sed -i "/^${NewIP%%/*}\s\+${Hostname}\$/d" /etc/hosts
    sudo sed -i "1s/^/${NewIP%%/*} ${Hostname}\n/" /etc/hosts
    echo "The hostname $Hostname and the IP address $NewIP have been updated in /etc/hosts"
fi

#### Firewall implementation and enavling usinf ufw with rules#######
# Function to check if UFW is enabled
isUfwEnabled() {
    ufw status | grep -q 'Status: active'
}

# Function to configure UFW rules
configureUfw() {
# Reset UFW to default settings
    sudo ufw --force reset

# Seting default policies
    sudo ufw default deny incoming
    sudo ufw default allow outgoing

# Allowing SSH on the management network (since eth0 is the management interface)
    sudo ufw allow in on eth0 to any port 22 proto tcp

# Allowing HTTP on both interfaces
    sudo ufw allow in on eth0 to any port 80 proto tcp
    sudo ufw allow in on eth1 to any port 80 proto tcp

# Allowing web proxy on both interfaces (assuming port 8080 for the web proxy)
    sudo ufw allow in on eth0 to any port 8080 proto tcp
    sudo ufw allow in on eth1 to any port 8080 proto tcp

# Enabling UFW
    sudo ufw --force enable
}


if isUfwEnabled; then
    echo "UFW is already enabled. No changes needed."
    echo "Current UFW status:"
    ufw status verbose
else
    configureUfw
    echo "UFW has been configured and enabled."
    echo "Current UFW status:"
    ufw status verbose
fi

# Define the list of users
users=("dennis" "aubrey" "captain" "snibbles" "brownie" "scooter" "sandy" "perrier" "cindy" "tiger" "yoda")

###### User accounts ######
# Creating a Function to create user accounts
createUser() {
    username="$1"
    homeDirectory="/home/$username"

# Checking if user already exists
    if id "$username" &>/dev/null; then
        echo "User $username already exists."
    else
        useradd -m -d "$homeDirectory" -s /bin/bash "$username"
        echo "User $username created."

# Adding default ssh directory and authorized keys file
        mkdir -p "$homeDirectory/.ssh"
        touch "$homeDirectory/.ssh/authorized_keys"
        chmod 700 "$homeDirectory/.ssh"
        chmod 600 "$homeDirectory/.ssh/authorized_keys"
        echo "SSH directory and authorized keys file created for $username."

# Adding ssh keys for rsa and ed25519 algorithms
        ssh_keys=("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm")
        for key in "${ssh_keys[@]}"; do
            echo "$key" >> "$homeDirectory/.ssh/authorized_keys"
        done
        echo "SSH keys added for $username."
    fi
}

# Initialize index for the while loop
index=0
# Get the length of the users array
usersLength=${#users[@]}

# Loop through the list of users using while loop
while [ "$index" -lt "$usersLength" ]; do
    user="${users[$index]}"
    createUser "$user"
    index=$((index + 1))
done

# Grant sudo access to dennis
usermod -aG sudo dennis
echo "Sudo access granted to dennis."
