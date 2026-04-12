# GCP Cost

The 'gcp_cost' project's purpose is to help enable customers to get a full TCO of their GCP cost data into Databricks. This then allows for using Databricks native tooling to process, visualize, and augment the cost data with data in Databricks System Tables.

## Key Outcomes:
- Visualize GCP cost data including Compute Engine, networking, storage, and other GCP service costs in addition to Databricks costs.
- Includes any credits or committed use discounts (CUDs) applied to the billing account.
- Cost data can be joined to [system tables](https://docs.databricks.com/en/admin/system-tables/), such as [system.compute.clusters](https://docs.databricks.com/en/admin/system-tables/compute.html) and [system.lakeflow.jobs](https://docs.databricks.com/en/admin/system-tables/lakeflow-jobs.html), for TCO analysis by cluster or job.
- Uses the GCP Detailed Usage Cost export format for resource-level visibility.
- GCP resource labels (including Databricks-applied tags like `clusterid`, `jobid`, `vendor`) are extracted for cost attribution.

> **Note on SQL Warehouses:** GCP SQL warehouses are serverless and do not generate GCE billing line items with Databricks tags. Warehouse compute costs are tracked exclusively through `system.billing.usage`, not through GCP infrastructure billing.

## Solution Architecture

The solution consists of the following components:

| Component | Description |
| --------- | ----------- |
| **GCP Cost Pipeline** (`gcp_cost_pipeline`) | Streaming Declarative Pipeline (SDP) that ingests GCP Detailed Usage Cost export data through a bronze/silver/gold medallion architecture. |
| **GCP Cost Dashboard** | Lakeview dashboard with pages for cost overview, compute TCO (joined to system tables), cost by labels, and service/SKU breakdown. |
| **File Arrival Job** | File arrival trigger job that monitors the GCS-backed volume for new Parquet exports from BigQuery. |

### Data Flow

```
GCP Billing Account
  │
  ▼
BigQuery (Detailed Usage Cost Export)       ← Configured in GCP Billing Console
  │
  ▼
BigQuery Scheduled Query (daily)            ← Exports last 2 months as Parquet to GCS
  │
  ▼
GCS Bucket (/export/gcp-detailed-cost/YYYYMMDDHHMMSS/*.parquet)
  │
  ▼
Databricks Volume (External)                ← File Arrival Trigger detects new files
  │
  ▼
GCP Cost SDP Pipeline                       → gcp_cost_bronze → gcp_cost_silver → gcp_cost_gold
                                                                                        │
                                                            Dashboard & System Tables ◄──┘
```

Each pipeline follows the medallion architecture:
- **Bronze**: Raw ingestion via AutoLoader (`read_files`) with source file metadata.
- **Silver**: Flattened GCP nested structs (service, SKU, project, location, usage, price), extracted billing period from `invoice.month`, extracted Databricks resource labels from the `labels` array, and aggregated credits.
- **Gold**: Deduplicated by billing period (keeps latest export using `RANK()` window function), pre-calculated `net_cost` column (`cost + credits_total`), and Databricks label extraction.

### Key Architectural Differences from Azure

| Aspect | Azure | GCP |
| ------ | ----- | --- |
| **Billing period source** | Extracted from file path | From `invoice.month` column in data |
| **Tag format** | JSON string (`try_parse_json(tags)`) | `ARRAY<STRUCT<key,value>>` (`FILTER(labels, ...)`) |
| **Data source** | Azure Cost Export → Storage Account (direct) | GCP Billing → BigQuery → GCS (requires export step) |
| **Cost calculation** | `quantity * unitPrice` | `cost + credits_total` (net cost) |
| **Warehouse TCO** | Supported via `parsedTags:SqlEndpointId` | Not available (serverless, no GCE tags) |

## Deployment Steps

### Prerequisites
- A GCP project with billing enabled
- [GCP Billing Export to BigQuery](https://cloud.google.com/billing/docs/how-to/export-data-bigquery) configured for **Detailed Usage Cost** data
- A Databricks workspace on GCP
- [Terraform](https://developer.hashicorp.com/terraform) installed
- [Databricks CLI](https://docs.databricks.com/en/dev-tools/cli/install.html) installed

### 1. Configure GCP Billing Export to BigQuery

If not already configured, enable Cloud Billing export to BigQuery in the [GCP Console](https://console.cloud.google.com/billing/export):

1. Navigate to **Billing** → **Billing export**
2. Under **Detailed usage cost**, click **Edit Settings**
3. Select your project and create or select a BigQuery dataset
4. Click **Save**

Note the **project ID**, **dataset ID**, and **table name** (e.g., `gcp_billing_export_resource_v1_XXXXXX_XXXXXX`) — these are needed for Terraform configuration.

> Data may take up to 24 hours to begin appearing in BigQuery after initial setup.

### 2. Deploy Terraform

Terraform is used to create the GCS bucket for Parquet staging, the BigQuery scheduled export, and the Databricks resources (external location, catalog, schema, volume). Navigate to the [Terraform subfolder](terraform/) and configure the [terraform.tfvars file](terraform/terraform.tfvars):

```
gcp_project_id         = "<GCP Project Id>"
gcp_region             = "<GCP Region>"
databricks_host        = "<Workspace Url>"
gcs_bucket_name        = "<Globally Unique Bucket Name>"
bigquery_dataset_id    = "<BigQuery Dataset Id>"
bigquery_billing_table = "<BigQuery Billing Table Name>"
catalog_name           = "billing"
schema_name            = "gcp"
```

Authenticate to GCP and deploy:

```bash
gcloud auth application-default login
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

Upon successful completion, Terraform has deployed:
- A [GCS bucket](https://cloud.google.com/storage/docs/buckets) for Parquet billing exports
- A [BigQuery stored procedure](https://cloud.google.com/bigquery/docs/procedures) that exports billing data to GCS as Parquet
- A [BigQuery scheduled query](https://cloud.google.com/bigquery/docs/scheduling-queries) that runs the export daily
- IAM bindings for BigQuery → GCS export and Databricks → GCS read access
- A Databricks [External Location](https://docs.databricks.com/en/connect/unity-catalog/cloud-storage/external-locations.html), Catalog, Schema, and Volume

### 3. Validate BigQuery → GCS Export

Trigger the scheduled query manually for the first run to populate initial data:

```bash
# Run the stored procedure directly in BigQuery
bq query --use_legacy_sql=false 'CALL `<project>.<dataset>.export_billing_to_gcs`();'
```

Verify that Parquet files appear in GCS:

```bash
gsutil ls gs://<bucket>/export/gcp-detailed-cost/
```

The expected directory structure is:
```
gs://<bucket>/export/gcp-detailed-cost/
  └── YYYYMMDDHHMMSS/          ← One directory per export run
      ├── 000000000000.parquet
      ├── 000000000001.parquet
      └── ...
```

### 4. Deploy Databricks Asset Bundle (DAB)

With cost files in GCS, deploy the Databricks pipelines, jobs, and dashboard using [Databricks Asset Bundles](https://docs.databricks.com/en/dev-tools/bundles/).

Configure the [databricks.yml](databricks.yml) file. The `warehouse_id` variable must be set to a SQL warehouse in your workspace. Other variables can be left at defaults if the Terraform catalog/schema/volume names match.

#### Pipeline Variables

| Parameter | Description | Default Value |
| --------- | ----------- | ------------- |
| catalog | Catalog where volume and tables will be configured | `billing` |
| schema | Schema where volume and tables will be configured | `gcp` |
| volume_name | Name of volume | `cost_export` |
| bronze_table_name | Name of bronze table | `gcp_cost_bronze` |
| silver_table_name | Name of silver table | `gcp_cost_silver` |
| gold_table_name | Name of gold table | `gcp_cost_gold` |
| volume_path | Path where file arrival trigger is listening | `/Volumes/${var.catalog}/${var.schema}/${var.volume_name}/` |
| source_file_path | Location in Volume where AutoLoader reads GCP billing files | `${var.volume_path}gcp-detailed-cost/*/*.parquet` |
| ingestion_date_depth | split_part depth to extract export timestamp from file path | `6` |
| warehouse_id | Id of SQL warehouse that the dashboard uses | N/A - Must be specified |

> **Note**: Unlike Azure, there is no `billing_period_depth` variable. GCP's billing period is read from the `invoice.month` column in the data, not from the file path.

Authenticate and deploy:

```bash
databricks auth login --host <workspace-url> --profile cloud-infra-cost
databricks bundle deploy --target dev --profile cloud-infra-cost
```

### 5. View Dashboard and Validate Pipeline

Navigate to the dashboard and validate that data appears. The dashboard includes the following pages:

- **Cost Overview** — Daily cost trends by GCP service, cost by project and region, total cost/credits/net cost scorecards
- **Compute TCO** — Cost by Databricks cluster and job, joined to `system.compute.clusters` and `system.lakeflow.jobs`
- **Cost by Labels** — Cost analysis by any GCP resource label with configurable time granularity
- **Service & SKU Breakdown** — Detailed cost breakdown by GCP service and SKU

#### File Arrival Job

Navigate to the jobs page and confirm that the job is executing successfully. The `gcp_cost_job` monitors the `gcp-detailed-cost/` directory in the volume.

By default, the Job's File Arrival Trigger is disabled as the DAB is configured with [Development Mode](https://docs.databricks.com/en/dev-tools/bundles/deployment-modes.html#development-mode) enabled. To enable the File Arrival Trigger for production use, set the mode to `production` in the `databricks.yml` targets section.

## Known Limitations

- **No SQL Warehouse TCO**: GCP SQL warehouses are serverless and do not generate GCE billing line items tagged with Databricks labels. Warehouse costs are only visible in `system.billing.usage`.
- **Export lag**: There is a 1-24 hour lag between incurring costs and data appearing in the dashboard, depending on the BigQuery scheduled query frequency and GCP billing export latency.
- **Credits sign convention**: GCP credits are negative amounts. `net_cost = cost + credits_total` where `credits_total <= 0`, so `net_cost <= cost`.
- **GCP label formatting**: All GCP labels are lowercase per GCE requirements. The `@` symbol in email addresses is replaced with `_at_` (e.g., `user_at_company.com`).
- **`labels` vs `project.labels`**: The pipeline extracts Databricks tags from `labels` (resource-level labels on GCE instances), not `project.labels` (project-level labels).

## Alternative Ingestion: Lakeflow Connect

This solution uses a BigQuery scheduled query to export billing data to GCS as Parquet files for AutoLoader-based ingestion. An alternative approach is to use [Lakeflow Connect](https://docs.databricks.com/en/lakeflow-connect/index.html) to ingest data directly from BigQuery into Delta tables, eliminating the GCS staging step. This may be a simpler option depending on your environment and Lakeflow Connect availability.

## Further Customizations

The dashboards and pipelines created as part of this solution provide a quick way to get started; however, there are many customizations possible based on individual business needs:
- Joining to additional System Tables (e.g., `system.billing.usage` for DBU-level details)
- Adding FOCUS (FinOps Open Cost and Usage Specification) mapping as a gold-layer transform
- CUD (Committed Use Discount) analysis using the CUD metadata export
- Custom label-based cost allocation and chargeback
- Natural language cost exploration via an AI/BI Genie space
