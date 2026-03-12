# Azure Cost

The 'azure_cost' project's purpose is to help enable customers to get a full TCO of their Azure cost data into Databricks.  This then allows for using Databricks native tooling to process, visualize, and augment the cost data with data in Databricks System Tables.

<img width="1444" height="653" alt="Screenshot 2025-11-05 at 10 58 37 AM" src="https://github.com/user-attachments/assets/611b8cf5-cf23-4c98-84a9-eab3776669fe" />

## Key Outcomes:
- Visualize Azure cost data including infrastructure, networking, and other costs in addition to Databricks costs.
- Includes any discounts a customer might have given their enterprise agreement with Microsoft.
- Cost data can be joined to other [system tables](https://learn.microsoft.com/en-us/azure/databricks/admin/system-tables/), such as [system.compute.clusters](https://learn.microsoft.com/en-us/azure/databricks/admin/system-tables/compute#cluster-table-schema), [system.compute.warehouses](https://learn.microsoft.com/en-us/azure/databricks/admin/system-tables/compute#warehouse-table-schema), and [system.lakeflow.jobs](https://learn.microsoft.com/en-us/azure/databricks/admin/system-tables/lakeflow-jobs) for TCO analysis by cluster, warehouse, or job.
- Supports three Azure Cost Export formats: **Actuals**, **Amortized**, and **FOCUS** (FinOps Open Cost and Usage Specification).
- Includes an AI/BI Genie space for natural language cost exploration, including TCO by job/cluster/warehouse, serverless vs classic cost comparison, and top-N cost analysis.

## Solution Architecture

The solution consists of the following components:

| Component | Description |
| --------- | ----------- |
| **Actuals Pipeline** (`azure_cost_pipeline`) | Streaming Declarative Pipeline (SDP) that ingests Azure Actuals cost export data through a bronze/silver/gold medallion architecture. |
| **Amortized Pipeline** (`azure_amortized_pipeline`) | Optional SDP for Amortized cost data. Same schema as actuals but with reservation costs spread across the usage period. Paused by default. |
| **FOCUS Pipeline** (`azure_focus_pipeline`) | Optional SDP for FOCUS-format cost data. Uses standardized FinOps column names (BilledCost, EffectiveCost, ServiceName, etc.). Paused by default. |
| **Azure Cost Dashboard** | Lakeview dashboard with a global Cost Type filter to toggle between Actuals and Amortized views. Includes pages for cost overview, compute TCO (joined to system tables), and cost-by-tags analysis. |
| **Azure FOCUS Cost Dashboard** | Separate Lakeview dashboard for FOCUS-format data with cost overview and resource analysis pages. |
| **File Arrival Jobs** | Each pipeline has a dedicated file arrival trigger job that monitors its respective export directory in the volume. Amortized and FOCUS jobs are paused by default. |
| **Genie Space** | AI/BI Genie space (manual import) for natural language cost exploration across all three formats. Supports TCO by job, cluster, or warehouse, serverless vs classic comparison, and top-N analysis. |

### Data Flow

```
Azure Cost Export (Storage Account)
  ├── azure-actual-cost/       → Actuals SDP Pipeline   → actuals_bronze → actuals_silver → actuals_gold
  ├── azure-amortized-cost/    → Amortized SDP Pipeline → amortized_bronze → amortized_silver → amortized_gold
  └── azure-focus-cost/        → FOCUS SDP Pipeline     → focus_bronze → focus_silver → focus_gold
                                                                                              │
                                                              Dashboards & Genie Space ◄──────┘
```

Each pipeline follows the medallion architecture:
- **Bronze**: Raw ingestion via AutoLoader (`read_files`) with source file metadata.
- **Silver**: Parsed dates, extracted billing period and ingestion date from file paths, and parsed JSON tags into a VARIANT column.
- **Gold**: Deduplicated by billing period (keeps latest ingestion date using `RANK()` window function), pre-calculated price column, and vendor tag extraction.

## Deployment Steps
### Deploy Terraform to configure dependent components
Terraform is used to simplify the initial setup of dependent components that are required for this solution to work - storage account, container, external location, catalog, schema, and volume.  [Terraform](https://developer.hashicorp.com/terraform) is an open-source, infrastructure as code (IaC) tool that allows you to define and provision infrastructure in human-readable configuration files.  For additional information on Terraform best practices with Databricks, please refer to the following [documentation](https://learn.microsoft.com/en-us/azure/databricks/dev-tools/terraform/).

The Terraform requires a pre-existing Azure Subscription Id, Databricks Workspace URL, and Resource Group.  Navigate to the [Terraform subfolder](terraform/) within the Azure solution via the command line.   Within the [terraform.tfvars file](terraform/terraform.tfvars), configure the following parameters:

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

Once configured, the Terraform is deployed with the following steps.  First, one needs to login and ensure they are using the appropriate credentials when executing the Terraform.  After executing az login, select the subscription that was configured in the above variable file.

`az login`

Initializes a working directory containing Terraform configuration files.

`terraform init`

Shows a preview of the changes Terraform will make to your infrastructure before those changes are actually applied.

`terraform plan -var-file="terraform.tfvars"`

Executes the changes proposed in a Terraform plan, provisioning or modifying infrastructure resources in the target cloud or infrastructure provider.

`terraform apply -var-file="terraform.tfvars"`

Upon successful completion, a message indicating "Apply complete!" is displayed in the terminal.  The Terraform has deployed a [Storage Account](https://learn.microsoft.com/en-us/azure/storage/common/storage-account-overview), [Container](https://learn.microsoft.com/en-us/azure/storage/blobs/blob-containers-portal), [External Location](https://learn.microsoft.com/en-us/azure/databricks/connect/unity-catalog/cloud-storage/external-locations), Catalog, Schema, and Volume.  These resources are the location where the Azure billing data is exported to.

### Configure Billing Export Setup into a Storage Account
Start by accessing the [Azure portal](https://portal.azure.com/) and signing in using your Azure account credentials.  On the left-hand side, click All services and search for Cost Exports.  Click create to create a new [Cost Export](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-improved-exports).

The Azure Cost Export functionality supports three dataset types. Create one or more exports depending on your needs:

| Export Type | Description | Export Directory Name |
| ----------- | ----------- | -------------------- |
| **Actuals** (required) | Actual billed costs as invoiced by Azure | `azure-actual-cost` |
| **Amortized** (optional) | Costs with reservation/commitment purchases spread across the usage period | `azure-amortized-cost` |
| **FOCUS** (optional) | FinOps FOCUS standard format with standardized column names | `azure-focus-cost` |

For each export, configure the following settings and set it to deliver the exports to the Storage Account and Container created in the prior step:
   - Frequency: Daily
   - Schedule status: Active
   - File partitioning: On
   - Overwrite data: Off
   - Format: Parquet
   - Compression type: Snappy

> **Important**: Each export type should be configured with a distinct export name (e.g., `azure-actual-cost`, `azure-amortized-cost`, `azure-focus-cost`). These names become directory names in the storage container, and the solution's pipelines are configured to read from these specific paths.

![Cost Export Setup](screenshots/AzureCostExport.gif?raw=true)

Next, validate the files are exported to the Container as those contain the Azure cost data we need (Databricks and infra costs).  On the left-hand side, click All services and search for Storage Accounts.  Select the Storage Account created in the previous step and navigate to the Container that was also created during the previous step.

![Storage Account Navigation](screenshots/AzureStorageAccountNavigation.png?raw=true)

Once inside the Container, the folder and pathing structure should look something like the following and it should also include parquet files containing the cost data.

![Container with Cost Export Data](screenshots/AzureCostExportFiles.png?raw=true)

The expected directory structure within the container is:
```
<container>/
  ├── azure-actual-cost/<billing-period>/<ingestion-date>/<run-id>/*.parquet
  ├── azure-amortized-cost/<billing-period>/<ingestion-date>/<run-id>/*.parquet   (optional)
  └── azure-focus-cost/<billing-period>/<ingestion-date>/<run-id>/*.parquet       (optional)
```

### Databricks Asset Bundle (DAB) Configuration to deploy jobs, pipelines, and dashboards
With cost files successfully exported on a daily basis to the configured Storage Account, it is now possible to deploy the rest of the solution within Databricks.  To facilitate this step, Databricks Asset Bundles (DABs) are used to streamline the configuration and deployment process.  For more information on DABs, please check out the following [documentation](https://learn.microsoft.com/en-us/azure/databricks/dev-tools/bundles/).

First, DAB needs to be configured so that it deploys to the correct Databricks workspace.  This is done within the [databricks.yml](databricks.yml) file.  To configure the desired [target](https://learn.microsoft.com/en-us/azure/databricks/dev-tools/bundles/settings#bundle-syntax-mappings-targets), use the same workspace URL as was used in the Terraform deployment.  Optionally, one can change the name of the target.  For this example, the target is named "dev".  Additionally, one variable, `warehouse_id`, will need to be configured.  The other variables can be left as the default values presuming the name of the Catalog, Schema, Volume Name are the same as the Terraform.

#### Actuals Pipeline Variables

| Parameter      | Description      | Default Value      |
| ------------- | ------------- | ------------- |
| catalog | Catalog where volume and tables will be configured | `billing` |
| schema | Schema where volume and tables will be configured | `azure` |
| volume_name | Name of volume | `cost_export` |
| bronze_table_name | Name of bronze table | `actuals_bronze` |
| silver_table_name | Name of silver table | `actuals_silver` |
| gold_table_name | Name of gold table | `actuals_gold` |
| volume_path | Path where file arrival trigger is listening | `/Volumes/${var.catalog}/${var.schema}/${var.volume_name}/` |
| source_file_path | Location in Volume where AutoLoader is reading Cost Export files from | `${var.volume_path}azure-actual-cost/*/*/*/*.parquet` |
| billing_period_depth | Pipeline uses split_part to extract billing period (e.g. 20250901-20250930) from file source_file_path | `7` |
| ingestion_date_depth | Pipeline uses split_part to extract ingestion date (e.g. 202509081628) from file source_file_path | `8` |
| warehouse_id | Id of SQL warehouse that the dashboard uses | N/A - Must be specified |

#### Amortized Pipeline Variables (Optional)

| Parameter      | Description      | Default Value      |
| ------------- | ------------- | ------------- |
| amortized_bronze_table_name | Name of amortized bronze table | `amortized_bronze` |
| amortized_silver_table_name | Name of amortized silver table | `amortized_silver` |
| amortized_gold_table_name | Name of amortized gold table | `amortized_gold` |
| amortized_source_file_path | Location in Volume where AutoLoader is reading Amortized Cost Export files from | `${var.volume_path}azure-amortized-cost/*/*/*/*.parquet` |
| amortized_billing_period_depth | split_part depth for billing period in amortized file paths | `7` |
| amortized_ingestion_date_depth | split_part depth for ingestion date in amortized file paths | `8` |

#### FOCUS Pipeline Variables (Optional)

| Parameter      | Description      | Default Value      |
| ------------- | ------------- | ------------- |
| focus_bronze_table_name | Name of FOCUS bronze table | `focus_bronze` |
| focus_silver_table_name | Name of FOCUS silver table | `focus_silver` |
| focus_gold_table_name | Name of FOCUS gold table | `focus_gold` |
| focus_source_file_path | Location in Volume where AutoLoader is reading FOCUS Cost Export files from | `${var.volume_path}azure-focus-cost/*/*/*/*.parquet` |
| focus_billing_period_depth | split_part depth for billing period in FOCUS file paths | `7` |
| focus_ingestion_date_depth | split_part depth for ingestion date in FOCUS file paths | `8` |

Authenticate to your Databricks workspace, if you have not done so already.  For additional documentation, please refer to the following [page](https://learn.microsoft.com/en-us/azure/databricks/dev-tools/cli/authentication#m2m-auth).

`databricks auth login --host <workspace-url> --profile cloud-infra-cost`

To deploy the DAB, execute the following command:

`databricks bundle deploy --target dev --profile cloud-infra-cost`

### View Dashboards and validate Lakeflow Jobs

#### Azure Cost Dashboard (Actuals & Amortized)
Navigate to the dashboard created and validate that data appears. The dashboard includes a global **Cost Type** filter that lets you toggle between Actuals and Amortized views (defaults to Actuals).

![Dashboard Screenshot](screenshots/AzureDashboardScreenshot.png?raw=true)

The dashboard includes the following pages:
- **Cost Overview** - Daily cost trends by service category, cost by subscription and resource group
- **Compute TCO** - Total cost of ownership for Databricks clusters and SQL warehouses, joined to `system.compute.clusters` and `system.compute.warehouses`
- **Cost by Tags** - Cost analysis by Azure resource tags with configurable time granularity

#### Azure FOCUS Cost Dashboard
If the FOCUS pipeline is enabled, a separate dashboard is deployed for FOCUS-format data with:
- **Cost Overview** - Cost trends by ServiceCategory, breakdown by SubAccountName, ChargeCategory, and RegionName
- **Resource Analysis** - Detailed resource-level cost analysis with cross-filtering

#### File Arrival Jobs
Navigate to the jobs page and confirm that the job(s) are executing successfully.

![Jobs Page](screenshots/AzureJobsPage.png?raw=true)

Each pipeline has its own file arrival trigger job:
- `azure_cost_job` - Monitors `azure-actual-cost/` directory (active by default)
- `azure_amortized_job` - Monitors `azure-amortized-cost/` directory (paused by default)
- `azure_focus_job` - Monitors `azure-focus-cost/` directory (paused by default)

By default, the Job's File Arrival Trigger is disabled as the DAB is configured to be deployed with [Development Mode](https://learn.microsoft.com/en-us/azure/databricks/dev-tools/bundles/deployment-modes#development-mode) enabled.  To enable the File Arrival Trigger for production use, set [Development Mode](https://github.com/databricks-solutions/cloud-infra-costs/blob/main/azure/databricks.yml#L46) to "production".  To enable the amortized or FOCUS jobs, remove the `pause_status: PAUSED` from their respective job YAMLs in the `resources/` directory.

### (Optional) - Import Genie Space
An AI/BI Genie space JSON file is included in the repository (`Azure_cost_reporting_genie_space_azure_billing.json`) for natural language cost exploration.  To import it, use the [Genie Spaces API](https://learn.microsoft.com/en-us/azure/databricks/genie/genie-api):

```bash
databricks api post /api/2.0/genie/spaces --profile cloud-infra-cost --json @Azure_cost_reporting_genie_space_azure_billing.json
```

> **Note**: You may need to add a `"warehouse_id"` field to the JSON before importing if one is not already present.

The Genie space supports:
- Cost queries across all three formats (Actuals, Amortized, FOCUS)
- TCO analysis by Databricks job, cluster, or SQL warehouse (joined to system tables)
- Serverless vs classic SQL warehouse cost comparison
- Top-N most expensive resources across clusters, warehouses, and jobs
- Cost breakdown by Databricks workload type (SQL, ALL_PURPOSE, SDP, etc.)
- Cost forecasting using `AI_FORECAST`

### (Optional) - Perform additional Job and Dashboard configurations
The dashboards and pipelines created as part of this solution provide an excellent, quick way to get started; however, there are near infinite customizations that can be done based on individual business needs that will require further customization, such as:
- Joining to additional System Tables (e.g., `system.billing.usage` for DBU-level details)
- Modeling out reservation costs differently
- Adding additional cost export formats or custom tag-based analysis
- Customizing the Genie space with domain-specific instructions or example queries
