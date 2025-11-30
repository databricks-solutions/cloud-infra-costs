# AWS Cost

The 'aws_cost' project's purpose is to help enable customers to get TCO of their Databricks implementation including AWS infrastructure costs.  This then allows for using Databricks native tooling to process, vizualize, and augment the cost data with data in Databricks System Tables. The accelerator allows for users to visualize the different types of AWS Cost (Unblended, Net Unblended, Amortized, Net Amortized).

<img width="1698" height="842" alt="image" src="https://github.com/user-attachments/assets/0b8751a3-25fe-4a41-8abe-e69cc95baa26" />


## Key Outcomes:
- AWS cost data including infrastructure, networking, and other costs in addition to Databricks costs.
- Includes any discounts a customer might have given their enterprise agreement with Amazon
- Cost data can be joined to other [system tables](https://docs.databricks.com/aws/en/admin/system-tables/)

## AWS Cost and Usage Reports 2.0 (CUR) Export Setup

_Note: The pipelines need an AWS CUR 2.0 Data Export to work. If you have already an AWS CUR1.0; follow the AWS [documentation](https://docs.aws.amazon.com/cur/latest/userguide/dataexports-migrate.html) to upgrade._

1. You need an Amazon S3 bucket in your AWS account to store your Cost and Usage Reports. When creating an export in the console, you can select an existing S3 bucket that you own, or you can create a new bucket. Configure the S3 bucket according to the AWS [documentation](https://docs.aws.amazon.com/cur/latest/userguide/dataexports-s3-bucket.html), the S3 bucket policy grants access to AWS to deliver your reports.

_Note: The account that creates the export must also own the S3 bucket that AWS sends the exports to. It is recommended to create the Data Export in your AWS payer account; so that the cost of all AWS accounts is included. If your Databricks cost is related to only one AWS account, you can optionally set your Data Export there._

3. Configure a [Standard Export](https://docs.aws.amazon.com/cur/latest/userguide/dataexports-create-standard.html) to deliver the AWS CUR. The following settings should be configured on the export.
   - Type of export: Standard Data Export
   - Include resource IDs (Checked)
   - Time granularity: Hourly
   - For Column selection, select all columns by selecting the first check box at the top of the table
   - Compression type and file format: Parquet
   - File versioning: Overwrite existing data export file

3. Create a Databricks [Credential](https://docs.databricks.com/aws/en/connect/unity-catalog/cloud-storage/#storage-credentials) and [External Location](https://docs.databricks.com/aws/en/connect/unity-catalog/cloud-storage/#overview-of-external-locations) that points to the S3 bucket in the prior step. 

_Note: AWS refreshes the data multiple times a day rewriting the data files for months that had a change; however, historical data older than a few months usually doesn't get updated. Should you require additional historical data, you can raise an AWS support ticket and request a data backfill ._

## DAB Setup

### Required Parameters
1. Configure [DAB Target](https://docs.databricks.com/aws/en/dev-tools/bundles/settings#targets) in [databricks.yml](databricks.yml#l40).  The target will dictate which Databricks workspace the DAB will be deployed in.
2. The DAB has the following parameters in [databricks.yml](databricks.yml#l11).

| Parameter      | Description      | Default Value      |
| ------------- | ------------- | ------------- |
| catalog | Catalog where volume and tables will be configured | `billing` |
| schema | Schema where volume and tables will be configured | `aws` |
| volume_name | Name of volume | `cost_export` |
| bronze_table_name | Name of bronze table | `actual_bronze` |
| silver_table_name | Name of silver table | `actuals_silver` |
| gold_table_name | Name of gold table | `actuals_gold` |
| tracker_table_name | Name of tracking table | `aws_cost_and_usage_tracking` |
| storage_location | Folder within an S3 bucket where AWS is exporting files to | N/A - Must be specified |
| job_alerts_email | Email address to dleievr pipeline failures | N/A - Must be specified |
| warehouse_id | Id of SQL warehouse that the dashboard uses | N/A - Must be specified |

### DAB Deployment

1. Install the Databricks CLI from https://docs.databricks.com/dev-tools/cli/databricks-cli.html

2. Authenticate to your Databricks workspace, if you have not done so already:
    ```
    $ databricks configure
    ```

3. To deploy a development copy of this project, type:
    ```
    $ databricks bundle deploy --target dev
    ```
    (Note that "dev" is the default target, so the `--target` parameter
    is optional here.)

    This deploys everything that's defined for this project.
    For example, the default template would deploy a job called
    `[dev yourname] aws_cost_job` to your workspace.
    You can find that job by opening your workpace and clicking on **Workflows**.

4. Similarly, to deploy a production copy, type:
   ```
   $ databricks bundle deploy --target prod
   ```

   Note that the default job from the template has a schedule that runs every day
   (defined in resources/aws_cost_job.job.yml).

5. To run a job or pipeline, use the "run" command:
   ```
   $ databricks bundle run
   ```
6. Optionally, install developer tools such as the Databricks extension for Visual Studio Code from
   https://docs.databricks.com/dev-tools/vscode-ext.html.

7. For documentation on the Databricks asset bundles format used
   for this project, and for CI/CD configuration, see
   https://docs.databricks.com/dev-tools/bundles/index.html.

### Limitations

   - S3 Storage charges and corrsponding data egress is not included as those resources are not created by Databricks
   - AWS Cost and Usage Reports only include the latest key value pair in resource tags (including Databricks propagated tags like cluster or job IDs). Therefore, when EC2 instances are reused in multiple clusters (e.g. in Databricks pools), the EC2 cost will be reflected on the latest cluster used by that instance.

