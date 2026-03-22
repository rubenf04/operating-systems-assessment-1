#!/usr/bin/env bash
BASE_DIR="$(dirname "$(readlink -f "$0")")"
SUBMISSION_AND_LOGIN_LOG_FILE="$BASE_DIR/submission_and_login_log_bash.txt"
ACCEPTED_SUBMISSIONS_FILE="$BASE_DIR/accepted_submissions_bash.txt"
LOCKED_ACCOUNTS_FILE="$BASE_DIR/locked_accounts_bash.txt"
STORED_SUBMISSIONS_DIR="$BASE_DIR/stored_submissions_bash"

# constants needed for the file max byte size
MAX_BYTES_ALLOWED=$((5 * 1024 * 1024))   # 5 MB in bytes



main_menu() {
    while true; do
        echo
        echo "Secure Examination Submission and Access Control System"
        echo "-------------------------------------------------"
        echo "1) Submit an assignment"
        echo "2) Check if a file has already been submitted"
        echo "3) List all submitted assignments"
        echo "4) Simulate login attempt"
        echo "5) Exit the system"

        read -r -p "Please select an option (1-5): " user_input

        if [[ "$user_input" == "1" ]]; then
            echo
            echo "Submit an Assignment:"
            echo
            submit_assignment

        elif [[ "$user_input" == "2" ]]; then
            echo
            echo "Check If a file has already been submitted:"
            echo
            check_if_already_submitted

        elif [[ "$user_input" == "3" ]]; then
            echo
            echo "List of all submitted assignments:"
            echo
            list_submitted_assignments

        elif [[ "$user_input" == "4" ]]; then
            simulate_login_attempt

        elif [[ "$user_input" == "5" ]]; then
            read -r -p "Are you sure you want to exit? Type 'y' or 'yes' to confirm or type any other key to cancel: " choice
            choice="${choice^^}"

            if [[ "$choice" == "Y" || "$choice" == "YES" ]]; then
                echo
                echo "Exiting the system. Goodbye!"
                break
            else
                echo
                echo "Exit cancelled. Returning to main menu."
            fi
        else
            echo
            echo "Invalid option. Please select an option from 1 to 5 only."
        fi
    done
}


# logging system called at every major function with pre-set details and timestamp using date command
logging_system() {
    local event_type="$1"
    local student_id="$2"
    local file_name="$3"
    local status="$4"
    local reason="$5"

    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    echo "$timestamp - Event Type: $event_type, Student ID: $student_id, File name: $file_name, Status: $status, Reason: $reason" >> "$SUBMISSION_AND_LOGIN_LOG_FILE" # outputted format
}

# function to check file existance, its type and size and make sure its adequate for submission
validate_file() {
    local file_path="$1"
    # check file exists
    if [[ ! -f "$file_path" ]]; then
        VALIDATE_RESULT=1
        VALIDATE_REASON="File does not exist."
        return
    fi
    # convert file extension to lowercase
    local file_ext=".${file_path##*.}"
    file_ext="${file_ext,,}"
    # allow only pdf and docx extensions
    if [[ "$file_ext" != ".pdf" && "$file_ext" != ".docx" ]]; then
        VALIDATE_RESULT=1
        VALIDATE_REASON="Invalid file type. Only PDF and DOCX files are allowed."
        return
    fi
    # get the file size in bytes
    local file_size
    file_size=$(stat -c%s "$file_path" 2>/dev/null)

    if [[ -z "$file_size" ]]; then
        VALIDATE_RESULT=1
        VALIDATE_REASON="File does not exist."
        return
    fi
    #check file size against size limit of 5MB
    if (( file_size > MAX_BYTES_ALLOWED )); then
        VALIDATE_RESULT=1
        VALIDATE_REASON="File size exceeds the 5 MB limit."
        return
    fi
    # if all checks pass
    VALIDATE_RESULT=0
    VALIDATE_REASON="File is valid."
}

# compares two files byte-for-byte (binary comparison) using cmp
binary_file_comparison() {
    local file1="$1"
    local file2="$2"
    # check both files exist
    if [[ ! -f "$file1" || ! -f "$file2" ]]; then
        return 1
    fi
    # cmp command returns 0 if both files have identical content
    cmp -s "$file1" "$file2"
    return $?
}

# function that checks for either duplicate filename or content or both - for content size of each file is compared first, if size is the same, binary comparison is done
check_for_duplicates_content_and_filename() {
    local filename="$1"
    local new_file_path="$2"
    # in case of no previous submissions
    if [[ ! -f "$ACCEPTED_SUBMISSIONS_FILE" ]]; then
        DUPLICATE_RESULT=1
        DUPLICATE_REASON="No previous submissions."
        return
    fi
    # get size of new file
    local new_size
    new_size=$(stat -c%s "$new_file_path" 2>/dev/null)
    
    if [[ -z "$new_size" ]]; then
        DUPLICATE_RESULT=1
        DUPLICATE_REASON="No previous submissions."
        return
    fi
    # extract the filename without extension (pure filename)
    local new_name_only
    new_name_only="${filename%.*}"
    new_name_only="${new_name_only,,}"
    # loop trough the stored submissions in storage file
    while IFS= read -r submission; do
        [[ -z "$submission" ]] && continue
        # split the CSV lines
        IFS=',' read -r part1 part2 part3 part4 <<< "$submission"

        local existing_filename
        local stored_path

        existing_filename="$(echo "$part3" | sed 's/^ *//; s/ *$//')"
        stored_path="$(echo "$part4" | sed 's/^ *//; s/ *$//')"

        [[ -z "$existing_filename" || -z "$stored_path" ]] && continue

        local existing_name_only
        existing_name_only="${existing_filename%.*}"
        existing_name_only="${existing_name_only,,}"

        local same_filename=false
        local same_content=false
        # check the filename matches
        if [[ "$existing_name_only" == "$new_name_only" ]]; then
            same_filename=true
        fi
        # check content only if size in matches
        if [[ -f "$stored_path" ]]; then
            local stored_size
            stored_size=$(stat -c%s "$stored_path" 2>/dev/null)

            if [[ -n "$stored_size" && "$stored_size" -eq "$new_size" ]]; then
                if binary_file_comparison "$new_file_path" "$stored_path"; then
                    same_content=true # if both size and binary output same content then true
                fi
            fi
        else
            continue
        fi
        # result decider 
        if [[ "$same_filename" == true && "$same_content" == true ]]; then
            DUPLICATE_RESULT=0
            DUPLICATE_REASON="Completely identical file detected (same filename and content)."
            return
        elif [[ "$same_filename" == true ]]; then
            DUPLICATE_RESULT=0
            DUPLICATE_REASON="Duplicate filename (same base name) detected."
            return
        elif [[ "$same_content" == true ]]; then
            DUPLICATE_RESULT=0
            DUPLICATE_REASON="Duplicate file content detected."
            return
        fi

    done < "$ACCEPTED_SUBMISSIONS_FILE"

    DUPLICATE_RESULT=1
    DUPLICATE_REASON="No duplicate."
}

# function for inputs and decider when submitting asignments
submit_assignment() {
    while true; do
        echo
        echo "Type 'cancel' at any time to return to the main menu."
        echo

        read -r -p "Enter your student ID (account must not be locked): " student_ID
        #cancel option
        if [[ "${student_ID^^}" == "CANCEL" ]]; then
            break
        fi
        # validation of adequate userr ID
        if [[ ${#student_ID} -gt 15 || ${#student_ID} -eq 0 || "$student_ID" =~ ^[0-9]+$ ]]; then
            echo "Invalid student ID. Must be between 1 and 15 characters and not all digits."
            continue
        fi
        # check if given account is locked if so dont allow submission
        if is_user_locked "$student_ID"; then
            echo "This student ID account is locked due to too many failed login attempts. Cannot submit assignment."
            echo
            logging_system "Submission Attempt" "$student_ID" "N/A" "Rejected" "Attempted submission with locked student ID account."
            continue
        fi
        # get the file path trough input
        read -r -p "Enter the full file path of your assignment or place assignment file in the same folder as this script and simply type the filename with its correct extension (must be either PDF or DOCX, max 5MB and no duplicates): " file

        file="$(echo "$file" | sed 's/^ *//; s/ *$//')"

        if [[ "${file^^}" == "CANCEL" ]]; then
            break
        fi
        # if inadequate path given
        if [[ -z "$file" ]]; then
            echo "You must type an adequate file path."
            continue
        fi
        # read file 
        if [[ "$file" == ~* ]]; then
            eval "file_path=\"$file\""
        else
            file_path="$file"
        fi

        filename="$(basename "$file_path")"
        # calls function to ensure file is adequate
        validate_file "$file_path"
        if [[ "$VALIDATE_RESULT" -ne 0 ]]; then
            echo "$VALIDATE_REASON"
            logging_system "Submission" "$student_ID" "$filename" "Rejected" "$VALIDATE_REASON"
            continue
        fi
        # calls function to ensure duplicates name and content is checked
        check_for_duplicates_content_and_filename "$filename" "$file_path"
        if [[ "$DUPLICATE_RESULT" -eq 0 ]]; then
            echo "Rejected: $DUPLICATE_REASON" # reject if output is true and duplicate is found
            logging_system "Submission" "$student_ID" "$filename" "Rejected" "$DUPLICATE_REASON" # logging to system if rejected
            continue
        fi
        # stores a file copy in directory
        mkdir -p "$STORED_SUBMISSIONS_DIR"
        stored_file="$STORED_SUBMISSIONS_DIR/${student_ID}_$(date +%s)_${filename}"

        cp "$file_path" "$stored_file" # copy file path
        
        echo "$(date '+%Y-%m-%d %H:%M:%S'), $student_ID, $filename, $stored_file" >> "$ACCEPTED_SUBMISSIONS_FILE" #positive output

        echo "Submission successful."
        logging_system "Submission" "$student_ID" "$filename" "Accepted" "OK" # logging to system if accepted

        read -r -p "Submit another? (y/yes): " again # allow user to input another if they wish
        again="${again^^}"
        if [[ "$again" != "Y" && "$again" != "YES" ]]; then
            return
        fi
    done
}
# fetches and returns locked users from a file holding all locked accounts
is_user_locked() {
    local student_id="$1"

    if [[ ! -f "$LOCKED_ACCOUNTS_FILE" ]]; then
        return 1
    fi

    grep -Fxq "$student_id" "$LOCKED_ACCOUNTS_FILE"
    return $?
}

# simulation of a login, if user fails to type 'success' three times in a row they get blocked and locked out. If three fails within 60 seconds and then retry to enter password when locked, they are deeemed suspicious
simulate_login_attempt() {
    local times_failed=0 # counter to keep track of fails
    local first_fail_time="" # variable needed to 60 seconds from starting time

    echo
    echo "Simulating login attempt. Type 'cancel' at any time to return to the main menu."
    echo

    while true; do
        read -r -p "Enter your student ID for Login attempt: " student_ID # input for username

        if [[ "${student_ID^^}" == "CANCEL" ]]; then # can cancel
            echo "Exiting login simulation. Returning to main menu."
            return
        fi

        if [[ ${#student_ID} -gt 15 || ${#student_ID} -eq 0 || "$student_ID" =~ ^[0-9]+$ ]]; then # validation of adequate username 
            echo "Invalid student ID. Must be between 1 and 15 characters and not all digits."
            continue
        fi

        if is_user_locked "$student_ID"; then # checks for all locked accounts in the file and if username given is locked, blocks attempt and logs as suspicious
            echo "This student ID account is locked due to too many failed login attempts. Suspicious re-attempt of login logged as suspicious in internal logs."
            echo
            logging_system "Suspicious Login Attempt" "$student_ID" "N/A" "Rejected" "Repeated login attempt after account lockout"
            continue
        fi

        while true; do
            read -r -p "Type 'correct' to simulate a successful login or any other input to simulate a failed login (lower or upper case): " login_simulation # correct is correct password

            if [[ "${login_simulation^^}" == "CANCEL" ]]; then
                echo "Exiting login simulation. Returning to main menu."
                return
            fi

            if [[ "${login_simulation^^}" == "CORRECT" ]]; then
                echo
                echo "Successful login, Welcome $student_ID."
                logging_system "Login Attempt" "$student_ID" "N/A" "Success" "Simulated login successful." # logging successful attempt
                return # goes back to main menu
            fi

            if [[ -z "$login_simulation" ]]; then # does not allow empty inputs
                echo "Input cannot be empty. Please try again."
                continue 
            fi

            current=$(date +%s) # gets current time and marks first fail time as current time of fail
            if [[ -z "$first_fail_time" ]]; then
                first_fail_time="$current"
            fi

            times_failed=$((times_failed + 1)) # if not success then add one failed instance until three are reached
            echo "Incorrect login, please try again."
            logging_system "Login Attempt" "$student_ID" "N/A" "Failed" "Simulated login failed." # log unsuccessful attempts

            if [[ "$times_failed" -eq 3 ]]; then # if failed three times then lock user out (if all three within 60 seconds then mark as suspicious)
                suspicious=false
                if (( current - first_fail_time <= 60 )); then
                    suspicious=true
                fi

                echo
                echo "Too many failed login attempts. Returning to main menu and locking studentID account."
                echo "To unlock the account, go to the locked_accounts.txt file and remove the student ID from the file."

                lock_reason="Failed login more than 3 times" # give reason in logging
                if [[ "$suspicious" == true ]]; then
                    lock_reason+=" SUSPICIOUS ACTIVITY: 3 failed attempts within 60 seconds."
                    echo
                    echo "Your account has been flagged for suspicious activity in internal logs due to 3 failed login attempts within 60 seconds."
                fi

                logging_system "Account Lockout" "$student_ID" "N/A" "Account permanently locked until further notice" "Too many failed login attempts. $lock_reason"
                echo "$student_ID" >> "$LOCKED_ACCOUNTS_FILE" # added username to locked accounts file so cannot log back in unless deleted from that file
                return
            fi
        done
    done
}

# function that checks for file name and current submitted assignments to check wether that file has already been submitted
check_if_already_submitted() {
    while true; do
        echo "Type 'cancel' at any time to return to the main menu."
        echo

        read -r -p "Enter the full file name to check if there has been another submission (e.g. report.docx): " filename

        if [[ "${filename^^}" == "CANCEL" ]]; then
            echo "Exiting and returning to main menu."
            break
        fi

        if [[ -z "$filename" ]]; then
            echo "File name cannot be empty. Please try again."
            continue # check for invalid empty input
        fi

        if [[ ! -f "$ACCEPTED_SUBMISSIONS_FILE" ]]; then
            echo
            echo "No submissions have been made yet. Assignments need to first be submitted before checking for duplicates."
            break # check for if file exists but no submissions done yet
        fi

        found=false
        # read lines in submitted assignments file line by line avoiding white spaces and store in submission variable for checking
        while IFS= read -r submission; do
            [[ -z "$submission" ]] && continue

            IFS=',' read -r part1 part2 part3 part4 <<< "$submission"

            submitted_timestamp="$(echo "$part1" | sed 's/^ *//; s/ *$//')"
            submitted_student_id="$(echo "$part2" | sed 's/^ *//; s/ *$//')"
            submitted_filename="$(echo "$part3" | sed 's/^ *//; s/ *$//')"

            if [[ "${submitted_filename,,}" == "${filename,,}" ]]; then # if same name then tell user
                echo
                echo "A file named '$filename' has already been submitted by student ID: $submitted_student_id on $submitted_timestamp."
                found=true
                return
            fi
        done < "$ACCEPTED_SUBMISSIONS_FILE"

        if [[ "$found" == false ]]; then
            echo
            echo "No file named '$filename' has been submitted yet." # if no submission name found tell user
            return
        fi
    done
}


list_submitted_assignments() {
    if [[ ! -f "$ACCEPTED_SUBMISSIONS_FILE" ]]; then # check for file existance
        echo
        echo "No assignments have been submitted yet, submit an assignment first."
        return
    fi

    local found=false

    echo
    echo
    # read trough all submissions accepted file and seperate info into parts for neat display
    while IFS= read -r submission; do
        # skip empty lines
        [[ -z "$submission" || "$submission" =~ ^[[:space:]]*$ ]] && continue

        found=true

        IFS=',' read -r part1 part2 part3 part4 <<< "$submission"

        sub_part1="$(echo "$part1" | sed 's/^ *//; s/ *$//')"
        sub_part2="$(echo "$part2" | sed 's/^ *//; s/ *$//')"
        sub_part3="$(echo "$part3" | sed 's/^ *//; s/ *$//')"

        if [[ -n "$sub_part1" && -n "$sub_part2" && -n "$sub_part3" ]]; then
            echo "$sub_part1 | $sub_part2 | $sub_part3"
        fi

    done < "$ACCEPTED_SUBMISSIONS_FILE"

    if [[ "$found" == false ]]; then # check if no submissions in file
        echo "No assignments have been successfully submitted yet."
    fi
}

main_menu # starts the program