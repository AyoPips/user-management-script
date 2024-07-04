#!/bin/bash

LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Ensure /var/log directory and log file exists and has appropriate permissions
sudo touch $LOG_FILE
sudo chown root:root $LOG_FILE
sudo chmod 644 $LOG_FILE

# Ensure /var/secure directory exists with appropriate permissions
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

# Check if the script is run with the correct number of arguments
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <name-of-text-file>"
    exit 1
fi

INPUT_FILE=$1

# Read the input file and process each line
while IFS=';' read -r username groups; do
    # Trim whitespace
    username=$(echo $username | xargs)
    groups=$(echo $groups | xargs)

    # Skip empty username lines
    if [ -z "$username" ]; then
        continue
    fi

    # Create user with personal group
    if id -u "$username" >/dev/null 2>&1; then
        log "User $username already exists."
    else
        if sudo useradd -m -s /bin/bash "$username"; then
            log "User $username created."
        else
            log "Failed to create user $username."
            continue
        fi
    fi

    # Create and assign groups
    IFS=',' read -ra GROUP_ARRAY <<< "$groups"
    for group in "${GROUP_ARRAY[@]}"; do
        group=$(echo $group | xargs)
        if [ -z "$group" ]; then
            continue
        fi
        if ! getent group "$group" >/dev/null 2>&1; then
            if sudo groupadd "$group"; then
                log "Group $group created."
            else
                log "Failed to create group $group."
                continue
            fi
        fi
        if sudo usermod -aG "$group" "$username"; then
            log "User $username added to group $group."
        else
            log "Failed to add user $username to group $group."
        fi
    done

    # Generate and set password
    PASSWORD=$(openssl rand -base64 12)
    if echo "$username:$PASSWORD" | sudo chpasswd; then
        echo "$username,$PASSWORD" | sudo tee -a $PASSWORD_FILE
        log "Password for user $username generated and stored securely."
    else
        log "Failed to set password for user $username."
    fi

    # Set home directory permissions
    if sudo chmod 700 /home/$username && sudo chown $username:$username /home/$username; then
        log "Permissions set for home directory of user $username."
    else
        log "Failed to set permissions for home directory of user $username."
    fi
done < "$INPUT_FILE"

log "User creation and setup completed successfully."
