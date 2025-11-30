# Azure Cost

The 'azure_cost' project's purpose is to help enable customers to get a full TCO of their Azure cost data into Databricks.  This then allows for using Databricks native tooling to process, vizualize, and augment the cost data with data in Databricks System Tables.

<img width="1444" height="653" alt="Screenshot 2025-11-05 at 10 58 37 AM" src="https://github.com/user-attachments/assets/611b8cf5-cf23-4c98-84a9-eab3776669fe" />

## Key Outcomes:
- Vizualize Azure cost data including infrastructure, networking, and other costs in addition to Databricks costs.
- Includes any discounts a customer might have given their enterprise agreement with Microsoft
- Cost data can be joined to other [system tables](https://learn.microsoft.com/en-us/azure/databricks/admin/system-tables/), such as [system.compute.clusters](https://learn.microsoft.com/en-us/azure/databricks/admin/system-tables/compute#cluster-table-schema)

## Deployment Steps

1. Deploy Terraform to configure a [Storage Account](https://learn.microsoft.com/en-us/azure/storage/common/storage-account-overview), [Container](https://learn.microsoft.com/en-us/azure/storage/blobs/blob-containers-portal), [External Location](https://learn.microsoft.com/en-us/azure/databricks/connect/unity-catalog/cloud-storage/external-locations), Catalog, Schema, and Volume.

   - Navigate to the [Terraform subfolder](terraform/) within the Azure solution via the command line.  Within the [terraform.tfvars](terraform/terraform.tfvars) file, configure the following parameters:
   ```
   subscription_id = "<Azure Subscription Id>"
   databricks_host = "<Workspace Url>"
   resource_group_name = "<Resource Group Name>"
   location = "<Azure Region>"
   storage_account_name = "<Globally Unique Name>"
   container_name = "billing"
   catalog_name = "billing"
   schema_name = "azure"
   ```

   - Once configured, the Terraform is deployed with the following steps:
   ```
   #First, one needs to login and ensure they are using the appropriate credentials when executing the Terraform.  After executing az login, select the subscription that was configured in the above variable file.
   az login

   #Initializes a working directory containing Terraform configuration files.
   terraform init

   #Shows a preview of the changes Terraform will make to your infrastructure before those changes are actually applied.
   terraform plan -var-file="terraform.tfvars"

   #Executes the changes proposed in a Terraform plan, provisioning or modifying infrastructure resources in the target cloud or infrastructure provider. 
   terraform apply -var-file="terraform.tfvars"
   ```
   Upon successful completion, a message indicating “Apply complete!” is displayed in the terminal.

2. Configure [Cost Export](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-improved-exports) to deliver daily exports to Container.  The following settings should be configured on the export.
   - Type of data: Cost and usage details (actual)
   - Frequency: Daily
   - Schedule status: Active
   - File partitioning: On
   - Overwrite data: Off
   - Format: Parquet
   - Compression type: Snappy

3. Validate the files are exported to the Container on a daily basis
![Container with Cost Export Data](screenshots/AzureCostExportFiles.png?raw=true)

4. Configure [DAB Target](https://learn.microsoft.com/en-us/azure/databricks/dev-tools/bundles/settings#bundle-syntax-mappings-targets) in [databricks.yml](databricks.yml#l44).  The target should be the same workspace used in step 1.

5. The DAB has the following parameters in [databricks.yml](databricks.yml#l11); however, it is important to ensure the parameters for the DAB and previously the Terraform setup are consistent (e.g. which catalog and schema to use).  The only parameter that needs to be configured in the DAB outside of the target is the warehouse_id.

| Parameter      | Description      | Default Value      |
| ------------- | ------------- | ------------- |
| catalog | Catalog where volume and tables will be configured | `billing` |
| schema | Schema where volume and tables will be configured | `azure` |
| volume_name | Name of volume | `cost_export` |
| bronze_table_name | Name of bronze table | `actual_bronze` |
| silver_table_name | Name of silver table | `actuals_silver` |
| gold_table_name | Name of gold table | `actuals_gold` |
| volume_path | Path where file arrival trigger is listening | `/Volumes/${var.catalog}/${var.schema}/${var.volume_name}/` |
| source_file_path | Location in Volume where AutoLoader is reading Cost Export files from | `${var.volume_path}*/*/*/*/*.parquet` |
| billing_period_depth | Pipeline uses split_part to extract billing period (e.g. 20250901-20250930) from file source_file_path | `7` |
| ingestion_date_depth | Pipeline uses split_part to extract ingestion date (e.g. 202509081628) from file source_file_path | `8` |
| warehouse_id | Id of SQL warehouse that the dashboard uses | N/A - Must be specified |