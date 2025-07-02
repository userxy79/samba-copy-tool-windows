# Samba Copy Tool

The **Samba Copy Tool** is a lightweight, user-friendly utility designed to simplify file transfers between Windows systems and Samba (SMB) network shares. 
It provides a graphical interface for uploading and downloading files, with optional logging and robust conflict handling — all powered by PowerShell and Robocopy.

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

- ✅ Upload files to a Samba/SMB share
- ✅ Download files from a Samba/SMB share
- ✅ Show a progress window with transfer speed
- ✅ Handle file conflicts (overwrite, rename, skip)
- ✅ Optionally create a log file in the user’s Documents folder
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
- End users who need to copy files to/from a network share without using the command line
- Anyone looking for a portable, GUI-based alternative to Robocopy

---

## 📁 Files Included

- `smb-copytool.ps1` – the original PowerShell script
- `smb-copytool.exe` – compiled version (created with [PS2EXE](https://github.com/MScholtes/PS2EXE))
- `README.md` – this documentation

---

## 🧪 How to Use and Build This Tool Yourself

### ▶️ Run the Script Directly in Powershell

powershell -ExecutionPolicy Bypass -File .\smb-copytool.ps1

This will launch the graphical interface and allow you to upload or download files via SMB.


### 🛠️ Build Your Own .exe in Powershell (Optional)
If you don't trust precompiled binaries (and you shouldn't blindly trust any), you can build your own .exe from the source script using PS2EXE.

### 🔧 Step-by-step:
Make sure you have PowerShell 5.1 or later

Install the PS2EXE module in Powershell (if not already installed):

Install-Module -Name ps2exe -Scope CurrentUser -Force


Use the following script to compile your own .exe:

##Beginn
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

Write-Host "`n Done! The file '$outputExe' has been created."
##END

You can save this as build-smb-copytool-exe.ps1 and run it anytime you want to rebuild the .exe.

---

## 🔐 Security Notice

This tool is not digitally signed. As an open-source project, it is provided as-is without a commercial certificate. 
Windows Defender or SmartScreen may show a warning when launching the `.exe` for the first time. 
You can verify the integrity of the file using the SHA256 checksum provided in the Releases section.

---

## 📜 License

This project is released under the MIT License. See `LICENSE` for details.
