# Azure Cost

The 'azure_cost' project's purpose is to help enable customers to get a full TCO of their Azure cost data into Databricks.  This then allows for using Databricks native tooling to process, vizualize, and augment the cost data with data in Databricks System Tables.

## Key Outcomes:
- Vizualize Azure cost data including infrastructure, networking, and other costs in addition to Databricks costs.
- Includes any discounts a customer might have given their enterprise agreement with Microsoft
- Cost data can be joined to other [system tables](https://learn.microsoft.com/en-us/azure/databricks/admin/system-tables/), such as [system.compute.clusters](https://learn.microsoft.com/en-us/azure/databricks/admin/system-tables/compute#cluster-table-schema)

## Billing Export Setup

1. Create a [Storage Account](https://learn.microsoft.com/en-us/azure/storage/common/storage-account-overview) and a [Container](https://learn.microsoft.com/en-us/azure/storage/blobs/blob-containers-portal).  The Container is where the Billing Export logs will be delivered.  Storage Account best practices for using with Azure Databricks can be found [here](https://learn.microsoft.com/en-us/azure/databricks/connect/unity-catalog/cloud-storage/#best-practices-azure).  

2. Create a Databricks [Credential](https://learn.microsoft.com/en-us/azure/databricks/connect/unity-catalog/cloud-storage/storage-credentials) and [External Location](https://learn.microsoft.com/en-us/azure/databricks/connect/unity-catalog/cloud-storage/external-locations) that points to the Container in the prior step. 

3. Configure [Cost Export](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-improved-exports) to deliver daily exports to Container.  The following settings should be configured on the export.
   - Type of data: Cost and usage details (actual)
   - Frequency: Daily
   - Schedule status: Active
   - File partitioning: On
   - Overwrite data: Off
   - Format: Parquet
   - Compression type: Snappy

4. Validate the files are exported to the Container on a daily basis
![Container with Cost Export Data](screenshots/ContainerWithCostExportData.png?raw=true)

## DAB Setup

### Required Parameters
1. Configure [DAB Target](https://learn.microsoft.com/en-us/azure/databricks/dev-tools/bundles/settings#bundle-syntax-mappings-targets) in [databricks.yml](databricks.yml#l40).  The target will dictate which Databricks workspace the DAB will be deployed in.
2. The DAB has the following parameters in [databricks.yml](databricks.yml#l11).

| Parameter      | Description      | Default Value      |
| ------------- | ------------- | ------------- |
| catalog | Catalog where volume and tables will be configured | `billing` |
| schema | Schema where volume and tables will be configured | `azure` |
| volume_name | Name of volume | `cost_export` |
| bronze_table_name | Name of bronze table | `actual_bronze` |
| silver_table_name | Name of silver table | `actuals_silver` |
| gold_table_name | Name of gold table | `actuals_gold` |
| storage_location | Folder within a Storage Account's Container where Cost Export is exporting files to | N/A - Must be specified |
| volume_path | Path where file arrival trigger is listening | `/Volumes/${var.catalog}/${var.schema}/${var.volume_name}/` |
| source_file_path | Location in Volume where AutoLoader is reading Cost Export files from | `${var.volume_path}*/*/*/*/*/*.parquet` |
| billing_period_depth | Pipeline uses split_part to extract billing period (e.g. 20250901-20250930) from file source_file_path | `8` |
| ingestion_date_depth | Pipeline uses split_part to extract ingestion date (e.g. 202509081628) from file source_file_path | `9` |
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
    `[dev yourname] azure_cost_job` to your workspace.
    You can find that job by opening your workpace and clicking on **Workflows**.

4. Similarly, to deploy a production copy, type:
   ```
   $ databricks bundle deploy --target prod
   ```

   Note that the default job from the template has a schedule that runs every day
   (defined in resources/azure_cost_prototype.job.yml). The schedule
   is paused when deploying in development mode (see
   https://docs.databricks.com/dev-tools/bundles/deployment-modes.html).

5. To run a job or pipeline, use the "run" command:
   ```
   $ databricks bundle run
   ```
6. Optionally, install developer tools such as the Databricks extension for Visual Studio Code from
   https://docs.databricks.com/dev-tools/vscode-ext.html.

7. For documentation on the Databricks asset bundles format used
   for this project, and for CI/CD configuration, see
   https://docs.databricks.com/dev-tools/bundles/index.html.
