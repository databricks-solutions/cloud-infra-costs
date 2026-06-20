-- Silver Layer: Databricks Usage with List Prices
-- Source: system.billing.usage, system.billing.list_prices
-- Target: silver_databricks_usage

CREATE OR REFRESH MATERIALIZED VIEW ${silver_databricks_usage}
AS
WITH base AS (SELECT
  u.record_id,
  u.account_id,
  u.workspace_id,
  u.sku_name,
  u.usage_date,
  DATE_TRUNC('hour', u.usage_start_time) AS usage_hour,
  u.usage_quantity AS dbu_quantity,
  u.usage_unit,
  -- Resource attribution
  u.usage_metadata.cluster_id AS cluster_id,
  u.usage_metadata.job_id AS job_id,
  u.usage_metadata.job_name AS job_name,
  u.usage_metadata.job_run_id AS job_run_id,
  u.usage_metadata.warehouse_id AS warehouse_id,
  u.usage_metadata.instance_pool_id AS instance_pool_id,
  u.usage_metadata.node_type AS node_type,
  u.usage_metadata.notebook_id AS notebook_id,
  u.usage_metadata.dlt_pipeline_id AS dlt_pipeline_id,
  u.usage_metadata.endpoint_name AS endpoint_name,
  -- Identity
  u.identity_metadata.run_as AS run_as_user,
  u.billing_origin_product,
  CASE
    WHEN u.product_features.is_serverless IS NULL THEN False -- MISC GCP infra costs not attributed to any direct DBx compute. This could be for short-lived compute or MISC GCP infra
    ELSE u.product_features.is_serverless
  END AS is_serverless, 
  u.product_features.is_photon,
  u.product_features.jobs_tier,
  u.product_features.sql_tier,
  -- Custom tags
  u.custom_tags,
  u.custom_tags['team'] AS team_tag,
  u.custom_tags['cost_center'] AS cost_center_tag,
  u.custom_tags['environment'] AS environment_tag,
  -- DBU list cost calculation
  lp.pricing.effective_list.default AS dbu_list_price,
  u.usage_quantity * lp.pricing.effective_list.default AS dbu_list_cost,
  u.record_type
FROM
  system.billing.usage u
    JOIN system.billing.list_prices lp
      ON lp.sku_name = u.sku_name
      AND lp.cloud = u.cloud
      AND u.usage_end_time >= lp.price_start_time
      AND (
        lp.price_end_time IS NULL
        OR u.usage_end_time < lp.price_end_time
      )
WHERE
  u.cloud = 'GCP'
  AND u.record_type != 'RETRACTION')

  SELECT * FROM base