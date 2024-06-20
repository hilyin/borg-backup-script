This script manages automated BorgBackup with simple scheduling, ensuring the key is not stored persistently on the system. It requires manual activation.

The script will prompt for a passphrase, calculate the next run time, perform the backup, and log hourly status updates.

To avoid accidentally closing the session, run the script within screen or tmux. Use a user account that has full permissions to the files.