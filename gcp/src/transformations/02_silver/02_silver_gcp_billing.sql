-- Silver Layer: Cleaned and Enriched GCP Billing
-- Source: bronze_gcp_billing
-- Target: silver_gcp_billing

CREATE OR REFRESH MATERIALIZED VIEW ${silver_gcp_billing}
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS
SELECT
    DATE(usage_start_time) AS usage_date,
    DATE_TRUNC('hour', usage_start_time) AS usage_hour,
    billing_account_id,
    project.id AS project_id,
    project.name AS project_name,
    service.id AS service_id,
    service.description AS service_description,
    sku.id AS sku_id,
    sku.description AS sku_description,
    location.region AS region,
    location.zone AS zone,
    get(FILTER(labels, x -> x.key = 'sku'), 0).value AS sku,
    get(FILTER(labels, x -> x.key = 'vendor'), 0).value AS vendor_label,
    get(FILTER(labels, x -> x.key = 'clusterid'), 0).value AS cluster_id,
    get(FILTER(labels, x -> x.key = 'clustername'), 0).value AS cluster_name,
    get(FILTER(labels, x -> x.key = 'creator'), 0).value AS creator,
    get(FILTER(labels, x -> x.key = 'jobid'), 0).value AS job_id,
    get(FILTER(labels, x -> x.key = 'runname'), 0).value AS run_name,
    get(FILTER(labels, x -> x.key = 'databricksinstancepoolid'), 0).value AS instance_pool_id,
    get(FILTER(labels, x -> x.key = 'team'), 0).value AS team_label,
    get(FILTER(labels, x -> x.key = 'cost_center'), 0).value AS cost_center_label,
    get(FILTER(labels, x -> x.key = 'environment'), 0).value AS environment_label,
    resource.name AS resource_name,
    resource.global_name AS resource_global_name,
    cost AS gross_cost,
    currency,
    cost_at_list,
    usage.amount AS usage_amount,
    usage.unit AS usage_unit,
    usage.amount_in_pricing_units,
    usage.pricing_unit,
    invoice.month AS invoice_month,
    IFNULL(AGGREGATE(credits, DOUBLE(0), (acc, c) -> acc + c.amount), 0) AS total_credits,
    IFNULL(AGGREGATE(FILTER(credits, c -> c.type = 'COMMITTED_USE_DISCOUNT'), DOUBLE(0), (acc, c) -> acc + c.amount), 0) AS cud_credits,
    IFNULL(AGGREGATE(FILTER(credits, c -> c.type = 'SUSTAINED_USE_DISCOUNT'), DOUBLE(0), (acc, c) -> acc + c.amount), 0) AS sud_credits,
    IFNULL(AGGREGATE(FILTER(credits, c -> c.type = 'PROMOTION'), DOUBLE(0), (acc, c) -> acc + c.amount), 0) AS promo_credits,
    cost + IFNULL(AGGREGATE(credits, DOUBLE(0), (acc, c) -> acc + c.amount), 0) AS net_cost,
    get(FILTER(system_labels, x -> x.key = 'compute.googleapis.com/machine_spec'), 0).value AS machine_spec,
    get(FILTER(system_labels, x -> x.key = 'compute.googleapis.com/cores'), 0).value AS core_count,
    export_time,
    cost_type
FROM ${bronze_gcp_billing}
WHERE cost_type = 'regular';
