# Database Transfer Statistics

The purpose of this README file is to provide customers with an understanding of the estimated time it may take to backup and transfer a database to one of our S3 buckets using SFTP (Secure File Transfer Protocol). Please note that the provided times are approximations and may vary based on various factors.

## Small Database (up to a few gigabytes)

- **Backup time**: Approximately 12-24 hours, assuming an average backup speed of 10MB/s.
- **SFTP transfer time**: Approximately 12-24 hours, assuming an average upload speed of 10MB/s.
- **Example AWS instance types**: t2.small (1 vCPU, 2 GB RAM), t2.medium (2 vCPUs, 4 GB RAM)

## Medium Database (up to tens of gigabytes)

- **Backup time**: Approximately 6-12 hours, assuming an average backup speed of 20MB/s.
- **SFTP transfer time**: Approximately 6-12 hours, assuming an average upload speed of 10MB/s.
- **Example AWS instance types**: m5.large (2 vCPUs, 8 GB RAM), m5.xlarge (4 vCPUs, 16 GB RAM)

## Large Database (hundreds of gigabytes or more)

- **Backup time**: Approximately 2-4 days, assuming an average backup speed of 30MB/s.
- **SFTP transfer time**: Approximately 2-4 days, assuming an average upload speed of 10MB/s.
- **Example AWS instance types**: i3.2xlarge (8 vCPUs, 61 GB RAM), i3.4xlarge (16 vCPUs, 122 GB RAM)

Please keep in mind that the backup speed and backup time are directly proportional. Therefore, if the backup speed doubles, the backup time should be reduced by half, assuming all other factors remain constant. For example, if it takes 12 hours to backup a database with an average backup speed of 10MB/s, it should take around 6 hours to backup the same database with an average backup speed of 20MB/s.

However, it's important to note that various factors can impact the actual backup time, such as the complexity of the database queries, disk speed, and processing time. Additionally, the backup process may be affected by network latency or congestion if the backup is being sent over a network, rather than being written locally.

We hope this information provides you with a better understanding of the estimated time it may take to backup and transfer your database. If you have any further questions or concerns, please don't hesitate to reach out to our support team.
