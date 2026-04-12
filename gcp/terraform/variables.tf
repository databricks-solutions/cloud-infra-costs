variable "gcp_project_id" {
  type        = string
  description = "GCP project ID where resources will be created"
}

variable "gcp_region" {
  type        = string
  description = "GCP region for resource deployment"
}

variable "databricks_host" {
  type        = string
  description = "Databricks workspace URL"
}

variable "gcs_bucket_name" {
  type        = string
  description = "Name of the GCS bucket for billing export Parquet files"
}

variable "bigquery_dataset_id" {
  type        = string
  description = "BigQuery dataset ID where GCP billing export is configured"
}

variable "bigquery_billing_table" {
  type        = string
  description = "BigQuery billing export table name (e.g. gcp_billing_export_resource_v1_XXXXXX_XXXXXX)"
}

variable "catalog_name" {
  type        = string
  description = "Databricks Unity Catalog name"
}

variable "schema_name" {
  type        = string
  description = "Databricks schema name within the catalog"
}
