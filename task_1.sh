#!/usr/bin/env bash

# makes sure all the necessary files and directories exist in the same directory as the script
BASE_DIR="$(dirname "$(readlink -f "$0")")"
LOG_FILE="$BASE_DIR/system_actions_logging.txt"
ARCHIVE_DIR="$BASE_DIR/Archive_Logs"


main_menu() {

    while true; do
        echo "System Administration tool"
        echo "--------------------------"
        echo "1) Process Monitoring and Management"
        echo "2) Disk Inspection and Log Archiving"
        echo "3) Exit the program"
        echo "--------------------------"
        read -r -p "Select an option 1-3: " user_choice
        echo

        case "$user_choice" in

            1)
                process_monitoring
                ;;

            2)
                disk_inspection_and_log_archiving
                ;;

            3)
                read -r -p "Are you sure you want to exit? Please type 'y' or 'yes' to confirm or any other key to cancel: " confirm_exit # exit confirmation to prevent accidental exits

                if [ "$confirm_exit" = "y" ] || [ "$confirm_exit" = "Y" ] || [ "$confirm_exit" = "yes" ] || [ "$confirm_exit" = "YES" ]; then
                    echo "Exiting the program. Goodbye."
                    return
                else
                    echo "Exit cancelled. Returning to the main menu."
                fi
                ;;

            *)
                echo "Invalid option. Please select a valid option (1, 2, or 3)." 
                ;;
        esac

        echo
    done
}

# function to log all the actions performed by the user in a system log file with added timestamps called at every administrative action.
add_to_log() {
    action="$1"
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $action" >> "$LOG_FILE"
}

# holds all the functionalities related to process monitoring and management under another submenu, including displaying CPU and memory usage, listing top memory-consuming processes, and terminating selected processes
process_monitoring() {
    while true; do

            echo "Process Monitoring and Management"
            echo "--------------------------"
            echo "1) Display current CPU and Memory usage"
            echo "2) List top 10 memory-consuming processes"
            echo "3) Terminate a selected process"
            echo "4) Return to main menu"
            echo "--------------------------"
            read -r -p "Select an option 1-4: " process_choice
            echo

            if [ "$process_choice" == "4" ]; then
                break
                    
            elif [ "$process_choice" == "1" ]; then
                # CPU usage is displayed by subtracting the idle CPU percentage from 100, and memory usage is obtained by checking the used memory in megabytes from the free command output.
                cpu_Usage=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}') 
                mem_Usage=$(free -m | awk '/Mem:/ {print $3}')
                
                echo "Current CPU Usage: $cpu_Usage%"
                echo "Current Memory Usage: $mem_Usage MB"
                add_to_log "Checked CPU and Memory usage"
                echo
                echo

            elif [ "$process_choice" == "2" ]; then
                echo "Top 10 memory-consuming processes:"
                echo "--------------------------------"
                ps -eo pid,user,%cpu,%mem,rss,comm --sort=-%mem | head -11 # using ps -eo command to list all processes sorted by memory usage and displaying the top 10 along with their important info such as PID and name.
                add_to_log "Listed top 10 memory-consuming processes"
                echo
                    
            elif [ "$process_choice" == "3" ]; then
                terminate_process # calling the function to handle process termination with added checks and confirmation
            else
                echo "Invalid option. Please select a valid option (1, 2, 3 or 4)."
                echo
            fi
        done
                
            
}
# function to handle the termination of a selected process by the user, with added checks to prevent termination of critical system processes and confirmation before killing the process
terminate_process() {
    while true; do
        read -r -p "Enter the PID of the process to terminate (or type 'cancel' to return to the menu): " pid_to_kill # identifying process to kill by its PID number
        echo

        if [ "$pid_to_kill" == "cancel" ]; then
            echo "Termination cancelled. Returning to process management menu."
            return
        fi

        if ! echo "$pid_to_kill" | grep -qE '^[0-9]+$'; then # check if the input is a valid numeric PID (digits 0-9 only)
            echo "Invalid PID. Please enter a numeric value."
            echo
            continue
        fi

        if ! ps -p "$pid_to_kill" > /dev/null 2>&1; then
            echo "No process found with PID $pid_to_kill." # check for invalid pid given not of any process
            echo
            continue
        fi
        # if PID is 1 (init/systemd) or the current script's PID or its parent PID, prevent termination and display a warning message to the user
        if [ "$pid_to_kill" -eq 1 ] || [ "$pid_to_kill" -eq "$$" ] || [ "$pid_to_kill" -eq "$PPID" ]; then
            echo "This is a critical system process and cannot be terminated."
            echo
            continue
        fi
        # check the name of the process to prevent termination of critical system processes like init, systemd, bash, or sh (critical processes)
        chosen_process_name=$(ps -p "$pid_to_kill" -o comm=)
        case "$chosen_process_name" in
            ("init"|"systemd"|"bash"|"sh")
                echo "This is a critical system process and cannot be terminated."
                echo
                continue
                ;;
        esac

        # confirming before killing the process
        read -r -p "Are you sure you want to terminate selected process? type 'yes' to confirm or any other key to cancel: " confirm_kill
        echo

            if [ "$confirm_kill" == "yes" ] || [ "$confirm_kill" == "YES" ] || [ "$confirm_kill" == "Yes" ]; then
                kill "$pid_to_kill" 2>/dev/null # killing of pid
                sleep 2

                process_state=$(ps -p "$pid_to_kill" -o stat= 2>/dev/null | awk '{print $1}') # check if process is terminated by checking state

                if [ -z "$process_state" ] || [[ "$process_state" == Z* ]]; then # if process state is empty or zombie, it means the process was successfully terminated
                    echo "Process $pid_to_kill ($chosen_process_name) has been successfully terminated."
                    add_to_log "Terminated process $pid_to_kill ($chosen_process_name)"
                    echo
                else
                    echo "Failed to terminate process $pid_to_kill ($chosen_process_name). It may be a protected system process." # raise error message if somehow process could not be terminated.
                    add_to_log "Failed to terminate process $pid_to_kill ($chosen_process_name)"
                    echo
                fi
                return

            else
                echo "Termination cancelled. Returning to process management menu."
                add_to_log "Cancelled termination of process $pid_to_kill ($chosen_process_name)"
                echo
                return
            fi
        done
}
# function for checking disk usage for a specific given directory path.
disk_usage_check() {
    while true; do
        read -r -p "Enter the directory path to check disk usage (or type 'cancel' to return to the menu): " dir_path
        echo

        if [ "$dir_path" == "cancel" ]; then
            echo "Disk usage check cancelled. Returning to main menu."
            return
        fi

        if [ ! -d "$dir_path" ]; then # check if the input is a valid directory path
            echo "Invalid directory path. Please enter a valid directory."
            echo
            continue
        fi

        echo "Disk usage for $dir_path:"
        # using du command to check the disk usage of the specified directory and its contents, with error handling for permission issues or other errors that may occur during the check
        du -sh "$dir_path" 2>/dev/null || echo "Error occurred while checking disk usage possibly due to permission issues." 
        add_to_log "Checked disk usage for $dir_path"
        echo
        return
    done
}
# function to check for log files larger than 50MB in a specified directory, and if found, archive them by compressing with gzip and moving to an "Archive_Logs" directory, while also checking the total size of archived logs.
check_for_large_logs_and_archiving() {

    mkdir -p "$ARCHIVE_DIR" # create the arhcive directory straight away upon  function call
     

    while true; do
        read -r -p "Enter the directory path to check for large log files (or type 'cancel' to return to the menu): " log_dir
        echo

        if [ "$log_dir" == "cancel" ]; then
            echo "Log file check cancelled. Returning to menu."
            return
        fi

        if [ ! -d "$log_dir" ]; then # checks if given directory path is valid and exists
            echo "Invalid directory. Please enter a valid directory."
            echo
            continue
        fi
        echo

        # Check if no files were found
        if ! find "$log_dir" -type f -name "*.log" -size +50M 2>/dev/null | grep -q .; then # error handling if no files are found larger than 50MB
            echo "No log files larger than 50MB found in $log_dir."
            add_to_log "Checked for large log files in $log_dir - none found" # log addition failed
            echo
            return
        fi

        echo "Log files larger than 50MB found in $log_dir" # informs user
        find "$log_dir" -type f -name "*.log" -size +50M 2>/dev/null # displays the specific log files larger than 50MB if any.
        echo

        find "$log_dir" -type f -name "*.log" -size +50M 2>/dev/null | while IFS= read -r log_file; do # find command to find the log. files within the specified directory larger than 50MB
            

            file_name=$(basename "$log_file") # formatting for archive
            timestamp=$(date +"%Y%m%d%H%M%S")

            gzip -c "$log_file" > "$ARCHIVE_DIR/${file_name}_${timestamp}.gz" # gzip command to archive large logs found to the archivedlogs directory

            echo "Archived $log_file to $ARCHIVE_DIR/${file_name}_${timestamp}.gz"
            add_to_log "Checked for large log files and archived relevant log file $log_file to $ARCHIVE_DIR/${file_name}_${timestamp}.gz" # log addition successful
        done


        # Check ArchiveLogs size for 1GB size overhead
        archive_size=$(du -sm "$ARCHIVE_DIR" 2>/dev/null | awk '{print $1}') # using du command to check for disk space
        if [ "$archive_size" -gt 1024 ]; then # 1024MB = 1GB
            echo "Warning: The total size of archived logs exceeds 1GB."
            add_to_log "Warning: $ARCHIVE_DIR directory exceeded 1GB"
        fi

        echo
        return
    done
}
# function to handle the submenu for disk inspection and log archiving, allowing the user to choose between checking disk usage for a specific directory or checking for large log files and archiving them, with an option to return to the main menu.
disk_inspection_and_log_archiving() {
    while true; do
        echo "Disk Inspection and Log Archiving"
        echo "--------------------------"
        echo "1) Check disk usage for a specific directory"
        echo "2) Check for large log files and archive them"
        echo "3) Return to main menu"
        echo "--------------------------"
        read -r -p "Select an option 1-3: " disk_choice
        echo

        case "$disk_choice" in
            1)
                disk_usage_check # calling the function to handle disk usage check for a specific directory with added error handling and logging
                ;;
            2)
                check_for_large_logs_and_archiving # calling the function to handle checking for large log files and archiving them with added error handling, logging, and size check for archived logs
                ;;
            3)
                break
                ;;
            *)
                echo "Invalid option. Please select a valid option (1, 2, or 3)."
                ;;
        esac

        echo
    done
}

main_menu # start the program by calling the main menu function