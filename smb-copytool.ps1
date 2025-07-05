# === Imports & Globals ===
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$global:overwriteAllConfirmed = $false
$global:enableLogging = $false
$global:dryRun = $false
$global:logPath = $null
$global:progressForm = $null
$global:progressBar = $null
$global:progressLabel = $null
$global:speedLabel = $null
$global:startTime = $null
$global:renameAllWithTimestamp = $false
$global:stats = @{
    FilesCopied = 0
    FilesRenamed = 0
    FilesSkipped = 0
    FoldersCopied = 0
    FoldersSkipped = 0
}

# === Utility Functions ===
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
# === Dialogs: Choice, File/Folder Selection ===

function Show-ChoiceDialog {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Samba Copy Tool"
    $form.Size = New-Object System.Drawing.Size(360,260)
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
    $checkbox.Text = "Enable Logging"
    $checkbox.AutoSize = $true
    $checkbox.Location = New-Object System.Drawing.Point(40,130)
    $checkbox.Checked = $false
    $form.Controls.Add($checkbox)

    $dryRunCheckbox = New-Object System.Windows.Forms.CheckBox
    $dryRunCheckbox.Text = "Dry Run (simulate only)"
    $dryRunCheckbox.AutoSize = $true
    $dryRunCheckbox.Location = New-Object System.Drawing.Point(40,150)
    $dryRunCheckbox.Checked = $false
    $form.Controls.Add($dryRunCheckbox)

    $form.AcceptButton = $uploadButton
    $form.CancelButton = $downloadButton

    $dialogResult = $form.ShowDialog()
    $global:enableLogging = $checkbox.Checked
    $global:dryRun = $dryRunCheckbox.Checked
    return $dialogResult
}

function Show-TransferModeDialog {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Transfer Mode"
    $form.Size = New-Object System.Drawing.Size(360,200)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "What do you want to transfer?"
    $label.AutoSize = $true
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $label.Location = New-Object System.Drawing.Point(90,20)
    $form.Controls.Add($label)

    $filesButton = New-Object System.Windows.Forms.Button
    $filesButton.Text = "📄 Files"
    $filesButton.Size = New-Object System.Drawing.Size(80,35)
    $filesButton.Location = New-Object System.Drawing.Point(30,70)
    $filesButton.Add_Click({ $form.Tag = "Files"; $form.Close() })
    $form.Controls.Add($filesButton)

    $foldersButton = New-Object System.Windows.Forms.Button
    $foldersButton.Text = "📁 Folders"
    $foldersButton.Size = New-Object System.Drawing.Size(80,35)
    $foldersButton.Location = New-Object System.Drawing.Point(130,70)
    $foldersButton.Add_Click({ $form.Tag = "Folders"; $form.Close() })
    $form.Controls.Add($foldersButton)

    $bothButton = New-Object System.Windows.Forms.Button
    $bothButton.Text = "📄 + 📁 Both"
    $bothButton.Size = New-Object System.Drawing.Size(80,35)
    $bothButton.Location = New-Object System.Drawing.Point(230,70)
    $bothButton.Add_Click({ $form.Tag = "Both"; $form.Close() })
    $form.Controls.Add($bothButton)

    $form.ShowDialog() | Out-Null
    return $form.Tag
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
# === Dialogs: Multi-Selection for Files and Folders ===

function Show-MultiFolderSelection {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Select Folders to Transfer"
    $form.Size = New-Object System.Drawing.Size(500,400)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Selected folders:"
    $label.Location = New-Object System.Drawing.Point(20,20)
    $label.Size = New-Object System.Drawing.Size(200,20)
    $form.Controls.Add($label)

    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Location = New-Object System.Drawing.Point(20,50)
    $listBox.Size = New-Object System.Drawing.Size(440,220)
    $form.Controls.Add($listBox)

    $addButton = New-Object System.Windows.Forms.Button
    $addButton.Text = "Add Folder"
    $addButton.Size = New-Object System.Drawing.Size(120,30)
    $addButton.Location = New-Object System.Drawing.Point(20,290)
    $addButton.Add_Click({
        $folder = Show-FolderDialog "Select a Folder to add"
        if ($folder -and -not $listBox.Items.Contains($folder)) {
            $listBox.Items.Add($folder)
        }
    })
    $form.Controls.Add($addButton)

    $removeButton = New-Object System.Windows.Forms.Button
    $removeButton.Text = "Remove Selected"
    $removeButton.Size = New-Object System.Drawing.Size(140,30)
    $removeButton.Location = New-Object System.Drawing.Point(160,290)
    $removeButton.Add_Click({
        if ($listBox.SelectedItem) {
            $listBox.Items.Remove($listBox.SelectedItem)
        }
    })
    $form.Controls.Add($removeButton)

    $doneButton = New-Object System.Windows.Forms.Button
    $doneButton.Text = "Start Transfer"
    $doneButton.Size = New-Object System.Drawing.Size(120,30)
    $doneButton.Location = New-Object System.Drawing.Point(340,290)
    $doneButton.Add_Click({
        $form.Tag = "Done"
        $form.Close()
    })
    $form.Controls.Add($doneButton)

    $form.ShowDialog() | Out-Null
    return $listBox.Items
}

function Show-MultiFileSelection {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Select Files to Transfer"
    $form.Size = New-Object System.Drawing.Size(500,400)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Selected files:"
    $label.Location = New-Object System.Drawing.Point(20,20)
    $label.Size = New-Object System.Drawing.Size(200,20)
    $form.Controls.Add($label)

    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Location = New-Object System.Drawing.Point(20,50)
    $listBox.Size = New-Object System.Drawing.Size(440,220)
    $form.Controls.Add($listBox)

    $addButton = New-Object System.Windows.Forms.Button
    $addButton.Text = "Add Files"
    $addButton.Size = New-Object System.Drawing.Size(120,30)
    $addButton.Location = New-Object System.Drawing.Point(20,290)
    $addButton.Add_Click({
        $files = Show-FileDialog "Select file(s) to add"
        if ($files) {
            foreach ($file in $files) {
                if (-not $listBox.Items.Contains($file)) {
                    $listBox.Items.Add($file)
                }
            }
        }
    })
    $form.Controls.Add($addButton)

    $removeButton = New-Object System.Windows.Forms.Button
    $removeButton.Text = "Remove Selected"
    $removeButton.Size = New-Object System.Drawing.Size(140,30)
    $removeButton.Location = New-Object System.Drawing.Point(160,290)
    $removeButton.Add_Click({
        if ($listBox.SelectedItem) {
            $listBox.Items.Remove($listBox.SelectedItem)
        }
    })
    $form.Controls.Add($removeButton)

    $doneButton = New-Object System.Windows.Forms.Button
    $doneButton.Text = "Start Transfer"
    $doneButton.Size = New-Object System.Drawing.Size(120,30)
    $doneButton.Location = New-Object System.Drawing.Point(340,290)
    $doneButton.Add_Click({
        $form.Tag = "Done"
        $form.Close()
    })
    $form.Controls.Add($doneButton)

    $form.ShowDialog() | Out-Null
    return $listBox.Items
}

function Show-MixedSelection {
    $mode = Show-TransferModeDialog
    $allItems = @()

    if ($mode -eq "Files" -or $mode -eq "Both") {
        $files = Show-MultiFileSelection
        if ($files) { $allItems += $files }
    }

    if ($mode -eq "Folders" -or $mode -eq "Both") {
        $folders = Show-MultiFolderSelection
        if ($folders) { $allItems += $folders }
    }

    return $allItems | Select-Object -Unique
}
# === Dialogs: Progress Window & Conflict Handling ===

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

        $elapsed = (Get-Date) - $global:startTime
        $remaining = if ($currentIndex -gt 0) {
            $avg = $elapsed.TotalSeconds / $currentIndex
            [TimeSpan]::FromSeconds($avg * ($totalFiles - $currentIndex))
        } else {
            [TimeSpan]::Zero
        }

        $global:speedLabel.Text = "Speed: {0:N2} MB/s – ETA: {1:mm\:ss}" -f $speedMBps, $remaining
        [System.Windows.Forms.Application]::DoEvents()
    }
}

function Close-ProgressWindow {
    if ($global:progressForm -ne $null -and !$global:progressForm.IsDisposed) {
        $global:progressForm.Close()
        $global:progressForm = $null
    }
}

function Show-FileConflictDialog {
    param (
        [string]$sourcePath,
        [string]$targetPath
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "File Conflict"
    $form.Size = New-Object System.Drawing.Size(600,380)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $sourceInfo = Get-Item $sourcePath
    $targetInfo = Get-Item $targetPath

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "The file already exists. What would you like to do?"
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $label.AutoSize = $true
    $label.Location = New-Object System.Drawing.Point(20,20)
    $form.Controls.Add($label)

    $details = @"
Source: $($sourceInfo.FullName)
Target: $($targetInfo.FullName)
"@

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Multiline = $true
    $textBox.ReadOnly = $true
    $textBox.ScrollBars = "Vertical"
    $textBox.Text = $details
    $textBox.Size = New-Object System.Drawing.Size(540,80)
    $textBox.Location = New-Object System.Drawing.Point(20,50)
    $form.Controls.Add($textBox)

    $sourceSize = $sourceInfo.Length
    $targetSize = $targetInfo.Length
    $sizeColor = if ($sourceSize -gt $targetSize) { 'Red' } else { 'Black' }

    $sizeLabel = New-Object System.Windows.Forms.Label
    $sizeLabel.Text = "Source size: $([math]::Round($sourceSize / 1MB, 2)) MB`nTarget size: $([math]::Round($targetSize / 1MB, 2)) MB"
    $sizeLabel.Location = New-Object System.Drawing.Point(20,140)
    $sizeLabel.Size = New-Object System.Drawing.Size(540,40)
    $sizeLabel.ForeColor = $sizeColor
    $form.Controls.Add($sizeLabel)

    $renameLabel = New-Object System.Windows.Forms.Label
    $renameLabel.Text = "New name (if renaming):"
    $renameLabel.Location = New-Object System.Drawing.Point(20,185)
    $renameLabel.Size = New-Object System.Drawing.Size(200,20)
    $form.Controls.Add($renameLabel)

    $renameBox = New-Object System.Windows.Forms.TextBox
    $renameBox.Text = [System.IO.Path]::GetFileNameWithoutExtension($sourceInfo.Name) + " - Copy" + [System.IO.Path]::GetExtension($sourceInfo.Name)
    $renameBox.Location = New-Object System.Drawing.Point(20,210)
    $renameBox.Size = New-Object System.Drawing.Size(540,25)
    $form.Controls.Add($renameBox)

    $applyAllCheckbox = New-Object System.Windows.Forms.CheckBox
    $applyAllCheckbox.Text = "Apply this action to all remaining conflicts"
    $applyAllCheckbox.Location = New-Object System.Drawing.Point(20,245)
    $applyAllCheckbox.Size = New-Object System.Drawing.Size(400,20)
    $form.Controls.Add($applyAllCheckbox)

    $overwriteButton = New-Object System.Windows.Forms.Button
    $overwriteButton.Text = "Overwrite"
    $overwriteButton.Size = New-Object System.Drawing.Size(100,30)
    $overwriteButton.Location = New-Object System.Drawing.Point(20,280)
    $overwriteButton.Add_Click({ $form.Tag = "Overwrite"; $form.Close() })
    $form.Controls.Add($overwriteButton)

    $renameButton = New-Object System.Windows.Forms.Button
    $renameButton.Text = "Rename"
    $renameButton.Size = New-Object System.Drawing.Size(100,30)
    $renameButton.Location = New-Object System.Drawing.Point(130,280)
    $renameButton.Add_Click({
        $form.Tag = "Rename"
        if ($applyAllCheckbox.Checked) {
            $global:renameAllWithTimestamp = $true
        }
        $form.Close()
    })
    $form.Controls.Add($renameButton)

    $skipButton = New-Object System.Windows.Forms.Button
    $skipButton.Text = "Skip"
    $skipButton.Size = New-Object System.Drawing.Size(100,30)
    $skipButton.Location = New-Object System.Drawing.Point(240,280)
    $skipButton.Add_Click({ $form.Tag = "Skip"; $form.Close() })
    $form.Controls.Add($skipButton)

    $form.ShowDialog() | Out-Null

    return @{
        Action = $form.Tag
        NewName = $renameBox.Text
        ApplyToAll = $applyAllCheckbox.Checked
    }
}
# === Dialogs: Folder Conflict Handling ===

function Show-FolderConflictDialog {
    param (
        [string]$sourcePath,
        [string]$targetPath
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Folder Conflict"
    $form.Size = New-Object System.Drawing.Size(600,300)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "A folder with the same name already exists. What would you like to do?"
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $label.AutoSize = $true
    $label.Location = New-Object System.Drawing.Point(20,20)
    $form.Controls.Add($label)

    $details = @"
Source: $sourcePath
Target: $targetPath
"@

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Multiline = $true
    $textBox.ReadOnly = $true
    $textBox.ScrollBars = "Vertical"
    $textBox.Text = $details
    $textBox.Size = New-Object System.Drawing.Size(540,80)
    $textBox.Location = New-Object System.Drawing.Point(20,50)
    $form.Controls.Add($textBox)

    $renameLabel = New-Object System.Windows.Forms.Label
    $renameLabel.Text = "New folder name (if renaming):"
    $renameLabel.Location = New-Object System.Drawing.Point(20,140)
    $renameLabel.Size = New-Object System.Drawing.Size(250,20)
    $form.Controls.Add($renameLabel)

    $renameBox = New-Object System.Windows.Forms.TextBox
    $renameBox.Text = ([System.IO.Path]::GetFileName($sourcePath)) + " - Copy"
    $renameBox.Location = New-Object System.Drawing.Point(20,165)
    $renameBox.Size = New-Object System.Drawing.Size(540,25)
    $form.Controls.Add($renameBox)

    $applyAllCheckbox = New-Object System.Windows.Forms.CheckBox
    $applyAllCheckbox.Text = "Apply this action to all remaining folder conflicts"
    $applyAllCheckbox.Location = New-Object System.Drawing.Point(20,200)
    $applyAllCheckbox.Size = New-Object System.Drawing.Size(400,20)
    $form.Controls.Add($applyAllCheckbox)

    $overwriteButton = New-Object System.Windows.Forms.Button
    $overwriteButton.Text = "Overwrite"
    $overwriteButton.Size = New-Object System.Drawing.Size(100,30)
    $overwriteButton.Location = New-Object System.Drawing.Point(20,230)
    $overwriteButton.Add_Click({ $form.Tag = "Overwrite"; $form.Close() })
    $form.Controls.Add($overwriteButton)

    $renameButton = New-Object System.Windows.Forms.Button
    $renameButton.Text = "Rename"
    $renameButton.Size = New-Object System.Drawing.Size(100,30)
    $renameButton.Location = New-Object System.Drawing.Point(130,230)
    $renameButton.Add_Click({ $form.Tag = "Rename"; $form.Close() })
    $form.Controls.Add($renameButton)

    $skipButton = New-Object System.Windows.Forms.Button
    $skipButton.Text = "Skip"
    $skipButton.Size = New-Object System.Drawing.Size(100,30)
    $skipButton.Location = New-Object System.Drawing.Point(240,230)
    $skipButton.Add_Click({ $form.Tag = "Skip"; $form.Close() })
    $form.Controls.Add($skipButton)

    $form.ShowDialog() | Out-Null

    return @{
        Action = $form.Tag
        NewName = $renameBox.Text
        ApplyToAll = $applyAllCheckbox.Checked
    }
}

# === Core Logic: File & Folder Copy ===
function Handle-Copy {
    param (
        [string[]]$sourceFiles,
        [string]$targetFolder,
        [int]$currentIndex = 1,
        [int]$totalItems = 1
    )

    foreach ($file in $sourceFiles) {
        try {
            $originalName = [System.IO.Path]::GetFileName($file)
            $fileName = $originalName
            $targetPath = Join-Path $targetFolder $fileName
            $useRobocopy = $true

            # === Automatischer Rename-All ohne Dialog ===
            if ($global:renameAllWithTimestamp) {
                $base = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
                $ext = [System.IO.Path]::GetExtension($fileName)
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss_fff"
                $fileName = "$base - $timestamp$ext"
                $targetPath = Join-Path $targetFolder $fileName
                Write-Log "Renamed with timestamp: $fileName"
                if (-not $global:dryRun) {
                    Copy-Item -Path $file -Destination $targetPath -Force
                }
                $global:stats.FilesCopied++
                $global:stats.FilesRenamed++
                Update-ProgressWindow -fileName $fileName -currentIndex $currentIndex -totalFiles $totalItems -speedMBps 0
                continue
            }

            # === Konfliktbehandlung ===
            if ($global:overwriteAllConfirmed) {
                $msg = "Overwrite"
            } elseif (Test-Path $targetPath) {
                if ($global:progressForm -ne $null) { $global:progressForm.Hide() }
                $conflict = Show-FileConflictDialog -sourcePath $file -targetPath $targetPath
                if ($global:progressForm -ne $null) { $global:progressForm.Show() }

                $msg = $conflict.Action

                if ($conflict.ApplyToAll -and $msg -eq "Overwrite") {
                    $global:overwriteAllConfirmed = $true
                }

                if ($msg -eq "Rename") {
                    if ($conflict.ApplyToAll) {
                        $global:renameAllWithTimestamp = $true
                        $base = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
                        $ext = [System.IO.Path]::GetExtension($fileName)
                        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss_fff"
                        $fileName = "$base - $timestamp$ext"
                    } else {
                        $fileName = $conflict.NewName
                    }
                    $targetPath = Join-Path $targetFolder $fileName
                    $useRobocopy = $false
                }

                if ($msg -eq "Skip") {
                    Write-Log "Skipped: $fileName"
                    $global:stats.FilesSkipped++
                    continue
                }
            }

            Write-Log "File: $fileName – Decision: $msg"
            Update-ProgressWindow -fileName $fileName -currentIndex $currentIndex -totalFiles $totalItems -speedMBps 0
            $startTime = Get-Date

            if ($useRobocopy) {
                $sourceDir = [System.IO.Path]::GetDirectoryName($file)
                $args = "`"$sourceDir`" `"$targetFolder`" `"$originalName`" /MT:8 /NP /R:1 /W:1 /IS /IT"
                if ($global:dryRun) { $args += " /L" }

                Write-Log "Running robocopy for: $originalName"
                $proc = Start-Process -FilePath robocopy -ArgumentList $args -NoNewWindow -Wait -PassThru
                $endTime = Get-Date

                if ($proc.ExitCode -ge 8) {
                    $msg = "Robocopy failed for '$originalName' – ExitCode: $($proc.ExitCode)"
                    Write-Log $msg "ERROR"
                    [System.Windows.Forms.MessageBox]::Show($msg, "Error", "OK", "Error")
                } else {
                    $global:stats.FilesCopied++
                }
            } else {
                if (-not $global:dryRun) {
                    Copy-Item -Path $file -Destination $targetPath -Force
                }
                $endTime = Get-Date
                $global:stats.FilesCopied++
                $global:stats.FilesRenamed++
                Write-Log "Renamed with timestamp: $fileName"
            }

            $duration = ($endTime - $startTime).TotalSeconds
            $fileSize = (Get-Item $file).Length / 1MB
            $speed = if ($duration -gt 0) { $fileSize / $duration } else { 0 }

            Update-ProgressWindow -fileName $fileName -currentIndex $currentIndex -totalFiles $totalItems -speedMBps $speed

        } catch {
            $errorMsg = "Error with '$file': $_"
            Write-Log $errorMsg "ERROR"
            [System.Windows.Forms.MessageBox]::Show($errorMsg, "Error", "OK", "Error")
        }
    }
}

function Handle-FolderCopy {
    param (
        [string]$sourceFolder,
        [string]$targetFolder,
        [int]$currentIndex = 1,
        [int]$totalItems = 1
    )

    $folderName = [System.IO.Path]::GetFileName($sourceFolder.TrimEnd('\'))
    $destinationPath = Join-Path $targetFolder $folderName
    $useRobocopy = $true

    if (-not $global:overwriteAllConfirmed -and (Test-Path $destinationPath)) {
        if ($global:progressForm -ne $null) { $global:progressForm.Hide() }
        $conflict = Show-FolderConflictDialog -sourcePath $sourceFolder -targetPath $destinationPath
        if ($global:progressForm -ne $null) { $global:progressForm.Show() }

        $msg = $conflict.Action

        if ($conflict.ApplyToAll -and $msg -eq "Overwrite") {
            $global:overwriteAllConfirmed = $true
        }

        switch ($msg) {
            "Rename" {
                if ($conflict.ApplyToAll) {
                    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss_fff"
                    $folderName = "$folderName - $timestamp"
                } else {
                    $folderName = $conflict.NewName
                }
                $destinationPath = Join-Path $targetFolder $folderName
                $useRobocopy = $true
            }
            "Skip" {
                Write-Log "Skipped folder: $sourceFolder"
                $global:stats.FoldersSkipped++
                continue
            }
        }
    }

    Update-ProgressWindow -fileName $folderName -currentIndex $currentIndex -totalFiles $totalItems -speedMBps 0

    try {
        $startTime = Get-Date
        $args = "`"$sourceFolder`" `"$destinationPath`" /E /MT:8 /NP /R:1 /W:1 /IS /IT"
        if ($global:dryRun) { $args += " /L" }

        Write-Log "Running robocopy for folder: $sourceFolder"
        $proc = Start-Process -FilePath robocopy -ArgumentList $args -NoNewWindow -Wait -PassThru
        $endTime = Get-Date

        $duration = ($endTime - $startTime).TotalSeconds
        $folderSize = (Get-ChildItem -Path $sourceFolder -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
        $speed = if ($duration -gt 0) { $folderSize / $duration } else { 0 }

        Update-ProgressWindow -fileName $folderName -currentIndex $currentIndex -totalFiles $totalItems -speedMBps $speed

        if ($proc.ExitCode -ge 8) {
            $msg = "Robocopy failed for folder '$folderName' – ExitCode: $($proc.ExitCode)"
            Write-Log $msg "ERROR"
            [System.Windows.Forms.MessageBox]::Show($msg, "Error", "OK", "Error")
        } else {
            Write-Log "Folder copied successfully: $folderName"
            $global:stats.FoldersCopied++
        }

    } catch {
        $errorMsg = "Error copying folder '$folderName': $_"
        Write-Log $errorMsg "ERROR"
        [System.Windows.Forms.MessageBox]::Show($errorMsg, "Error", "OK", "Error")
    }
}

# === Main Execution ===
$choice = Show-ChoiceDialog

if ($global:enableLogging) {
    $logRoot = Join-Path -Path ([Environment]::GetFolderPath("MyDocuments")) -ChildPath "SambaCopyTool\Logs"
    if (-not (Test-Path $logRoot)) {
        New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
    }
    $global:logPath = Join-Path $logRoot "smb-copytool.log"
    Write-Log "Tool started"
    Write-Log "User choice: $choice"
}

if ($choice -eq "Yes" -or $choice -eq "No") {
    $isUpload = ($choice -eq "Yes")
    $sourceItems = Show-MixedSelection

    if (-not $sourceItems -or ($sourceItems | Where-Object { $_ -and ($_ -ne "") }).Count -eq 0) {
        Write-Log "No source selected – operation cancelled"
        exit
    }

    if ($isUpload) {
        $targetFolder = Show-FolderDialog "Select destination folder for upload"
    } else {
        $targetFolder = Show-FolderDialog "Select destination folder for download"
    }

    if (-not $targetFolder) {
        Write-Log "Target folder selection cancelled"
        exit
    }

    $totalItems = $sourceItems.Count
    $index = 0
    $global:startTime = Get-Date
    Show-ProgressWindow -totalFiles $totalItems
    Write-Log "Transfer started. Total items: $totalItems"

    foreach ($item in $sourceItems) {
        $index++
        if (Test-Path $item -PathType Container) {
            Handle-FolderCopy -sourceFolder $item -targetFolder $targetFolder -currentIndex $index -totalItems $totalItems
        } else {
            Handle-Copy -sourceFiles @($item) -targetFolder $targetFolder -currentIndex $index -totalItems $totalItems
        }
    }

    Close-ProgressWindow
    [System.Windows.Forms.MessageBox]::Show("Transfer completed!", "Done", "OK", "Information")
    $summary = @"
    Transfer Summary:

    ✔ Files copied:     $($global:stats.FilesCopied)
    📝 Files renamed:    $($global:stats.FilesRenamed)
    ⏭ Files skipped:    $($global:stats.FilesSkipped)
    📁 Folders copied:   $($global:stats.FoldersCopied)
    📂 Folders skipped:  $($global:stats.FoldersSkipped)
"@

    [System.Windows.Forms.MessageBox]::Show($summary, "Transfer Summary", "OK", "Information")
    Write-Log "Transfer Summary:`n$summary"
    Write-Log "Transfer completed"

    if ($global:enableLogging -and (Test-Path $global:logPath)) {
        Start-Process notepad.exe $global:logPath
    }

} else {
    Write-Log "User exited without selecting an action"
    exit
}
