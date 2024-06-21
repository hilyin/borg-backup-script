#!/bin/bash

# Get the path of the currently running script
SCRIPT_PATH="$(realpath "$0")"

# Define log path
LOG_PATH="/home/user/borg.log"

# Define the repository path
REPO_PATH="/mnt/repo-drive"

# Define the directory to back up
BACKUP_PATH="/mnt/backup-drive"

# Define the base name for the archive
ARCHIVE_NAME="example-$(date +%Y-%m-%d_%H-%M-%S)"

# Desired start time (24-hour format, e.g., "02:00" for 2 AM)
START_TIME="02:00"
# Backup interval in minutes (e.g., 1440 for daily backups)
BACKUP_INTERVAL_MINUTES=1440

# Function to calculate the initial and subsequent run times
calculate_next_run_time() {
  local start_time="$1"
  local interval_minutes="$2"
  local current_epoch=$(date +%s)
  local target_time_today=$(date -d "today $start_time" +%s)
  local target_time_tomorrow=$(date -d "tomorrow $start_time" +%s)

  if [ $current_epoch -ge $target_time_today ]; then
    # If current time is past today's target time, scheduling for tomorrow.
    local delay_seconds=$((target_time_tomorrow - current_epoch))
  else
    # Scheduling for later today.
    local delay_seconds=$((target_time_today - current_epoch))
  fi
  echo $delay_seconds
}

# Converts seconds to HH:MM:SS format
convert_seconds_to_hms() {
    local total_seconds=$1
    local hours=$((total_seconds / 3600))
    local minutes=$(( (total_seconds % 3600) / 60 ))
    local seconds=$((total_seconds % 60))
    printf "%02d:%02d:%02d" $hours $minutes $seconds
}

# The actual backup script
backup_script() {
  # Prompt the user for the passphrase
  read -sp 'Enter BorgBackup passphrase: ' BORG_PASSPHRASE
  export BORG_PASSPHRASE
  echo "Passphrase set and exported. Starting backup process."

  while true; do
    # Calculate the initial delay until the start time
    initial_delay=$(calculate_next_run_time "$START_TIME" "$BACKUP_INTERVAL_MINUTES")
    formatted_delay=$(convert_seconds_to_hms $initial_delay)
    echo "Sleeping for $formatted_delay until the start time."
    sleep $initial_delay

    # Run the backup
    echo "Starting the backup process."
    if ! borg create --progress --compression none --stats $REPO_PATH::$ARCHIVE_NAME $BACKUP_PATH 2>&1 | tee $LOG_PATH; then
        echo "Backup failed at $(date). Check logs for details."
    else
        echo "Backup completed successfully. Archive name: $ARCHIVE_NAME"
    fi

    # Calculate next scheduled backup time correctly
    next_run_epoch=$(($(date +%s) + BACKUP_INTERVAL_MINUTES * 60))
    echo "Next backup scheduled at $(date -d @$next_run_epoch)."


    # Log every hour until the next run to show the script is waiting
    for ((i = 0; i < $BACKUP_INTERVAL_MINUTES / 60; i++)); do
      echo "Backup script waiting. Next run at $(date -d @$next_run_epoch)."
      sleep 3600
    done
  done

  # Clear the passphrase on script exit
  unset BORG_PASSPHRASE
  echo "Backup process exited. Passphrase cleared."
}

# Run the backup script directly
backup_script