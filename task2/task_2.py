#!/usr/bin/env python3
from pathlib import Path
import heapq
import time
from datetime import datetime
# making sure all the files are created in the same directory as the script and using pathlib to handle file paths
BASE_DIR = Path(__file__).resolve().parent
JOB_QUEUE_FILE = BASE_DIR / "job_queue.txt"
COMPLETED_JOBS_FILE = BASE_DIR / "completed_jobs.txt"
LOGGING_FILE = BASE_DIR / "scheduler_log.txt"


# function to log all the actions performed by the user in a system log file with added timestamps and results called at every administrative action.
def logging_system(student_id, job_name, scheduling_type, result):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(LOGGING_FILE, "a") as log_file:
        log_file.write(f"{timestamp} - Student ID: {student_id}, Job Name: {job_name}, Scheduling Type: {scheduling_type}, Result: {result}\n")




def main_menu():

    while True:
        print("\nUniversity High Performance Computing Job Scheduler")
        print("--------------------------------")
        print("1) View pending jobs")
        print("2) Submit a job request")
        print("3) Process the job queue")
        print("4) View completed jobs")
        print("5) Exit the program")

        user_input = input("Please select an option (1-5): ")

        if user_input == '1':
            print("\nPending Jobs:\n")
            view_pending_jobs()
        
        elif user_input == '2':
            print("\nSubmit a Job Request:\n")
            submit_job_request()
                
               
        elif user_input == '3':
            process_jobs_using_priority_queue()
        
        elif user_input == '4':
            print("\nCompleted Jobs: \n")
            view_completed_jobs()
        
        elif user_input == '5':
            exit_choice = input("Are you sure you want to exit? Type 'y' or 'yes' to confirm or any other key to cancel: ")
            if exit_choice.upper() == 'Y' or exit_choice.upper() == 'YES':
                print("Exiting the system. Goodbye!")
                break
            else:
                print("\nExit cancelled. Returning to main menu.")
            
        else:
            print("\nInvalid option. Please select a number between 1 and 5.")


# function to submit a job request by taking user input for student ID, job name, estimated execution time, and priority level, with error handling for invalid inputs and the option to submit multiple job requests before returning to the main menu.
def submit_job_request(): 
    while True:
        print("Type 'cancel' at any time to return to the main menu.\n") # cancel if needed

        student_id =input("Please enter your Student ID: ").strip() # strip to remove leading and trailing whitespace and upper to convert to uppercase for consistency.
        student_id = student_id.upper()
        if student_id == "CANCEL":
            break
        if len(student_id) > 15 or len(student_id) == 0: # error handling for invalid student ID input, checking if it's empty or exceeds 15 characters.
            print("Invalid Student ID. Please enter a Student ID that is between 1 and 15 characters.\n")
            continue
        if "," in student_id:
            print("Please do not include commas in your Student ID.\n")
            continue
        
        job_name = input("\nPlease enter the name of your job: ").strip()
        if job_name.upper() == "CANCEL":
            break
        if len(job_name) == 0 or job_name.isdigit(): # error handling for invalid job name input, checking if it's empty or consists solely of digits.
            print("Invalid job name. Please enter a non-empty job name that does not consist solely of digits.\n")
            continue
        if "," in job_name:
            print("Invalid job name. Please do not include commas in your job name.\n")
            continue
        
        try: # error handling for invalid execution time input, checking if it's a positive whole number.
            execution_time = int(input("\nPlease enter the estimated execution time for your job with digits only (in minutes): ").strip())
            if execution_time <= 0:
                print("Execution time must be greater than 0.\n")
                continue
        except ValueError:
            print("Invalid execution time. Please enter a positive whole number.\n")
            continue
        
        try:
            priority = int(input("\nPlease enter the priority level for your job (1-10) - 10 is highest and 1 is lowest: ").strip())
            if priority < 1 or priority > 10:
                print("Priority must be between 1 and 10.\n")
                continue
        except ValueError: # catches the error if the user input for priority is not an integer.
            print("Invalid priority level. Please enter a number between 1 and 10.\n")
            continue
        
        with open(JOB_QUEUE_FILE, "a") as job_file: # appending the new job request to the job queue file in the format of student ID, job name, execution time, and priority level, separated by commas.
            job_file.write(f"{student_id},{job_name},{execution_time},{priority}\n")
        
        logging_system(student_id, job_name, "Priority Scheduling", "Job Queue Submission") # logging the job submission.

        print("\nJob request submitted successfully!")

        request_another = input("Would you like to submit another job request? Please type 'y' or 'yes' to submit another job or type any other key to return to the main menu: ")
        if request_another.upper() == 'Y' or request_another.upper() == 'YES': # if the user wants to submit another job request, the loop continues and they can enter the details for the next job.
            continue
        else:
            print("Returning to main menu.")
            break

# function to process jobs using a priority scheduling using the heapq module.
def process_jobs_using_priority_queue(): 
    try:
        with open(JOB_QUEUE_FILE, "r") as f: # reading the pending jobs from the job queue file and stripping whitespace and filtering out empty lines.
            lines = [ln.strip() for ln in f.readlines() if ln.strip()]
    except FileNotFoundError:
        print("\nNo pending jobs file found submit a job request first.")
        return

    if not lines: # if there are no valid lines in the job queue file, it means there are no pending jobs to process, and the function will print a message and return to the main menu.
        print("\nNo pending jobs to process.")
        return

    queue = [] # using a list to implement the queue with heapq where each job is stored as a tuple.
    seq = 0  # sequence number to maintain the order of jobs with the same priority and execution time, ensuring that they are processed in the order they were submitted.

    for ln in lines: 
        parts = ln.split(",")
        if len(parts) != 4:
            continue
        # gathering and splitting job details from job queue file.
        student_id, job_name, exec_time, priority = parts

        try:
            prio_int = int(priority) # converting priority and execution time to integers for proper sorting in the priority queue, with error handling for invalid inputs.
            exec_time_int = int(exec_time)
        except ValueError:
            continue
        # pushing the job details into the priority queue using heapq, with priority as the first element followed by execution time.
        heapq.heappush(queue, (-prio_int, exec_time_int, seq, student_id, job_name, exec_time_int, prio_int))
        seq += 1 # incrementing the sequence number for each job to maintain the order of jobs with the same priority and execution time.

    if not queue:
        print("No valid pending jobs to process.")
        return

    print("\nProcessing jobs using Priority Scheduling: (if multiple jobs have the same priority, they will be processed by shorter estimated time first))\n")

    while queue:
        _, exec_time_int, _, student_id, job_name, _, prio_int = heapq.heappop(queue) # popping the job with the highest priority (lowest negative value) and shortest execution time from the priority queue for processing.

        print(f"Executing {job_name} job: (Student: {student_id}, Priority: {prio_int}, Estimated Time: {exec_time_int} minutes)...")
        time.sleep(2)  # simulate execution time
        print("Job executed.\n")

        # completed
        with open(COMPLETED_JOBS_FILE, "a") as done:
            done.write(f"{student_id},{job_name},{exec_time_int},{prio_int}, Complete!\n")
        
        logging_system(student_id, job_name, "Priority Scheduling", "Job Process Completed") # log the job processing completion.


    # clear pending queue text file after processing all jobs.
    open(JOB_QUEUE_FILE, "w").close()

    print("All jobs completed.\n")



# function to view pending jobs by reading the job queue file and displaying the details of each pending job, with error handling for missing files and empty queues.
def view_pending_jobs():
    try:
        with open(JOB_QUEUE_FILE, "r") as job_file:
            pending_jobs = job_file.readlines() 

        has_jobs = False
        # # reading the pending jobs from the job queue file and stripping whitespace and filtering out empty lines.
        for job in pending_jobs:
            job = job.strip()
            if job == "":
                continue  

            student_id, job_name, execution_time, priority = job.split(",")
            print(f"Student ID: {student_id}, Job Name: {job_name}, Execution Time: {execution_time} minutes, Priority: {priority}")
            has_jobs = True

        if has_jobs == False:
            print("No pending jobs in the queue.")
    except FileNotFoundError:
        print("No file found. Make sure to submit a job request first to create the job queue file.\n")

# function to view completed jobs by reading the completed jobs file and displaying the details of each completed job, with error handling for missing files and empty completed jobs.
def view_completed_jobs():
    try:
        with open(COMPLETED_JOBS_FILE, "r") as done_file:
            completed_jobs = done_file.readlines()

        has_completed_jobs = False

        for job in completed_jobs:
            job = job.strip()
            if job == "":
                continue  
            # reading the completed jobs from the completed jobs file and stripping whitespace and filtering out empty lines, then splitting the job details for clear display.
            student_id, job_name, execution_time, priority, status = job.split(",") 
            print(f"Student ID: {student_id}, Job Name: {job_name}, Execution Time: {execution_time} minutes, Priority: {priority}, Status: {status}")
            has_completed_jobs = True
        
        if has_completed_jobs == False:
            print("No completed jobs to display.")
    except FileNotFoundError:
        print("No file found. Make sure to process some jobs first to create the completed jobs file.\n")
            

# start the program by calling the main menu function.
main_menu()
