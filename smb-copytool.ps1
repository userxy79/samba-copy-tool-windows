Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Robuste Pfaderkennung
function Get-ScriptBase {
    try {
        if ($MyInvocation.MyCommand.Path) {
            return Split-Path -Parent -Path $MyInvocation.MyCommand.Path
        }

        $assembly = [System.Reflection.Assembly]::GetEntryAssembly()
        if ($assembly -and $assembly.Location) {
            return [System.IO.Path]::GetDirectoryName($assembly.Location)
        }

        $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        if ($exePath) {
            return [System.IO.Path]::GetDirectoryName($exePath)
        }

        return [Environment]::GetFolderPath("MyDocuments")
    } catch {
        return [Environment]::GetFolderPath("MyDocuments")
    }
}

# 💡 Jetzt sofort setzen:
$scriptBase = Get-ScriptBase

$global:overwriteAllConfirmed = $false
$global:enableLogging = $false
$global:logPath = $null
$global:progressForm = $null
$global:progressBar = $null
$global:progressLabel = $null
$global:speedLabel = $null

# 🔧 Robuste Pfaderkennung für .ps1 und .exe
function Get-ScriptBase {
    try {
        if ($MyInvocation.MyCommand.Path) {
            return Split-Path -Parent -Path $MyInvocation.MyCommand.Path
        }

        $assembly = [System.Reflection.Assembly]::GetEntryAssembly()
        if ($assembly -and $assembly.Location) {
            return [System.IO.Path]::GetDirectoryName($assembly.Location)
        }

        $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        if ($exePath) {
            return [System.IO.Path]::GetDirectoryName($exePath)
        }

        # Fallback: Benutzerordner
        return [Environment]::GetFolderPath("MyDocuments")
    } catch {
        return [Environment]::GetFolderPath("MyDocuments")
    }
}

$scriptBase = Get-ScriptBase

function Write-Log {
    param (
        [string]$message,
        [string]$level = "INFO"
    )

    if (-not $global:enableLogging -or -not $global:logPath) { return }

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $entry = "[$timestamp] [$level] $message"
    Add-Content -Path $global:logPath -Value $entry
}

function Show-ChoiceDialog {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Samba Copy Tool v1.0.0"
    $form.Size = New-Object System.Drawing.Size(360,230)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "What would you like to do?"
    $label.AutoSize = $true
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $label.Location = New-Object System.Drawing.Point(90,20)
    $form.Controls.Add($label)

    $uploadButton = New-Object System.Windows.Forms.Button
    $uploadButton.Text = "🔼 Upload"
    $uploadButton.Size = New-Object System.Drawing.Size(120,35)
    $uploadButton.Location = New-Object System.Drawing.Point(40,70)
    $uploadButton.DialogResult = [System.Windows.Forms.DialogResult]::Yes
    $form.Controls.Add($uploadButton)

    $downloadButton = New-Object System.Windows.Forms.Button
    $downloadButton.Text = "🔽 Download"
    $downloadButton.Size = New-Object System.Drawing.Size(120,35)
    $downloadButton.Location = New-Object System.Drawing.Point(190,70)
    $downloadButton.DialogResult = [System.Windows.Forms.DialogResult]::No
    $form.Controls.Add($downloadButton)

    $checkbox = New-Object System.Windows.Forms.CheckBox
    $checkbox.Text = "Create Logfile"
    $checkbox.AutoSize = $true
    $checkbox.Location = New-Object System.Drawing.Point(40,130)
    $checkbox.Checked = $false
    $form.Controls.Add($checkbox)

    $form.AcceptButton = $uploadButton
    $form.CancelButton = $downloadButton

    $dialogResult = $form.ShowDialog()
    $global:enableLogging = $checkbox.Checked
    return $dialogResult
}

function Show-FileDialog($title, $multi = $true) {
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = $title
    $dialog.Multiselect = $multi
    $dialog.Filter = "All files (*.*)|*.*"
    if ($dialog.ShowDialog() -eq "OK") {
        return $dialog.FileNames
    }
    return $null
}

function Show-FolderDialog($title) {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = $title
    if ($dialog.ShowDialog() -eq "OK") {
        return $dialog.SelectedPath
    }
    return $null
}

function Show-ConflictDialog {
    param ([string]$fileName)

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "File Conflict"
    $form.Size = New-Object System.Drawing.Size(420,170)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedSingle"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $true
    $form.ControlBox = $true
    $form.ShowInTaskbar = $true

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "The file '$fileName' already exists.`nWhat would you like to do?"
    $label.Size = New-Object System.Drawing.Size(380,40)
    $label.Location = New-Object System.Drawing.Point(20,15)
    $form.Controls.Add($label)

    $overwriteButton = New-Object System.Windows.Forms.Button
    $overwriteButton.Text = "Overwrite"
    $overwriteButton.Size = New-Object System.Drawing.Size(90,30)
    $overwriteButton.Location = New-Object System.Drawing.Point(20,70)
    $overwriteButton.Add_Click({ $form.Tag = "Overwrite"; $form.Close() })
    $form.Controls.Add($overwriteButton)

    $overwriteAllButton = New-Object System.Windows.Forms.Button
    $overwriteAllButton.Text = "Overwrite All"
    $overwriteAllButton.Size = New-Object System.Drawing.Size(100,30)
    $overwriteAllButton.Location = New-Object System.Drawing.Point(120,70)
    $overwriteAllButton.Add_Click({ $form.Tag = "OverwriteAll"; $form.Close() })
    $form.Controls.Add($overwriteAllButton)

    $renameButton = New-Object System.Windows.Forms.Button
    $renameButton.Text = "Rename"
    $renameButton.Size = New-Object System.Drawing.Size(90,30)
    $renameButton.Location = New-Object System.Drawing.Point(230,70)
    $renameButton.Add_Click({ $form.Tag = "Rename"; $form.Close() })
    $form.Controls.Add($renameButton)

    $skipButton = New-Object System.Windows.Forms.Button
    $skipButton.Text = "Skip"
    $skipButton.Size = New-Object System.Drawing.Size(90,30)
    $skipButton.Location = New-Object System.Drawing.Point(330,70)
    $skipButton.Add_Click({ $form.Tag = "Skip"; $form.Close() })
    $form.Controls.Add($skipButton)

    $form.Show()
    while ($form.Visible) {
        Start-Sleep -Milliseconds 100
        [System.Windows.Forms.Application]::DoEvents()
    }

    return $form.Tag
}

function Show-ProgressWindow {
    param ([int]$totalFiles)

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Copy Progress"
    $form.Size = New-Object System.Drawing.Size(500,180)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedSingle"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $true
    $form.ControlBox = $true
    $form.ShowInTaskbar = $true

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Preparing..."
    $label.Size = New-Object System.Drawing.Size(460,20)
    $label.Location = New-Object System.Drawing.Point(20,10)
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $form.Controls.Add($label)

    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Minimum = 0
    $progressBar.Maximum = $totalFiles
    $progressBar.Value = 0
    $progressBar.Size = New-Object System.Drawing.Size(460,20)
    $progressBar.Location = New-Object System.Drawing.Point(20,40)
    $form.Controls.Add($progressBar)

    $speedLabel = New-Object System.Windows.Forms.Label
    $speedLabel.Text = ""
    $speedLabel.Size = New-Object System.Drawing.Size(460,20)
    $speedLabel.Location = New-Object System.Drawing.Point(20,70)
    $speedLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $form.Controls.Add($speedLabel)

    $global:progressForm = $form
    $global:progressBar = $progressBar
    $global:progressLabel = $label
    $global:speedLabel = $speedLabel

    $form.Show()
}

function Update-ProgressWindow {
    param (
        [string]$fileName,
        [int]$currentIndex,
        [int]$totalFiles,
        [double]$speedMBps
    )

    if ($global:progressForm -ne $null -and !$global:progressForm.IsDisposed) {
        $global:progressLabel.Text = "Copying file ${currentIndex} of ${totalFiles}:`n$fileName"
        $global:progressBar.Value = $currentIndex
        if ($speedMBps -gt 0) {
            $global:speedLabel.Text = "Speed: {0:N2} MB/s" -f $speedMBps
        }
        [System.Windows.Forms.Application]::DoEvents()
    }
}

function Close-ProgressWindow {
    if ($global:progressForm -ne $null -and !$global:progressForm.IsDisposed) {
        $global:progressForm.Close()
        $global:progressForm = $null
    }
}

function Handle-Copy {
    param ([string[]]$sourceFiles, [string]$targetFolder)

    $total = $sourceFiles.Count
    $index = 0
    Show-ProgressWindow -totalFiles $total
    Write-Log "Copy started. Total files: $total"

    foreach ($file in $sourceFiles) {
        $index++
        try {
            $fileName = [System.IO.Path]::GetFileName($file)
            $targetPath = Join-Path $targetFolder $fileName

            if ($global:overwriteAllConfirmed) {
                $msg = "Overwrite"
            } elseif (Test-Path $targetPath) {
                if ($global:progressForm -ne $null) { $global:progressForm.Hide() }
                $msg = Show-ConflictDialog -fileName $fileName
                if ($global:progressForm -ne $null) { $global:progressForm.Show() }
            } else {
                $msg = $null
            }

            Write-Log "File: $fileName – Decision: $msg"

            switch ($msg) {
                'Overwrite' {
                    Write-Log "Overwriting: $fileName"
                }
                'OverwriteAll' {
                    $global:overwriteAllConfirmed = $true
                    Write-Log "Overwriting all remaining files"
                }
                'Rename' {
                    $base = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
                    $ext = [System.IO.Path]::GetExtension($fileName)
                    $i = 1
                    do {
                        $newName = "$base ($i)$ext"
                        $targetPath = Join-Path $targetFolder $newName
                        $i++
                    } while (Test-Path $targetPath)
                    $fileName = $newName
                    Write-Log "Renamed to: $fileName"
                }
                'Skip' {
                    Write-Log "Skipped: $fileName"
                    continue
                }
            }

            $sourceDir = [System.IO.Path]::GetDirectoryName($file)
            $escapedArgs = "`"$sourceDir`" `"$targetFolder`" `"$fileName`" /MT:8 /NP /R:1 /W:1 /IS /IT"

            Update-ProgressWindow -fileName $fileName -currentIndex $index -totalFiles $total -speedMBps 0
            $startTime = Get-Date
            Write-Log "Running robocopy for: $fileName"
            $proc = Start-Process -FilePath robocopy -ArgumentList $escapedArgs -NoNewWindow -Wait -PassThru
            $endTime = Get-Date

            $duration = ($endTime - $startTime).TotalSeconds
            $fileSize = (Get-Item $file).Length / 1MB
            $speed = if ($duration -gt 0) { $fileSize / $duration } else { 0 }

            Update-ProgressWindow -fileName $fileName -currentIndex $index -totalFiles $total -speedMBps $speed

            if ($proc.ExitCode -ge 8) {
                $msg = "Robocopy failed for '$fileName' – ExitCode: $($proc.ExitCode)"
                Write-Log $msg "ERROR"
                [System.Windows.Forms.MessageBox]::Show($msg, "Error", "OK", "Error")
            }

        } catch {
            $errorMsg = "Error with '$file': $_"
            Write-Log $errorMsg "ERROR"
            [System.Windows.Forms.MessageBox]::Show($errorMsg, "Error", "OK", "Error")
        }
    }

    Close-ProgressWindow
    Write-Log "Copy completed"
}

# Starte das Tool
$choice = Show-ChoiceDialog

if ($global:enableLogging) {
    $logRoot = Join-Path -Path ([Environment]::GetFolderPath("MyDocuments")) -ChildPath "SambaCopyTool\Logs"
    if (-not (Test-Path $logRoot)) {
        New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
    }
    $global:logPath = Join-Path $logRoot "smb-copytool.log"
    Write-Log "Tool gestartet"
    Write-Log "Benutzerauswahl: $choice"
}

if ($choice -eq "Yes") {
    $sourceFiles = Show-FileDialog "Select file(s) to upload"
    if (-not $sourceFiles) {
        Write-Log "Upload abgebrochen"
        exit
    }

    $targetFolder = Show-FolderDialog "Select the destination folder on the server"
    if (-not $targetFolder) {
        Write-Log "Zielordner für Upload abgebrochen"
        exit
    }

    Handle-Copy -sourceFiles $sourceFiles -targetFolder $targetFolder

} elseif ($choice -eq "No") {
    $sourceFiles = Show-FileDialog "Select file(s) from the server"
    if (-not $sourceFiles) {
        Write-Log "Download abgebrochen"
        exit
    }

    $targetFolder = Show-FolderDialog "Select the destination folder on your PC"
    if (-not $targetFolder) {
        Write-Log "Zielordner für Download abgebrochen"
        exit
    }

    Handle-Copy -sourceFiles $sourceFiles -targetFolder $targetFolder

} else {
    Write-Log "Benutzer hat das Tool beendet, ohne eine Aktion auszuwählen"
    exit
}

[System.Windows.Forms.MessageBox]::Show("File transfer completed!", "Done", "OK", "Information")
Write-Log "Transfer abgeschlossen"
