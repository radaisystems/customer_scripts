# SQL Server Backup Script

This PowerShell script connects to a Microsoft SQL Server database and performs an SQL dump to create a backup file. The backup file is split into multiple files of up to 10MB each to make it easier to manage and transfer. The script also logs the backup output to a log file and performs data integrity validation using MD5 checksums. It also has the option to enable encryption when creating the split files.

## Prerequisites

- PowerShell version 5.0 or higher
- Microsoft SQL Server Management Objects (SMO) version 16.5 or higher
- Optional: 7-Zip version 19.00 or higher, if you want to compress the split files

## Usage

To use the script, open PowerShell and run the following command:

```powershell
.\Backup-SqlDatabase.ps1 -ServerName <ServerName> -DatabaseName <DatabaseName> -BackupDirectory <BackupDirectory> [-EncryptionPassword <EncryptionPassword>] [-MaxFileSizeMB <MaxFileSizeMB>] [-EnableEncryption] [-Verbose]
```

Replace `<ServerName>` with the name of the SQL Server instance you want to connect to, `<DatabaseName>` with the name of the database you want to back up, and `<BackupDirectory>` with the path to the directory where you want to store the backup files.

The optional parameters are as follows:

- `-EncryptionPassword <EncryptionPassword>`: Password to use for encrypting the split backup files. If not specified, the split files will not be encrypted.
- `-MaxFileSizeMB <MaxFileSizeMB>`: Maximum file size (in megabytes) for the split backup files. Default is 10 MB.
- `-EnableEncryption`: Enables encryption for the split backup files. If not specified, the split files will not be encrypted.
- `-Verbose`: Enables verbose output for debugging purposes.

## License

This script is licensed under the MIT License. See the [LICENSE](LICENSE) file for more information.

## Acknowledgments

This script is based on the following resources:

- [Splitting Large Backup Files for Use on DVD+/-R Media](https://www.red-gate.com/simple-talk/sql/database-administration/splitting-large-backup-files-for-use-on-dvd-r-media/)
- [PowerShell Script to Backup a SQL Server Database](https://gallery.technet.microsoft.com/scriptcenter/PowerShell-Script-to-35f8b3c6)
