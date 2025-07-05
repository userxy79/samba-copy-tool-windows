Samba Copy Tool for Windows – Fast SMB Upload/Download with GUI
=======

The **Samba Copy Tool** is a lightweight, user-friendly utility designed to simplify file transfers between Windows systems and Samba (SMB) network shares. 
It provides a graphical interface for uploading and downloading files, with optional logging and robust conflict handling — all powered by PowerShell and Robocopy.

![tool_screenshot](https://github.com/user-attachments/assets/30824e59-044d-4a32-8207-c26986513627)

---

## 🚀 Why This Tool Exists

Transferring files to and from Samba shares can be tedious, especially for non-technical users. 
While tools like Robocopy are powerful, they are command-line based and not always intuitive. This tool was created to:

- Provide a simple GUI for file transfers
- Eliminate the need for scripting or command-line usage
- Offer clear progress feedback and error handling
- Allow optional logging for auditing or troubleshooting

It is especially useful in environments where users need to interact with shared folders (e.g. NAS devices, Linux servers, or Windows file servers) without administrative overhead.

---

## 🛠 What It Does

- ✅ Upload files, folders or both to a Samba/SMB share
- ✅ Download files, folders or both from a Samba/SMB share
- ✅ Dry Run mode (simulate transfers without copying)
- ✅ Progress window with ETA and transfer speed
- ✅ Automatic conflict resolution with:
  - Overwrite
  - Rename (with timestamp)
  - Skip
- ✅ "Apply to all" option for batch conflict handling
- ✅ Optionally create a log file in the user’s Documents folder
- ✅ Transfer summary at the end
- ✅ Run as a `.ps1` script or compiled `.exe` (via PS2EXE)

---

## 🚫 What It Does NOT Do

- ❌ It does not mount or map network drives
- ❌ It does not manage Samba permissions or users
- ❌ It does not support scheduled or background transfers
- ❌ It is not digitally signed (yet) — Windows Defender or SmartScreen may show a warning

---

## 📦 Who Is It For?

- IT admins who want to provide a safe, simple transfer tool to users
- End users who need to copy files or folders to/from a network share without using the command line
- Anyone looking for a portable, GUI-based alternative to Robocopy

---

## 📁 Files Included

- `smb-copytool.ps1` – the original PowerShell script
- `smb-copytool.exe` – compiled version (created with [PS2EXE](https://github.com/MScholtes/PS2EXE))
- `README.md` – this documentation

---

## 🧠 Usage Notes

### Dry Run Mode

When enabled in the startup dialog, the tool simulates the transfer process without copying any files or folders.  
This is useful for testing and previewing actions.

### Rename with Timestamp

If you choose "Rename" and check "Apply to all" during a conflict, all remaining conflicting files or folders will be renamed automatically using a timestamp format:

Example: `report.pdf` → `report - 20250705_143012_842.pdf`

This ensures unique names and prevents overwriting.

### Transfer Summary

At the end of each transfer, a summary dialog shows how many files and folders were:

- ✔ Copied
- 📝 Renamed
- ⏭ Skipped

Example:
<pre>
✔ Files copied: 4 
📝 Files renamed: 2 
⏭ Files skipped: 1 
📁 Folders copied: 3 
📂 Folders skipped: 0
</pre>
---

## 🗂️ Log Files

If logging is enabled, the tool creates a log file in the user's **Documents** folder:

C:\Users\<YourUsername>\Documents\SambaCopyTool\Logs\smb-copytool.log

The log includes timestamps, source/destination paths, conflict decisions, and Robocopy output.  
This is useful for troubleshooting or auditing file transfers.

---


## 🧪 How to Use and Build This Tool Yourself

### ▶️ Run the Script Directly in PowerShell

<pre>
powershell -ExecutionPolicy Bypass -File .\smb-copytool.ps1
</pre>

This will launch the graphical interface and allow you to upload or download files via SMB.


### 🛠️ Build Your Own .exe in PowerShell (Optional)
If you don't trust precompiled binaries (and you shouldn't blindly trust any), you can build your own .exe from the source script using PS2EXE.

### 🔧 Step-by-step:
Make sure you have PowerShell 5.1 or later

Install the PS2EXE module in PowerShell (if not already installed):

<pre>
Install-Module -Name ps2exe -Scope CurrentUser -Force
</pre>


Use the following script to compile your own .exe:

<pre>
# === Configuration ===
$scriptPath  = "smb-copytool.ps1"           # Your PowerShell script
$outputExe   = "smb-copytool.exe"           # Output EXE file
$title       = "Samba Copy Tool"
$description = "Fast SMB Upload/Download Tool with GUI"

# === Check if PS2EXE is installed ===
if (-not (Get-Command Invoke-PS2EXE -ErrorAction SilentlyContinue)) {
    Write-Host "PS2EXE module not found. Installing..."
    Install-Module -Name ps2exe -Scope CurrentUser -Force
}

# === Build EXE ===
Write-Host "Creating EXE from $scriptPath ..."
Invoke-PS2EXE `
    -InputFile $scriptPath `
    -OutputFile $outputExe `
    -NoConsole `
    -Title $title `
    -Description $description

Write-Host "`n✅ Done! The file '$outputExe' has been created."
</pre>

You can save this as build-smb-copytool-exe.ps1 and run it anytime you want to rebuild the .exe.

---

## 🔐 Security Notice

This tool is not digitally signed. As an open-source project, it is provided as-is without a commercial certificate. 
Windows Defender or SmartScreen may show a warning when launching the `.exe` for the first time. 
You can verify the integrity of the file using the SHA256 checksum provided in the Releases section.

---

## 📜 License

This project is released under the MIT License. See `LICENSE` for details.


---

🙌 Acknowledgments

This tool was created with helpful support from **Microsoft Copilot**.
