# SQL Backup Script for Fluency / MModal Database

This script is designed to create a backup of a Fluency / MModal database using SQL Server. The script retrieves specific data from the database and exports it to XML files for backup purposes. The following instructions will guide you on how to use this script effectively.

## Prerequisites
- SQL Server Management Studio or any other SQL Server management tool.
- Access to the Fluency / MModal database.

## Instructions

1. Open SQL Server Management Studio and connect to the SQL Server instance hosting the Fluency / MModal database.

2. Create a new query window and paste the provided script into it.

3. Modify the script according to your backup requirements. The script contains several variables that you can adjust based on your needs:

   - `@Path`: Specify the path where the backup files will be stored. Replace `'D:\ReportExport'` with your desired backup directory path.
   - `@BeginDate`: Set the start date for the backup range. Replace `'7/1/2019 05:00'` with the desired start date.
   - `@EndDate`: Set the end date for the backup range. Replace `'6/30/2022 04:59'` with the desired end date.
   - `@Filename`: Specify the prefix for the backup files. Replace `'FFI_Reports'` with your preferred filename.

4. Verify that the database name in the script matches your Fluency / MModal database. The script contains the following line:

   ```sql
   Use MModalServices
   ```

   If your database name is different, replace `'MModalServices'` with the correct database name.

5. Review the script for any additional customizations you may require.

6. Once you have configured the script according to your needs, execute it by clicking the "Execute" button or pressing the F5 key.

7. The script will start creating the backup files in XML format for the specified date range and save them to the specified directory.

8. Monitor the execution progress and wait for the script to complete. It may take some time depending on the amount of data to be backed up.

9. After the script finishes, you can verify the backup by checking the tables `@z` and `FFI_UploadXMLs` that store the extracted data and XML files, respectively.

   - The `@z` table contains the extracted data, including job details, physician information, modality, procedure description, and report content.
   - The `FFI_UploadXMLs` table stores the generated XML files along with the date and time of the backup.

10. Once the backup process is complete, you can access the generated XML files in the specified backup directory (`@Path`) for further usage or archival purposes.

   - The backup files are organized in folders named after the accession numbers of the corresponding reports.
   - Each backup folder contains the XML file representing a report, with the report content, metadata, and related information.

**Note:** It's important to ensure that you have sufficient disk space available at the specified backup path to accommodate the generated backup files.

## Important Considerations

- This script is intended for Fluency / MModal databases and may not be suitable for other database systems.
- It's recommended to perform regular backups of your Fluency / MModal database to ensure data integrity and availability.
- Consult your organization's guidelines and policies regarding data backup and retention before using this script.
- Make sure to securely store and protect the generated backup files to prevent unauthorized access.
- It's advisable to test the backup files and ensure their integrity before relying on them for restoration purposes.
