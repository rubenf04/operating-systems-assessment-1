# operating-systems-assessment-1
This repository contains all source code files for the Operating Systems coursework tasks.

---

## Repository Structure

- `task1/` – System Administration Tool (Bash)
- `task2/` – High Performance Computing Job Scheduler (Python)
- `task3/` – Secure Submission and Access Control System (Python and Bash)

---

## Requirements

- Linux or WSL environment with VS code
- Bash shell (for Task 1 and 3)
- Python 3 (for Task 2 and Task 3)

---

## General guidance 

### Running the scripts using VS code with WSL

1. Download and extract the repository (ZIP file).
2. Open **VS Code**.
3. Ensure the **WSL extension** is installed and active.
4. Press `Ctrl + Shift + P` and select:

WSL: Open Folder

5. Open the extracted repository folder.
6. Open a terminal in VS Code.
7. Navigate to the required task folder using `cd`.
8. Once inside the required sub-folder - for example 'task1' you can run the script using the commands below

### Running from a Standard Terminal (linux/macOS)

If not using VS Code with WSL, the scripts can be run directly from a terminal:

1. Navigate to the extracted repository folder:

```bash
cd path/to/operating-systems-assessment-1
```
Navigate to the required task folder:
* cd task1
  
Run the script using the appropriate command below:
   
## How to Run the scripts: 

Each task is located in its respective folder to allow for more organised creation and easier finding of txt files and directories when running the scripts. Make sure to navigate into the desired task directory before running the script.

### Bash Scripts

You can run Bash scripts in two ways:

Option 1:
```bash simple run
'bash task_1.sh'
```
Option 2: - make executable first
```bash run using chmod
chmod +x task_1.sh
```
### Python Scripts

run python scripts using the same process:

```either:
'python3 task_2.py
```
OR
```
chmod +x task_2.py
```
## File creation and Behaviour
* All scripts automatically create any required files (e.g., logs, data files, directories) during execution.
* No manual setup or pre-existing files are required before running the programs.
* Generated files are stored within the same directory as their respective scripts for easy management and access to files .
* Log files are not displayed within the program menus but can be accessed directly from the script folders.

