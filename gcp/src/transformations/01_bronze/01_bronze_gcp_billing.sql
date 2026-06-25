-- Bronze Layer: Raw GCP Billing Data Ingestion
-- Source: GCS Parquet files via Auto Loader
-- Target: bronze_gcp_billing

CREATE OR REFRESH STREAMING TABLE ${bronze_gcp_billing}
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS SELECT *
FROM STREAM read_files(
  '${source_file_path}',
  format => 'parquet',
  schemaLocation => '${source_file_path}/_schema/'
);
