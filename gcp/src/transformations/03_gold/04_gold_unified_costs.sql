-- Gold Layer: Unified Costs (GCP + Databricks DBU per cluster per day)
-- Sources: silver_gcp_billing, silver_databricks_usage, system.compute.clusters
-- Target: gold_unified_costs

CREATE OR REFRESH MATERIALIZED VIEW ${gold_unified_costs}
AS
WITH -- Aggregate GCP infra costs per cluster per day
gcp_cluster_daily AS (
    SELECT
        usage_date,
        cluster_id,
        cluster_name,
        team_label,
        cost_center_label,
        environment_label,
        creator,
        project_id,
        region,

        SUM(gross_cost) AS gcp_gross_cost,
        SUM(net_cost) AS gcp_net_cost,
        SUM(cud_credits) AS gcp_cud_credits,
        SUM(sud_credits) AS gcp_sud_credits,
        SUM(promo_credits) AS gcp_promo_credits,
        SUM(cost_at_list) AS gcp_list_cost,

        -- Cost breakdown by service type
        SUM(CASE WHEN service_description = 'Compute Engine'
                  AND sku_description LIKE '%Instance%'
            THEN net_cost ELSE 0 END) AS gcp_compute_cost,
        SUM(CASE WHEN service_description = 'Compute Engine'
                  AND sku_description LIKE '%PD%'
            THEN net_cost ELSE 0 END) AS gcp_disk_cost,
        SUM(CASE WHEN service_description = 'Compute Engine'
                  AND (sku_description LIKE '%Egress%'
                       OR sku_description LIKE '%Network%'
                       OR sku_description LIKE '%IP%')
            THEN net_cost ELSE 0 END) AS gcp_network_cost,
        SUM(CASE WHEN service_description = 'Cloud Storage'
            THEN net_cost ELSE 0 END) AS gcp_storage_cost

    FROM ${silver_gcp_billing}
    WHERE vendor_label = 'databricks'
        AND cluster_id IS NOT NULL
    GROUP BY ALL
),

-- Aggregate Databricks DBU costs per cluster per day
dbu_cluster_daily AS (
    SELECT
        usage_date,
        cluster_id,
        workspace_id,
        billing_origin_product,
        is_serverless,

        -- Tags from Databricks side
        team_tag,
        cost_center_tag,
        environment_tag,

        SUM(dbu_quantity) AS total_dbus,
        SUM(dbu_list_cost) AS dbu_list_cost,

        -- Per-job breakdown for proportional allocation
        COLLECT_SET(NAMED_STRUCT(
            'job_id', job_id,
            'job_name', job_name,
            'run_as', run_as_user
        )) AS jobs_on_cluster

    FROM ${silver_databricks_usage}
    GROUP BY ALL
),

-- Enrich with cluster metadata
cluster_metadata AS (
    SELECT
        cluster_id,
        MAX_BY(cluster_name, change_time) AS cluster_display_name,
        MAX_BY(owned_by, change_time) AS cluster_owner,
        MAX_BY(driver_node_type, change_time) AS driver_type,
        MAX_BY(worker_node_type, change_time) AS worker_type,
        MAX_BY(dbr_version, change_time) AS runtime_version,
        MAX_BY(cluster_source, change_time) AS cluster_source,
        MAX_BY(tags, change_time) AS cluster_tags
    FROM system.compute.clusters
    GROUP BY cluster_id
)

-- Final unified view
SELECT
    COALESCE(d.usage_date, g.usage_date) AS usage_date,
    COALESCE(d.cluster_id, g.cluster_id) AS cluster_id,
    d.workspace_id,
    g.project_id AS gcp_project_id,
    g.region AS gcp_region,
    cm.cluster_display_name,
    cm.cluster_owner,
    cm.driver_type,
    cm.worker_type,
    cm.runtime_version,
    cm.cluster_source,
    d.billing_origin_product,
    COALESCE(d.team_tag, g.team_label) AS team,
    COALESCE(d.cost_center_tag, g.cost_center_label) AS cost_center,
    COALESCE(d.environment_tag, g.environment_label) AS environment,
    COALESCE(d.total_dbus, 0) AS total_dbus,
    COALESCE(d.dbu_list_cost, 0) AS dbu_list_cost,
    COALESCE(g.gcp_gross_cost, 0) AS gcp_gross_cost,
    COALESCE(g.gcp_net_cost, 0) AS gcp_net_cost,
    COALESCE(g.gcp_list_cost, 0) AS gcp_list_cost,
    COALESCE(g.gcp_cud_credits, 0) AS gcp_cud_credits,
    COALESCE(g.gcp_sud_credits, 0) AS gcp_sud_credits,
    COALESCE(g.gcp_compute_cost, 0) AS gcp_compute_cost,
    COALESCE(g.gcp_disk_cost, 0) AS gcp_disk_cost,
    COALESCE(g.gcp_network_cost, 0) AS gcp_network_cost,
    COALESCE(g.gcp_storage_cost, 0) AS gcp_storage_cost,
    COALESCE(d.dbu_list_cost, 0)
      + COALESCE(g.gcp_net_cost, 0) AS total_net_cost,
    COALESCE(d.dbu_list_cost, 0)
      + COALESCE(g.gcp_list_cost, 0) AS total_list_cost,
    CASE WHEN (COALESCE(d.dbu_list_cost, 0)
               + COALESCE(g.gcp_net_cost, 0)) > 0
         THEN COALESCE(d.dbu_list_cost, 0)
              / (COALESCE(d.dbu_list_cost, 0)
                 + COALESCE(g.gcp_net_cost, 0))
         ELSE NULL
    END AS dbu_cost_ratio,
    d.jobs_on_cluster,
    is_serverless
FROM dbu_cluster_daily d
FULL OUTER JOIN gcp_cluster_daily g
    ON d.cluster_id = g.cluster_id
    AND d.usage_date = g.usage_date
LEFT JOIN cluster_metadata cm
    ON COALESCE(d.cluster_id, g.cluster_id) = cm.cluster_id;
