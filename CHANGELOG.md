# Changelog

All notable changes to this project will be documented in this file.  
This project adheres to [Semantic Versioning](https://semver.org/).

---

## [1.0.1] – 2025-07-05

### ✨ New Features
- **Support for transferring files, folders, or both** in a single operation
- **Automatic rename with timestamp** for file and folder conflicts (`yyyyMMdd_HHmmss_fff`)
- **Dry Run mode**: simulate transfers without copying any data (toggle in startup dialog)
- **Transfer summary** displayed at the end (files/folders copied, renamed, skipped)
- **"Apply to all" option** for Rename, Overwrite, and Skip during file and folder conflicts

### 🛠 Improvements
- Progress window now shows **ETA and transfer speed** (MB/s)
- Robocopy is only used when **no renaming is required**
- Conflict handling logic has been **fully reworked and hardened**

### 🐞 Bug Fixes
- Robocopy no longer overwrites files when Rename is selected — now uses `Copy-Item` instead
- "Rename All" now works **without repeated prompts**

### 🔧 Internal
- Introduced global statistics tracking via `$global:stats`
- Logging improved and now includes a full transfer summary

---

## [1.0.0] – 2025-07-01

### 🎉 Initial Release

- First public version of the Samba Copy Tool
- GUI-based upload/download to SMB shares
- File conflict handling: Overwrite, Rename, Skip
- Progress window with basic status
- Optional logging to file
- Built with PowerShell and Robocopy