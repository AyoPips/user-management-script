#!/bin/bash

LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Ensure /var/secure directory exists
sudo mkdir -p /var/secure
sudo touch $PASSWORD_FILE
sudo chown root:root /var/secure
sudo chmod 700 /var/secure
sudo chown root:root $PASSWORD_FILE
sudo chmod 600 $PASSWORD_FILE

# Log function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | sudo tee -a $LOG_FILE
}

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <name-of-text-file>"
    exit 1
fi

INPUT_FILE=$1

while IFS=';' read -r username groups; do
    username=$(echo $username | xargs)
    groups=$(echo $groups | xargs)

    if [ -z "$username" ]; then
        continue
    fi

    # Create user with personal group
    if id -u "$username" >/dev/null 2>&1; then
        log "User $username already exists."
    else
        sudo useradd -m -s /bin/bash "$username"
        log "User $username created."
    fi

    # Create and assign groups
    IFS=',' read -ra GROUP_ARRAY <<< "$groups"
    for group in "${GROUP_ARRAY[@]}"; do
        group=$(echo $group | xargs)
        if [ -z "$group" ]; then
            continue
        fi
        if ! getent group "$group" >/dev/null 2>&1; then
            sudo groupadd "$group"
            log "Group $group created."
        fi
        sudo usermod -aG "$group" "$username"
        log "User $username added to group $group."
    done

    # Generate and set password
    PASSWORD=$(openssl rand -base64 12)
    echo "$username:$PASSWORD" | sudo chpasswd
    echo "$username,$PASSWORD" | sudo tee -a $PASSWORD_FILE
    log "Password for user $username generated and stored securely."

    # Set home directory permissions
    sudo chmod 700 /home/$username
    sudo chown $username:$username /home/$username
done < "$INPUT_FILE"

log "User creation and setup completed successfully."
