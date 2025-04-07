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

$exeDirectory = Split-Path -Parent $RoWin.DisplayIcon

# Ensure Invoke-PS2EXE is available
if (-not (Get-Command Invoke-PS2EXE -ErrorAction SilentlyContinue)) {
    $nuget = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue -Force
    if (-not $nuget -or $nuget.Version -lt [Version]"2.8.5.201") {
        $env:__SuppressPromptForNuGet = "true"
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ForceBootstrap -Scope CurrentUser
    }
    Write-Host "[⚙️] Invoke-PS2EXE not found. Installing..."
    try {
        Install-Module -Name PS2EXE -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        Import-Module PS2EXE
        Write-Host "[✅] PS2EXE installed successfully."
    } catch {
        Write-Host "[❌] Failed to install PS2EXE: $_"
        exit 1
    }
}

# Download script content from GitHub
$remoteScriptUrl = "https://raw.githubusercontent.com/Bahikka/romc-launcher/main/Launcher.ps1"
try {
    Write-Host "[🌐] Downloading script from GitHub..."
    $scriptContent = Invoke-WebRequest -Uri $remoteScriptUrl -UseBasicParsing
    $scriptContent = $scriptContent.Content
} catch {
    Write-Host "[❌] Failed to download the script: $_"
    exit 1
}

# Create a temporary file with a .ps1 extension
$tempScriptPath = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.ps1'
$scriptContent | Out-File -FilePath $tempScriptPath -Encoding UTF8

# Convert the temporary script to an executable using Invoke-PS2EXE
Invoke-PS2EXE -InputFile $tempScriptPath -OutputFile ([Environment]::GetFolderPath([Environment+SpecialFolder]::Desktop) + '\ROMC - Launcher.exe') `
    -iconFile ($exeDirectory + '\res\icon\Icon.ico') `
    -version '1' -title 'ROMC:MC' -product 'ROMC - Multi Client' `
    -noConsole -noOutput -noError -requireAdmin -STA | Out-Null

# Remove the temporary file
Remove-Item $tempScriptPath

Write-Host "✅ Conversion complete. ROMC:MC has been created."
