function Get-InstalledApp {
    param(
        [string]$Pattern = 'RO_win*'
    )
    $uninstallKeys = @(
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $Apps = $uninstallKeys | ForEach-Object { Get-ItemProperty $_ -ErrorAction SilentlyContinue }
    return $Apps | Where-Object { $_.DisplayName -like $Pattern }
}

function Get-ScriptContent {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Source
    )
    if ($Source -match '^(http|https)://') {
        Write-Host "[🌐] Downloading script from $Source..."
        $result = Invoke-WebRequest -Uri $Source -UseBasicParsing
        return $result.Content
    } else {
        Write-Host "[📄] Reading script from $Source..."
        return Get-Content -Path $Source -Raw
    }
}
