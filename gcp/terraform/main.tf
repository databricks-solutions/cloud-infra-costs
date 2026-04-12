locals {
  external_location_url = format("gs://%s", var.gcs_bucket_name)
  catalog_location_url  = join("", [local.external_location_url, "/catalog_default/"])
  volume_location_url   = join("", [local.external_location_url, "/export/"])
}

# ---------------------------------------------------------------------------
# GCS Bucket for billing export Parquet files
# ---------------------------------------------------------------------------

resource "google_storage_bucket" "gcp_billing" {
  name                        = var.gcs_bucket_name
  location                    = var.gcp_region
  uniform_bucket_level_access = true
  force_destroy               = false

  lifecycle_rule {
    condition {
      age = 365
    }
    action {
      type = "Delete"
    }
  }
}

# ---------------------------------------------------------------------------
# BigQuery stored procedure: exports billing data to GCS as Parquet
# ---------------------------------------------------------------------------

resource "google_bigquery_routine" "export_billing_to_gcs" {
  dataset_id   = var.bigquery_dataset_id
  routine_id   = "export_billing_to_gcs"
  routine_type = "PROCEDURE"
  language     = "SQL"

  definition_body = <<-SQL
    BEGIN
      DECLARE export_uri STRING;
      DECLARE export_sql STRING;

      SET export_uri = CONCAT(
        'gs://${var.gcs_bucket_name}/export/gcp-detailed-cost/',
        FORMAT_TIMESTAMP('%Y%m%d%H%M%S', CURRENT_TIMESTAMP()),
        '/*.parquet'
      );

      SET export_sql = CONCAT(
        "EXPORT DATA OPTIONS (uri='", export_uri,
        "', format='PARQUET', compression='SNAPPY', overwrite=false) AS ",
        "SELECT * FROM `${var.gcp_project_id}.${var.bigquery_dataset_id}.${var.bigquery_billing_table}` ",
        "WHERE invoice.month >= FORMAT_DATE('%Y%m', DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 MONTH))"
      );

      EXECUTE IMMEDIATE export_sql;
    END
  SQL
}

# ---------------------------------------------------------------------------
# BigQuery scheduled query: runs the export procedure daily
# ---------------------------------------------------------------------------

resource "google_bigquery_data_transfer_config" "daily_export" {
  display_name   = "gcp-billing-to-gcs-daily"
  data_source_id = "scheduled_query"
  location       = var.gcp_region
  schedule       = "every 24 hours"

  params = {
    query = "CALL `${var.gcp_project_id}.${var.bigquery_dataset_id}.export_billing_to_gcs`();"
  }

  depends_on = [google_bigquery_routine.export_billing_to_gcs]
}

# ---------------------------------------------------------------------------
# IAM: Grant the BigQuery Data Transfer service agent write access to GCS
# ---------------------------------------------------------------------------

data "google_project" "project" {}

resource "google_storage_bucket_iam_member" "bq_export_writer" {
  bucket = google_storage_bucket.gcp_billing.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-bigquerydatatransfer.iam.gserviceaccount.com"
}

# ---------------------------------------------------------------------------
# Databricks Storage Credential (uses Databricks-managed GCP service account)
# ---------------------------------------------------------------------------

resource "databricks_storage_credential" "gcp_sa" {
  name = "gcp_billing_credential"

  databricks_gcp_service_account {}
}

# Grant the Databricks-managed service account read access to GCS
resource "google_storage_bucket_iam_member" "databricks_reader" {
  bucket = google_storage_bucket.gcp_billing.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${databricks_storage_credential.gcp_sa.databricks_gcp_service_account[0].email}"
}

# ---------------------------------------------------------------------------
# Databricks External Location, Catalog, Schema, Volume
# ---------------------------------------------------------------------------

resource "databricks_external_location" "gcp_billing_external_location" {
  name            = "gcp_billing_external_location"
  url             = local.external_location_url
  credential_name = databricks_storage_credential.gcp_sa.id

  depends_on = [google_storage_bucket.gcp_billing]
}

resource "databricks_catalog" "billing_catalog" {
  name         = var.catalog_name
  storage_root = local.catalog_location_url
}

resource "databricks_schema" "billing_schema" {
  catalog_name = databricks_catalog.billing_catalog.name
  name         = var.schema_name
}

resource "databricks_volume" "cost_export" {
  name             = "cost_export"
  catalog_name     = databricks_catalog.billing_catalog.name
  schema_name      = databricks_schema.billing_schema.name
  volume_type      = "EXTERNAL"
  storage_location = local.volume_location_url
}
