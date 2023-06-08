# Fluency database backups

This repository contains two scripts that serve different purposes. Here's an overview of each script:

## PHI script - MModal Report Export SQL Script

The `MModalReportExport.sql` script is designed to gather data that may contain Personally Identifiable Information (PHI). It collects information such as MRN (Medical Record Number), ACC (Accession Number), exam codes, and exam code descriptions. The exported data is saved in XML format.

## Non-PHI script - SQL Backup Script for Fluency / MModal Database

The `fluencyScript.sql` script is dedicated to performing database backups for non-PHI data. It retrieves specific data from the Fluency / MModal database and exports it to XML files for backup purposes. The backup process involves extracting job details, physician information, modality, procedure description, and report content. These backups are saved in XML format for further usage or archival purposes.

It's important to note that this script focuses on non-PHI data to ensure data integrity and availability while complying with privacy regulations.
