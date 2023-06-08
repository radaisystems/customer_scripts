# MModal Report Export Script

This script is used to export MModal reports along with additional data, such as report-level information and an exam code dictionary. The exported data is saved in XML format.

## Prerequisites

- SQL Server Management Studio or a similar tool to execute SQL scripts.
- Access to the MModalServices and ClinicalDataStore databases.

## Setup

1. Open SQL Server Management Studio and connect to your database server.
2. Open a new query window and execute the script provided in the file [MModalReportExport.sql](./MModalReportExport.sql). Make sure to execute the script in the context of the MModalServices database.

## Configuration

Before executing the script, you need to configure the following parameters:

- `@Path`: Specify the path where the exported XML files will be saved.
- `@BeginDate`: Set the start date for the report export range.
- `@EndDate`: Set the end date for the report export range.

Make sure to modify the values of these parameters in the script according to your requirements.

## Exam Code Dictionary

The script also includes an exam code dictionary that provides additional information about each exam code. The dictionary includes the following fields:

- Exam code
- Exam code description
- Modality
- Body part

To customize the exam code dictionary, you need to replace the placeholder `YourExamCodeDictionaryTable` in the script with the actual table name that contains your exam code dictionary data.

## Execution

1. Once you have configured the script and set the parameters, execute the script in SQL Server Management Studio.
2. The script will search for MModal reports within the specified date range and export them to XML files.
3. The exported XML files will be saved in the path specified by the `@Path` parameter.

## Output

The script generates two result sets:

1. Report-level data: This result set includes the following fields for each exported report:
   - MRN
   - ACC
   - Exam code
   - Exam code description

2. Exam code dictionary: This result set includes the following fields for each exam code:
   - Exam code
   - Exam code description
   - Modality
   - Body part

You can use these result sets to analyze and process the exported data as needed.
