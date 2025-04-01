# Import Security Module (for Credential Handling)
Import-Module -Name “C:\Windows\SysWOW64\WindowsPowerShell\v1.0\Modules\Microsoft.PowerShell.Security\Microsoft.PowerShell.Security.psd1” -Force

# Function to get installed applications (Optimized Single Query)
function Get-InstalledApp {
    $uninstallKeys = @(
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $Apps = $uninstallKeys | ForEach-Object { Get-ItemProperty $_ -ErrorAction SilentlyContinue }
    return $Apps | Where-Object { $_.DisplayName -like 'RO_win*' }
}

# Define paths dynamically based on the installed application
Write-Host "[🔍] Searching for installed RO_win..."
$RoWin = Get-InstalledApp
if (-not $RoWin) {
    Write-Host "[❌] RO_win not found. Exiting..."
    exit
}

$adsFile = $RoWin.DisplayIcon
$selectionFile = (Split-Path -Parent $RoWin.DisplayIcon) + '\Accounts.cfg'
$keyFileName = ".ads_executed"

# Get all valid local users
$validProfiles = Get-LocalUser | Where-Object { $_.Enabled -eq $true } | Select-Object -ExpandProperty Name

# Get all users who have previously executed the software and are still valid
$existingUsers = Get-ChildItem "C:\Users" -Directory | Where-Object { 
    $_.Name -in $validProfiles -and (Test-Path "C:\Users\$_\$keyFileName")
} | Select-Object -ExpandProperty Name

# Selection UI logic (wrapped to allow re-invocation after editing)
function Show-CharacterSelection {
    # Load saved characters from Accounts.cfg (if available)
    $savedChars = @(if (Test-Path $selectionFile) { Get-Content $selectionFile | Where-Object { $_ -ne "" } } else { $null | Set-Content $selectionFile; @() })

    # Combine and deduplicate all character sources
    $allUsers = @($savedChars + $existingUsers) | Sort-Object -Unique

    if ($allUsers.Count -gt 0) {
        Write-Host "`n[📋] Select characters to run the software:`n"

        $userChoices = @(
            [PSCustomObject]@{ User = "▶️ Use Last Session Selection"; 'Last Session Characters' = ($savedChars -join ', ') }
            [PSCustomObject]@{ User = "📄 Edit Accounts.cfg"; 'Last Session Characters' = "" }
        ) + ($allUsers | ForEach-Object {
            [PSCustomObject]@{
                User = $_
                'Last Session Characters' = if ($savedChars -contains $_) { "[✔] Previously Selected" } else { "[❌] Not Selected" }
            }
        })

        $selectedUsers = $userChoices | Out-GridView -Title "Select Characters" -PassThru | Select-Object -ExpandProperty User

        if (-not $selectedUsers -or $selectedUsers.Count -eq 0) {
            Write-Host "[❌] No selection made. Exiting..."
            return @()
        }

        if ($selectedUsers -contains "📄 Edit Accounts.cfg") {
            Write-Host "[✏️] Opening Accounts.cfg for editing..."
            Start-Process notepad.exe -ArgumentList "`"$selectionFile`"" -Wait
            return Show-CharacterSelection
        }

        if ($selectedUsers -contains "▶️ Use Last Session Selection") {
            if (-not $savedChars -or $savedChars.Count -eq 0) {
                Write-Host "[⚠️] No previous selection found. Please select characters manually."
                return Show-CharacterSelection
            }
            return $savedChars
        } else {
            # Filter out system entries
            $selectedUsers = $selectedUsers | Where-Object {
                ($_ -ne "▶️ Use Last Session Selection") -and ($_ -ne "📄 Edit Accounts.cfg")
            }

            # Save new selection
            $selectedUsers | Set-Content $selectionFile

            return $selectedUsers
        }
    } else {
        Write-Host "[ℹ] No characters found in Accounts.cfg. Please Add a character."
        Start-Process notepad.exe -ArgumentList "`"$selectionFile`"" -Wait
        return Show-CharacterSelection
    }
}

# Invoke the character selection
$selectedUsers = Show-CharacterSelection

# Function to rename the window for the correct process
function Set-WindowTitle {
    param([string]$newTitle, [int]$processId)
    
    $sig = '[DllImport("user32.dll", SetLastError = true)] public static extern bool SetWindowText(IntPtr hWnd, string lpString);'
    $User32 = Add-Type -MemberDefinition $sig -Name "Win32SetWindowText" -Namespace Win32Functions -PassThru
    
    # Retry logic to ensure the window handle is available
    for ($i = 0; $i -lt 50; $i++) {
        $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
        if ($process -and $process.MainWindowHandle -ne 0) {
            while (-not $User32::SetWindowText($process.MainWindowHandle, $newTitle)) {  Start-Sleep -Milliseconds 100}
            Write-Host "[✅] Window renamed to '$newTitle' (PID: $processId)"
            return
        }
        Start-Sleep -Milliseconds 100
    }
    
    Write-Host "[⚠] Could not rename the window for PID: $processId"
}

# Loop through selected users and execute the game
foreach ($username in $selectedUsers) {
    # Set user credentials
    $password = ConvertTo-SecureString -String $username -AsPlainText -Force
    $existingUser = Get-LocalUser | Where-Object { $_.Name -eq $username }
    
    if (-not $existingUser) {
        Write-Host "[+] Creating user '$username'..."
        New-LocalUser -Name $username -Password $password -FullName $username -Description "Auto-created for ADS execution" -PasswordNeverExpires
        } else {
        Write-Host "[+] Using existing user '$username'."
    }
    
    # Create a key file to track execution    
    New-Item -ItemType File -Path "C:\Users\$username\$keyFileName" -Force | Out-Null
    
    # Copy EXE into an NTFS Alternate Data Stream inside itself
    $adsStream = $username
    Get-Content $adsFile -Raw | Set-Content "$adsFile`:$adsStream" -NoNewline
    
    # Start the process with credentials
    Write-Host "[🚀] Running '$adsFile`:$adsStream' as user '$username'"
    $process = Start-Process -FilePath "$adsFile`:$adsStream" -WorkingDirectory (Split-Path -Parent $RoWin.DisplayIcon) -Credential (New-Object System.Management.Automation.PSCredential ($username, $password)) -PassThru -NoNewWindow -ErrorAction SilentlyContinue
    
    # Rename the window after ensuring the process exists    
    Set-WindowTitle -newTitle "$username" -processId $process.Id
  
    # Clean up ADS
    Remove-Item "$adsFile`:$adsStream" -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 5
}

Write-Host "[✅] Execution completed and character tracking updated."
