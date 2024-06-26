#!/bin/bash

# Path to the log file
LOG_PATH="/home/user/borg.log"
# Path to the Borg repository
REPO_PATH="/mnt/repo-drive"
# Path to the directory to be backed up
BACKUP_PATH="/mnt/backup-drive"
# Archive name with date and time
ARCHIVE_NAME="example-$(date +%Y-%m-%d_%H-%M-%S)"
# Desired start time in 24-hour format
START_TIME="02:00"
# Backup interval in minutes (1440 for daily backups)
BACKUP_INTERVAL_MINUTES=1440
# Interval for logging script status
LOG_INTERVAL_MINUTES=60

#########################
### DO NOT EDIT BELOW ###
#########################

LOG_INTERVAL_SECONDS=$((LOG_INTERVAL_MINUTES * 60))

# Function to calculate the initial and subsequent run times
calculate_next_run_time() {
  local start_time="$1"
  local current_epoch=$(date +%s)
  local target_time_today=$(date -d "today $start_time" +%s)
  local target_time_tomorrow=$(date -d "tomorrow $start_time" +%s)

  if [ $current_epoch -ge $target_time_today ]; then
    # If current time is past today's target time, scheduling for tomorrow.
    echo $target_time_tomorrow
  else
    # Scheduling for later today.
    echo $target_time_today
  fi
}

# Converts seconds to HH:MM:SS format
convert_seconds_to_hms() {
    local total_seconds=$1
    local hours=$((total_seconds / 3600))
    local minutes=$(( (total_seconds % 3600) / 60 ))
    local seconds=$((total_seconds % 60))
    printf "%02d:%02d:%02d" $hours $minutes $seconds
}

# Converts epoch to 12-hour format with AM/PM
convert_epoch_to_12hr() {
    date -d "@$1" +"%I:%M %p"
}

# The actual backup script
backup_script() {
    # Prompt the user for the passphrase
    read -sp 'Enter BorgBackup passphrase: ' BORG_PASSPHRASE
    export BORG_PASSPHRASE
    echo -e "\nPassphrase set and exported."
    echo -e "\e[32mStarting backup process.\e[0m"

    while true; do
        # Calculate the initial delay until the start time
        next_run_epoch=$(calculate_next_run_time "$START_TIME")
        current_epoch=$(date +%s)
        initial_delay=$((next_run_epoch - current_epoch))
        formatted_delay=$(convert_seconds_to_hms $initial_delay)
        start_time_12hr=$(convert_epoch_to_12hr $next_run_epoch)
        echo "Sleeping for $formatted_delay until the start time at $start_time_12hr."
        sleep $initial_delay

        # Run the backup
        echo "Starting the backup process."
        if ! borg create --progress --compression none --stats $REPO_PATH::$ARCHIVE_NAME $BACKUP_PATH 2>&1 | tee $LOG_PATH; then
            echo "Backup failed at $(date). Check logs for details."
        else
            echo "Backup completed successfully. Archive name: $ARCHIVE_NAME"
        fi

        # Calculate the next start time
        next_run_epoch=$(calculate_next_run_time "$START_TIME")
        current_epoch=$(date +%s)
        next_delay=$((next_run_epoch - current_epoch))

        # Log hourly until the next run to show the script is waiting
        while [ $next_delay -gt $LOG_INTERVAL_SECONDS ]; do
            next_run_time_12hr=$(convert_epoch_to_12hr $next_run_epoch)
            echo "Backup script waiting. Next run at $next_run_time_12hr."
            sleep $LOG_INTERVAL_SECONDS
            current_epoch=$(date +%s)
            next_delay=$((next_run_epoch - current_epoch))
        done

        # Sleep the remaining time until the next run
        sleep $next_delay
    done

    # Clear the passphrase on script exit
    unset BORG_PASSPHRASE
    echo "Backup process exited. Passphrase cleared."
}

# Run the backup script directly
backup_script
