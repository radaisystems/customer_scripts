# Powershell script for SQL databases
# See README.md for usage

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$ServerName,

    [Parameter(Mandatory = $true)]
    [string]$DatabaseName,

    [Parameter(Mandatory = $true)]
    [string]$BackupDirectory,

    [Parameter(Mandatory = $false)]
    [string]$EncryptionPassword,

    [Parameter(Mandatory = $false)]
    [int]$MaxFileSizeMB = 10,

    [Parameter(Mandatory = $false)]
    [switch]$EnableEncryption = $false
)

# Define the log file path
$logFilePath = Join-Path $BackupDirectory "backup.log"

# Define the backup file path
$backupFileName = "$DatabaseName.bak"
$backupFilePath = Join-Path $BackupDirectory $backupFileName

# Create a log entry for the start of the backup
$currentDateTime = Get-Date
Add-Content $logFilePath "SQL backup started at $currentDateTime."

# Connect to the SQL Server instance
$server = New-Object Microsoft.SqlServer.Management.Smo.Server($ServerName)

# Create a backup object
$backup = New-Object Microsoft.SqlServer.Management.Smo.Backup
$backup.Action = "Database"
$backup.Database = $DatabaseName
$backup.Devices.AddDevice($backupFilePath, "File")

# Start the backup and log the output
try {
    $backup.SqlBackup($serverName)
    Add-Content -Path $logFilePath -Value $backup | Out-String
    Add-Content -Path $backupFilePath -Value (Get-FileHash -Path $backupFilePath -Algorithm MD5).Hash -Encoding Byte -Stream md5checksum
    Add-Content -Path $logFilePath -Value "Backup file MD5 checksum generated."
}
catch {
    Write-Error "Error performing SQL backup: $_. Exception: $($_.Exception.Message)"
    Add-Content -Path $logFilePath -Value "Error performing SQL backup: $_. Exception: $($_.Exception.Message)"
}

# Close the backup file
$backup.Dispose()

# Split the backup file into multiple files
$splitFiles = Split-File -Path $backupFilePath -FileSize $maxFileSizeMB

# Delete the original backup file
Remove-Item -Path $backupFilePath

# Move the split files to the backup directory
$splitFiles | ForEach-Object { Move-Item -Path $_.FullName -Destination $backupDir }

# Create a log entry for the split files
$splitFilesCount = $splitFiles.Count
Add-Content -Path $logFilePath -Value "Backup file split into $splitFilesCount files."

iif ($EnableEncryption) {
    # Iterate through the split files and encrypt each one
    foreach ($splitFile in $splitFiles) {
        $encryptedFileName = "$($splitFile.Name).enc"
        $encryptedFilePath = Join-Path $backupDir $encryptedFileName
        try {
            $secureString = ConvertTo-SecureString -String $encryptionPassword -AsPlainText -Force
            $key = New-Object byte[] 16
            $IV = New-Object byte[] 16
            $keyIV = New-Object byte[] 32
            [System.Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($keyIV)
            [System.Buffer]::BlockCopy($keyIV, 0, $key, 0, 16)
            [System.Buffer]::BlockCopy($keyIV, 16, $IV, 0, 16)
            $aes = New-Object System.Security.Cryptography.AesCryptoServiceProvider
            $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
            $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
            $aes.Key = $key
            $aes.IV = $IV
            $encryptor = $aes.CreateEncryptor()
            $inputStream = New-Object System.IO.FileStream($splitFile.FullName, 'Open', 'Read')
            $outputStream = New-Object System.IO.FileStream($encryptedFilePath, 'Create', 'Write')
            $cryptoStream = New-Object System.Security.Cryptography.CryptoStream($outputStream, $encryptor, 'Write')
            $buffer = New-Object byte[] 1024
            $count = $inputStream.Read($buffer, 0, $buffer.Length)
            while ($count -gt 0) {
                $cryptoStream.Write($buffer, 0, $count)
                $count = $inputStream.Read($buffer, 0, $buffer.Length)
            }
            $cryptoStream.Close()
            $inputStream.Close()
            $outputStream.Close()
            Add-Content -Path $logFilePath -Value "Encrypted backup file $($splitFile.Name) to $($encryptedFilePath)."
            Remove-Item -Path $splitFile.FullName
            Add-Content -Path $logFilePath -Value "Deleted unencrypted backup file $($splitFile.Name)."
        }
        catch {
            Write-Error "Error encrypting backup file $($splitFile.Name): $_. Exception: $($_.Exception.Message)"
            Add-Content -Path $logFilePath -Value "Error encrypting backup file $($splitFile.Name): $_. Exception: $($_.Exception.Message)"
        }
    }

    # Create a log entry for the encrypted files
    $encryptedFilesCount = (Get-ChildItem -Path $backupDir -Filter "*.enc" | Measure-Object).Count
    Add-Content -Path $logFilePath -Value "Backup files encrypted with password '$EncryptionPassword'."
    Add-Content -Path $logFilePath -Value "Backup files split into $encryptedFilesCount encrypted files."
}
else {
    # Create a log entry for the unencrypted files
    $splitFilesCount = $splitFiles.Count
    Add-Content -Path $logFilePath -Value "Backup files split into $splitFilesCount unencrypted files."
}
