#!/usr/bin/env python3
# modules used 
from pathlib import Path
import time
from datetime import datetime


# making sure all files are stored next to the script 
BASE_DIR = Path(__file__).resolve().parent
SUBMISSION_AND_LOGIN_LOG_FILE = BASE_DIR / "submission_and_login_log_python.txt"
ACCEPTED_SUBMISSIONS_FILE = BASE_DIR / "accepted_submissions_python.txt"
LOCKED_ACCOUNTS_FILE = BASE_DIR / "locked_accounts_python.txt" # needed to know which users are locked out
STORED_SUBMISSIONS_DIR = BASE_DIR / "stored_submissions_python" # needed for adequate content detection using binary comparison 


# constants needed for the program
ALLOWED_FILE_TYPES = {'.pdf', '.docx'} # only allow pdf and docx files to be submitted
MAX_BYTES_ALLOWED = 5 * 1024 * 1024  # 5 MB in bytes


def main_menu():
    while True:

        print("\nSecure Examination Submission and Access Control System")
        print("-------------------------------------------------")
        print("1) Submit an assignment")
        print("2) Check if a file has already been submitted")
        print("3) List all submitted assignments")
        print("4) Simulate login attempt")
        print("5) Exit the system")

        user_input = input("Please select an option (1-5): ")

        if user_input == '1':
            print("\nSubmit an Assignment:\n")
            submit_assignment()

        elif user_input == '2':
            print("\nCheck If a file has already been submitted:\n")
            check_if_already_submitted()

        elif user_input == '3':
            print("\nList of submitted assessments")
            list_submitted_assignments()

        elif user_input == '4':
            simulate_login_attempt()
        # exit with confirmation inserted
        elif user_input == '5':
            choice = input("Are you sure you want to exit? Type 'y' or 'yes' to confirm or type any other key to cancel: ")
            if choice.upper() == 'Y' or choice.upper() == 'YES':
                print("\nExiting the system. Goodbye!")
                break
            else:
                print("\nExit cancelled. Returning to main menu.")
                
        else:
            print("\nInvalid option. Please select an option from 1 to 5 only.")


# logging function allowing information to be appended in a pre formatted way to the log file. this is called at every major action/event
def logging_system(event_type, student_id, file_name, status, reason):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_entry = f"{timestamp} - Event Type: {event_type}, Student ID: {student_id}, File name: {file_name}, Status: {status}, Reason: {reason}\n"
    with open(SUBMISSION_AND_LOGIN_LOG_FILE, "a") as log_file:
        log_file.write(log_entry)
# validates the file before submission making sure size and path is adequate and extension is adequate
def validate_file(file_path):
    try:
        if not file_path.is_file():
            return False, "File does not exist." # check if incorrect file path
        file_ext = file_path.suffix.lower() # variable for file extension
        if file_ext not in ALLOWED_FILE_TYPES: # checking file extension to make sure its either docx or pdf by looking in global variable at the top
            return False, "Invalid file type. Only PDF and DOCX files are allowed." # fail condition
        
        file_size = file_path.stat().st_size # maybe change to different method to get file size if this doesn't work
        if file_size > MAX_BYTES_ALLOWED:
            return False, "File size exceeds the 5 MB limit.\n"
        return True, "File is valid."
    except FileNotFoundError:
        return False, "File does not exist." # check for if file does not exist

# binary comparison function taking two files for comparison as arguments
def binary_file_comparison(file1, file2):
    try:
        with open(file1, "rb") as f1, open(file2, "rb") as f2:
            return f1.read() == f2.read() # returns true if file content is identical using read command to check both files and false otherwise or if given files are inadequate or not found
    except FileNotFoundError:
        return False

# check wether a new submission is a duplicate based on filename, content or both and decides the outcome. decides to use binary comparison by first comparing size in bytes of files.
def check_for_duplicates_content_and_filename(filename, new_file_path):
    try:
        new_size = new_file_path.stat().st_size # get size of newly submitted file using stat.st_size command
        new_name_only = Path(filename).stem.lower() # extracts only the name without the extension for easy filename comparsion vetween docx and pdf types 

        with open(ACCEPTED_SUBMISSIONS_FILE, "r") as accepted_files: # read all non-empty lines from accepted submissions file
            submissions = [line.strip() for line in accepted_files if line.strip()]

        for submission in submissions: # check each previous submission
            submission_parts = [part.strip() for part in submission.split(",", 3)]
            # skip irrelevant lines
            if len(submission_parts) < 4:
                continue

            existing_filename = submission_parts[2] # identify filename and stored path in parts
            stored_path = Path(submission_parts[3])

            existing_name_only = Path(existing_filename).stem.lower() # compare base filename without extension between files
            same_filename = existing_name_only == new_name_only
            same_content = False # track if content is identical

            try: # only attempt binary comparison if file sizes first match , if sizes differ, files cannot be identical in content 
                if stored_path.stat().st_size == new_size:
                    if binary_file_comparison(new_file_path, stored_path):
                        same_content = True # if both same then same content is true
            except FileNotFoundError:
                continue # check for if file is not found

            if same_filename and same_content: # return adequate output to user depending on content and filename of file given
                return True, "Completely identical file detected (same filename and content)."
            elif same_filename:
                return True, "Duplicate filename (same base name) detected."
            elif same_content:
                return True, "Duplicate file content detected."

        return False, "No duplicate."

    except FileNotFoundError:
        return False, "No previous submissions."



def submit_assignment():
    while True:
        print("\ntype 'cancel' at any time to return to the main menu.\n") # asks for userID and checks if adequate and not blocked (if blocked from login sim then cannot submit a file)
        student_ID = input("Enter your student ID (account must not be locked): ")
        if student_ID.upper() == 'CANCEL':
            break
        if len(student_ID) > 15 or len(student_ID) == 0 or student_ID.isdigit():
            print("Invalid student ID. Must be between 1 and 15 characters and not all digits.")
            continue
        if is_user_locked(student_ID):
            print("This student ID account is locked due to too many failed login attempts. Cannot submit assignment.\n")
            logging_system("Submission Attempt", student_ID, "N/A", "Rejected", "Attempted submission with locked student ID account.")
            continue
        # file path input and check if file path is incorrect
        file = input("Enter the full file path of your assignment or place assignment file in the same folder as this script and simply type the filename with its correct extension (must be either PDF or DOCX, max 5MB and no duplicates): ").strip()
        if file.upper() == 'CANCEL':
            break
        if not file:
            print("You must type a adequate file path.")
            continue
        # converts the input path into a path object
        file_path = Path(file).expanduser()
        filename = file_path.name # obtain filename part

        valid, reason = validate_file(file_path) # validate file existance, extension and size using validate_file function
        if not valid:
            print(reason) # prints rejection reason
            logging_system("Submission", student_ID, filename, "Rejected", reason) # log negative outcome if not valid 
            continue # rejected outcome
        # check for duplicate content and filename by calling function
        duplicate, dup_reason = check_for_duplicates_content_and_filename(filename, file_path)

        if duplicate: # if duplicate give reason for rejection and log outcome to system
            print(f"Rejected: {dup_reason}")
            logging_system("Submission", student_ID, filename, "Rejected", dup_reason)
            continue

        # ensure the storage directory exists 
        STORED_SUBMISSIONS_DIR.mkdir(exist_ok=True)
        stored_file = STORED_SUBMISSIONS_DIR / f"{student_ID}_{int(time.time())}_{filename}" # store the file  with timestamp

        # Copy the file by reading bytes from original and writing bytes to new path
        stored_file.write_bytes(file_path.read_bytes())

        # Save accepted submission data 
        with open(ACCEPTED_SUBMISSIONS_FILE, "a") as f:
            f.write(f"{datetime.now()}, {student_ID}, {filename}, {stored_file}\n")

        print("Submission successful.") # give positive output
        logging_system("Submission", student_ID, filename, "Accepted", "OK") # log positive output 

        again = input("Submit another? (y/yes): ").strip().upper() # ask user if they want to input another assignment 
        if again not in ["Y", "YES"]:
            return

# checks wether a studentID username is currently locked by returning output of file which is appended when a username is locked out
def is_user_locked(student_id):
    try:
        with open(LOCKED_ACCOUNTS_FILE, "r") as locked_accounts_file:
            locked_accounts = locked_accounts_file.read().splitlines()
            return student_id in locked_accounts
    except FileNotFoundError: # returns false if no locked users or no file exists
        return False


def simulate_login_attempt():

    times_failed = 0 # keep track of how many times a student ID has failed to login  # to keep track of locked student IDs 
    first_fail_time = None # time of first failed attempt count three failed attempts within 60 seconds


    print("\nSimulating login attempt. Type 'cancel' at any time to return to the main menu.\n")
    
    while True: # userID validation (if blocked account : cannot login)
        student_ID = input("Enter your student ID for Login attempt: ")
        if student_ID.upper() == 'CANCEL':
            print("Exiting login simulation. Returning to main menu.")
            return
        if len(student_ID) > 15 or len(student_ID) == 0 or student_ID.isdigit():
            print("Invalid student ID. Must be between 1 and 15 characters and not all digits.")
            continue
        if is_user_locked(student_ID):
            print("This student ID account is locked due to too many failed login attempts. Suspicious re-attempt of login logged as suspicious in internal logs.\n")
            logging_system("Suspicious Login Attempt", student_ID, "N/A", "Rejected", "Repeated login attempt after account lockout")
            continue

        while True:
            login_simulation = input("Type 'correct' to simulate a successful login or any other input to simulate a failed login (lower or upper case): ") # correct as the correct password else incorrect password
            if login_simulation.upper() == 'CANCEL':
                print("Exiting login simulation. Returning to main menu.") # can cancel anytime
                return
            if login_simulation.upper() == 'CORRECT':
                print(f"\nSuccessful login, Welcome {student_ID}.")
                logging_system("Login Attempt", student_ID, "N/A", "Success", "Simulated login successful.") # log success
                return
            if not login_simulation:
                print("Input cannot be empty. Please try again.")
                continue
            
            current = time.time() # gets current time and sets first fail attempt to current time
            if first_fail_time is None:
                first_fail_time = current

            times_failed += 1 # adds 1 to every time incorrect password is given
            print("Incorrect login, please try again.")
            logging_system("Login Attempt", student_ID, "N/A", "Failed", "Simulated login failed.") # log unsuccessfull attempts
            
            if times_failed == 3: # if three fail = lock userID
                suspicious = (current - first_fail_time) <= 60 # suspicious if three failed attempts within 60 seconds of first fail time
                print("\nToo many failed login attempts. Returning to main menu and locking studentID account.")
                print("To unlock the account, go to the locked_accounts.txt file and remove the student ID from the file.")

                lock_reason = "Failed login more than 3 times" # give reason
                if suspicious:
                    lock_reason += " SUSPICIOUS ACTIVITY: 3 failed attempts within 60 seconds." 
                    print("\nYour account has been flagged for suspicious activity in internal logs due to 3 failed login attempts within 60 seconds.")
                logging_system("Account Lockout", student_ID, "N/A", "Account permanently locked until further notice", f"Too many failed login attempts. {lock_reason}") # log lockout and suspicion
                with open(LOCKED_ACCOUNTS_FILE, "a") as locked_accounts_file:
                    locked_accounts_file.write(f"{student_ID}\n")
                return
                
           
# checks wether a given filename is already within the accepted submissions file and if so tells user that assignment has already been submitted
def check_if_already_submitted():
    while True:
        print("Type 'cancel' at any time to return to the main menu.\n")
        filename = input("Enter the full file name to check if there has been another submission (e.g. report.docx): ")
        if filename.upper() == 'CANCEL':
            print("Exiting and returning to main menu.")
            break
        if not filename:
            print("File name cannot be empty. Please try again.")
            continue
        try: # read all non empty lines 
            with open(ACCEPTED_SUBMISSIONS_FILE, "r") as accepted_files:
                submissions = accepted_files.readlines()
                submissions = [submission.strip() for submission in submissions if submission.strip()]

            
            found = False
            for submission in submissions: # loops trough every prior submission
                submission_parts = [part.strip() for part in submission.split(",")] # split line into parts for clear display
                
                
                submitted_filename = submission_parts[2] # original filename is stored at index 2
                if submitted_filename.lower() == filename.lower(): # checks if given filename is same as a filename in any of the previous submissions
                    print(f"\nA file named '{filename}' has already been submitted by student ID: {submission_parts[1]} on {submission_parts[0]}.")
                    found = True
                    return
                
            
            if not found:
                print(f"\nNo file named '{filename}' has been submitted yet.") # check if no file submitted yet
                return

        except FileNotFoundError: # check for error or no file found
            print("\nNo submissions have been made yet. Assignments need to first be submitted before checking for duplicates.")
            break
            


# displays all submissions from the accepted submissions file ina  clear formatted list
def list_submitted_assignments():
    try:
        with open(ACCEPTED_SUBMISSIONS_FILE, "r") as accepted_files:
            submissions = accepted_files.readlines()
            submissions = [submission.strip() for submission in submissions if submission.strip()]
            if not submissions:
                print("\nNo assignments have been successfully submitted yet.")
                return

            for submission in submissions:
                sub_parts = [p.strip() for p in submission.split(",", 3)]
                if len(sub_parts) >= 4:
                    print(f"{sub_parts[0]} | {sub_parts[1]} | {sub_parts[2]}")
    except FileNotFoundError:
        print("\nNo assignments have been submitted yet, submit an assignment first.") # check for error if file does not exist



main_menu() # starts the program

