-- Databricks System Tables to FOCUS 1.3 Mapping Query
-- Compatible with Databricks SQL and Unity Catalog
-- Specification: https://focus.finops.org/focus-specification/v1-3/

-- Usage: Replace :account_prices with your account-level prices table path,
--        e.g. system.billing.list_prices (same table, filtered to your account).
WITH pipeline_names AS (
  -- Latest known name per pipeline (system.lakeflow.pipelines is an SCD table)
  SELECT account_id, workspace_id, pipeline_id, name AS pipeline_name
  FROM system.lakeflow.pipelines
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY account_id, workspace_id, pipeline_id ORDER BY create_time DESC
  ) = 1
),
cluster_names AS (
  -- Latest known name per cluster
  SELECT account_id, workspace_id, cluster_id, cluster_name
  FROM system.compute.clusters
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY account_id, workspace_id, cluster_id ORDER BY change_time DESC
  ) = 1
),
warehouse_names AS (
  -- Latest known name per SQL warehouse
  SELECT account_id, workspace_id, warehouse_id, warehouse_name
  FROM system.compute.warehouses
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY account_id, workspace_id, warehouse_id ORDER BY change_time DESC
  ) = 1
),
list_prices as (
  select coalesce(price_end_time, date_add(current_date, 1)) as coalesced_price_end_time, *
  from system.billing.list_prices
  where currency_code = 'USD'
),
account_prices as (
  select coalesce(price_end_time, date_add(current_date, 1)) as coalesced_price_end_time, *
  from IDENTIFIER(:account_prices)
  where currency_code = 'USD'
),
usage_with_pricing AS (
  SELECT
    u.record_id,
    u.account_id,
    u.workspace_id,
    w.workspace_name,
    u.sku_name,
    u.cloud,
    u.usage_start_time,
    u.usage_end_time,
    u.usage_date,
    u.usage_quantity,
    u.usage_unit,
    u.usage_type,
    u.custom_tags,
    u.usage_metadata,
    u.product_features,
    u.billing_origin_product,
    -- Resource names from system tables
    pip.pipeline_name,
    cl.cluster_name,
    wh.warehouse_name,
    -- Join pricing to get list rates
    lp.currency_code,
    lp.price_start_time,
    CAST(lp.pricing.default AS DECIMAL(30, 15)) AS list_unit_price,
    CAST(ap.pricing.default AS DECIMAL(30, 15)) AS account_unit_price
  FROM
    system.billing.usage u
      LEFT JOIN list_prices lp
        ON u.sku_name = lp.sku_name
        AND u.usage_unit = lp.usage_unit
        AND u.account_id = lp.account_id
        -- Match usage time to the valid price window
        AND u.usage_end_time between lp.price_start_time and lp.coalesced_price_end_time
      LEFT JOIN account_prices ap
        ON u.sku_name = ap.sku_name
        AND u.usage_unit = ap.usage_unit
        AND u.account_id = ap.account_id
        -- Match usage time to the valid price window
        AND u.usage_end_time between ap.price_start_time and ap.coalesced_price_end_time
      LEFT JOIN system.access.workspaces_latest w
        ON u.account_id = w.account_id
        AND u.workspace_id = w.workspace_id
      LEFT JOIN pipeline_names pip
        ON u.account_id = pip.account_id
        AND u.workspace_id = pip.workspace_id
        AND u.usage_metadata.dlt_pipeline_id = pip.pipeline_id
      LEFT JOIN cluster_names cl
        ON u.account_id = cl.account_id
        AND u.workspace_id = cl.workspace_id
        AND u.usage_metadata.cluster_id = cl.cluster_id
      LEFT JOIN warehouse_names wh
        ON u.account_id = wh.account_id
        AND u.workspace_id = wh.workspace_id
        AND u.usage_metadata.warehouse_id = wh.warehouse_id
)
SELECT
  -- 3.1 Availability Zone (Recommended)
  -- Databricks billing is Regional; AZ data is not exposed in billing tables.
  CAST(NULL AS STRING) AS AvailabilityZone,
  -- 3.2 Billed Cost (Mandatory)
  -- Rows with no matching price record are coerced to 0 to satisfy the Mandatory constraint.
  CAST(COALESCE(usage_quantity * account_unit_price, 0) AS DECIMAL(30, 15)) AS BilledCost,
  -- 3.3 Billing Account ID (Mandatory)
  u.account_id AS BillingAccountId,
  -- 3.4 Billing Account Name (Mandatory)
  -- Databricks does not expose account name in system tables; account_id is used as a placeholder.
  u.account_id AS BillingAccountName,
  -- 3.5 Billing Account Type (Conditional)
  CAST(NULL AS STRING) AS BillingAccountType,
  -- 3.6 Billing Currency (Mandatory)
  u.currency_code AS BillingCurrency,
  -- 3.7 Billing Period End (Mandatory) — exclusive end of the calendar month
  DATE_TRUNC('MONTH', u.usage_date)
  + INTERVAL 1 MONTH AS BillingPeriodEnd,
  -- 3.8 Billing Period Start (Mandatory)
  DATE_TRUNC('MONTH', u.usage_date) AS BillingPeriodStart,
  -- 3.9 Capacity Reservation ID (Conditional)
  CAST(NULL AS STRING) AS CapacityReservationId,
  -- 3.10 Capacity Reservation Status (Conditional)
  CAST(NULL AS STRING) AS CapacityReservationStatus,
  -- 3.11 Charge Category (Mandatory)
  'Usage' AS ChargeCategory,
  -- 3.12 Charge Class (Mandatory)
  -- No correction/adjustment data available in system tables.
  CAST(NULL AS STRING) AS ChargeClass,
  -- 3.13 Charge Description (Mandatory)
  u.sku_name AS ChargeDescription,
  -- 3.14 Charge Frequency (Recommended)
  'Usage-Based' AS ChargeFrequency,
  -- 3.15 Charge Period End (Mandatory)
  u.usage_end_time AS ChargePeriodEnd,
  -- 3.16 Charge Period Start (Mandatory)
  u.usage_start_time AS ChargePeriodStart,
  -- 3.17 Commitment Discount Category (Conditional)
  CAST(NULL AS STRING) AS CommitmentDiscountCategory,
  -- 3.18 Commitment Discount ID (Conditional)
  CAST(NULL AS STRING) AS CommitmentDiscountId,
  -- 3.19 Commitment Discount Name (Conditional)
  CAST(NULL AS STRING) AS CommitmentDiscountName,
  -- 3.20 Commitment Discount Quantity (Conditional)
  CAST(NULL AS DECIMAL(30, 15)) AS CommitmentDiscountQuantity,
  -- 3.21 Commitment Discount Status (Conditional)
  CAST(NULL AS STRING) AS CommitmentDiscountStatus,
  -- 3.22 Commitment Discount Type (Conditional)
  CAST(NULL AS STRING) AS CommitmentDiscountType,
  -- 3.23 Commitment Discount Unit (Conditional)
  CAST(NULL AS STRING) AS CommitmentDiscountUnit,
  -- 3.24 Consumed Quantity (Conditional)
  -- In Databricks, usage quantity is the consumed quantity.
  CAST(u.usage_quantity AS DECIMAL(30, 15)) AS ConsumedQuantity,
  -- 3.25 Consumed Unit (Conditional)
  u.usage_unit AS ConsumedUnit,
  -- 3.26 Contracted Cost (Mandatory)
  CAST(COALESCE(usage_quantity * account_unit_price, 0) AS DECIMAL(30, 15)) AS ContractedCost,
  -- 3.27 Contracted Unit Price (Conditional)
  CAST(u.account_unit_price AS DECIMAL(30, 15)) AS ContractedUnitPrice,
  -- 3.28 Effective Cost (Mandatory)
  -- Without commitment discount / savings plan data, Effective Cost = Billed Cost.
  CAST(COALESCE(usage_quantity * account_unit_price, 0) AS DECIMAL(30, 15)) AS EffectiveCost,
  -- 3.29 Host Provider Name (Mandatory - NEW in FOCUS 1.3)
  -- The cloud infrastructure provider hosting the Databricks workload.
  CASE u.cloud
    WHEN 'AWS' THEN 'Amazon Web Services'
    WHEN 'AZURE' THEN 'Microsoft Azure'
    WHEN 'GCP' THEN 'Google Cloud Platform'
    ELSE u.cloud
  END AS HostProviderName,
  -- 3.30 Invoice ID (Recommended)
  CAST(NULL AS STRING) AS InvoiceId,
  -- 3.31 Invoice Issuer Name (Mandatory)
  'Databricks' AS InvoiceIssuerName,
  -- 3.32 List Cost (Mandatory)
  CAST(COALESCE(u.usage_quantity * u.list_unit_price, 0) AS DECIMAL(30, 15)) AS ListCost,
  -- 3.33 List Unit Price (Conditional)
  CAST(u.list_unit_price AS DECIMAL(30, 15)) AS ListUnitPrice,
  -- 3.34 Pricing Category (Conditional)
  'Standard' AS PricingCategory,
  -- 3.35 Pricing Currency (Conditional)
  u.currency_code AS PricingCurrency,
  -- 3.36 Pricing Currency Contracted Unit Price (Conditional)
  CAST(u.account_unit_price AS DECIMAL(30, 15)) AS PricingCurrencyContractedUnitPrice,
  -- 3.37 Pricing Currency Effective Cost (Conditional)
  CAST(
    COALESCE(usage_quantity * account_unit_price, 0) AS DECIMAL(30, 15)
  ) AS PricingCurrencyEffectiveCost,
  -- 3.38 Pricing Currency List Unit Price (Conditional)
  CAST(u.list_unit_price AS DECIMAL(30, 15)) AS PricingCurrencyListUnitPrice,
  -- 3.39 Pricing Quantity (Mandatory)
  CAST(u.usage_quantity AS DECIMAL(30, 15)) AS PricingQuantity,
  -- 3.40 Pricing Unit (Mandatory)
  u.usage_unit AS PricingUnit,
  -- 3.41 Provider Name (DEPRECATED in FOCUS 1.3 — kept for backward compatibility)
  -- Replaced by ServiceProviderName + HostProviderName + InvoiceIssuerName.
  'Databricks' AS ProviderName,
  -- 3.42 Publisher Name (DEPRECATED in FOCUS 1.3 — kept for backward compatibility)
  -- Replaced by ServiceProviderName.
  'Databricks' AS PublisherName,
  -- 3.43 Region ID (Conditional)
  -- Note: current_metastore() returns the metastore region, not the per-workspace region.
  -- For multi-region deployments, join workspace metadata or map workspace_url to regions.
  split(current_metastore(), ':')[1] AS RegionId,
  -- 3.44 Region Name (Conditional)
  split(current_metastore(), ':')[1] AS RegionName,
  -- 3.45 Resource ID (Conditional)
  CASE
    WHEN
      u.billing_origin_product IN ('JOBS')
    THEN
      COALESCE(u.usage_metadata.job_id, u.billing_origin_product)
    WHEN
      u.billing_origin_product IN ('LAKEHOUSE_MONITORING')
    THEN
      COALESCE(u.custom_tags['LakehouseMonitoringTableId'], u.billing_origin_product)
    WHEN u.billing_origin_product IN ('PREDICTIVE_OPTIMIZATION') THEN u.billing_origin_product
    WHEN
      u.billing_origin_product IN ('DLT', 'ONLINE_TABLES', 'LAKEFLOW_CONNECT')
    THEN
      COALESCE(u.usage_metadata.dlt_pipeline_id, u.billing_origin_product)
    WHEN
      u.billing_origin_product IN ('MODEL_SERVING')
      AND u.sku_name = 'ENTERPRISE_ALL_PURPOSE_COMPUTE'
    THEN
      -- Model serving provisioned throughput backed by a classic cluster
      COALESCE(u.usage_metadata.cluster_id, u.billing_origin_product)
    WHEN
      u.billing_origin_product IN ('VECTOR_SEARCH')
      AND (
        u.sku_name LIKE 'ENTERPRISE_JOBS_SERVERLESS_COMPUTE%'
        OR u.sku_name LIKE 'ENTERPRISE_SERVERLESS_SQL_COMPUTE%'
      )
    THEN
      COALESCE(u.usage_metadata.dlt_pipeline_id, u.billing_origin_product)
    WHEN
      u.billing_origin_product IN ('MODEL_SERVING', 'AI_FUNCTIONS', 'VECTOR_SEARCH', 'AI_GATEWAY')
    THEN
      COALESCE(u.usage_metadata.endpoint_id, u.billing_origin_product)
    WHEN
      u.billing_origin_product IN ('DATABASE')
      AND (u.sku_name LIKE 'ENTERPRISE_JOBS_SERVERLESS_COMPUTE%')
    THEN
      COALESCE(u.usage_metadata.dlt_pipeline_id, u.billing_origin_product)
    WHEN
      u.billing_origin_product = 'DATABASE'
    THEN
      COALESCE(u.usage_metadata.database_instance_id, u.billing_origin_product)
    WHEN
      u.billing_origin_product = 'ALL_PURPOSE'
    THEN
      COALESCE(u.usage_metadata.cluster_id, u.billing_origin_product)
    WHEN
      u.billing_origin_product = 'DATA_CLASSIFICATION'
    THEN
      COALESCE(u.usage_metadata.catalog_id, u.billing_origin_product)
    WHEN
      u.billing_origin_product = 'FINE_GRAINED_ACCESS_CONTROL'
    THEN
      COALESCE(u.custom_tags['Name'], u.billing_origin_product)
    WHEN
      u.billing_origin_product IN ('NETWORKING', 'AGENT_EVALUATION', 'SHARED_SERVERLESS_COMPUTE')
    THEN
      u.billing_origin_product
    WHEN
      u.billing_origin_product = 'FOUNDATION_MODEL_TRAINING'
    THEN
      COALESCE(u.usage_metadata.run_name, u.billing_origin_product)
    WHEN
      u.billing_origin_product = 'AI_RUNTIME'
    THEN
      COALESCE(u.usage_metadata.ai_runtime_workload_id, u.billing_origin_product)
    WHEN
      u.billing_origin_product = 'CLEAN_ROOM'
    THEN
      COALESCE(u.usage_metadata.central_clean_room_id, u.billing_origin_product)
    WHEN
      u.billing_origin_product = 'APPS'
    THEN
      COALESCE(u.usage_metadata.app_id, u.billing_origin_product)
    WHEN
      -- SQL notebook run inside a Jobs/DLT pipeline context uses a Jobs Serverless Compute SKU
      u.billing_origin_product = 'SQL'
      AND (u.sku_name LIKE '%_JOBS_SERVERLESS_COMPUTE%')
    THEN
      COALESCE(u.usage_metadata.dlt_pipeline_id, u.billing_origin_product)
    WHEN
      u.billing_origin_product = 'SQL'
    THEN
      COALESCE(u.usage_metadata.warehouse_id, u.billing_origin_product)
    WHEN
      u.billing_origin_product = 'AGENT_BRICKS'
    THEN
      COALESCE(u.usage_metadata.agent_bricks_id, u.billing_origin_product)
    WHEN
      u.billing_origin_product = 'BASE_ENVIRONMENTS'
    THEN
      COALESCE(u.usage_metadata.base_environment_id, u.billing_origin_product)
    WHEN
      u.billing_origin_product = 'DATA_QUALITY_MONITORING'
    THEN
      COALESCE(u.usage_metadata.schema_id, u.billing_origin_product)
    WHEN
      u.billing_origin_product = 'DATA_SHARING'
    THEN
      COALESCE(u.usage_metadata.sharing_materialization_id, u.billing_origin_product)
    WHEN
      u.billing_origin_product IN ('INTERACTIVE', 'NOTEBOOKS')
    THEN
      COALESCE(u.usage_metadata.notebook_id, u.billing_origin_product)
    ELSE u.billing_origin_product
  END AS ResourceId,
  -- 3.46 Resource Name (Conditional)
  -- Names are resolved via system table joins (pipelines, clusters, warehouses).
  -- For resources without a dedicated system table, name fields from usage_metadata are used.
  -- Falls back to the resource ID when the name is not available.
  CASE
    WHEN u.billing_origin_product IN ('JOBS')
      THEN COALESCE(u.usage_metadata.job_name, u.usage_metadata.job_id)
    WHEN u.billing_origin_product IN ('DLT', 'LAKEFLOW_CONNECT', 'ONLINE_TABLES')
      THEN COALESCE(u.pipeline_name, u.usage_metadata.dlt_pipeline_id)
    WHEN u.billing_origin_product = 'ALL_PURPOSE'
      THEN COALESCE(u.cluster_name, u.usage_metadata.cluster_id)
    WHEN u.billing_origin_product = 'SQL'
      THEN COALESCE(u.warehouse_name, u.usage_metadata.warehouse_id)
    WHEN u.billing_origin_product IN ('MODEL_SERVING', 'AI_GATEWAY', 'AI_FUNCTIONS', 'VECTOR_SEARCH')
      THEN COALESCE(u.usage_metadata.endpoint_name, u.usage_metadata.endpoint_id)
    WHEN u.billing_origin_product = 'APPS'
      THEN COALESCE(u.usage_metadata.app_name, u.usage_metadata.app_id)
    WHEN u.billing_origin_product IN ('INTERACTIVE', 'NOTEBOOKS')
      THEN COALESCE(u.usage_metadata.notebook_path, u.usage_metadata.notebook_id)
    WHEN u.billing_origin_product = 'FOUNDATION_MODEL_TRAINING'
      THEN u.usage_metadata.run_name
    WHEN u.billing_origin_product = 'AI_RUNTIME'
      THEN u.usage_metadata.ai_runtime_workload_id
    WHEN u.billing_origin_product = 'DATABASE'
      THEN u.usage_metadata.database_instance_id
    WHEN u.billing_origin_product = 'AGENT_BRICKS'
      THEN u.usage_metadata.agent_bricks_id
    WHEN u.billing_origin_product = 'CLEAN_ROOM'
      THEN u.usage_metadata.central_clean_room_id
    WHEN u.billing_origin_product = 'BASE_ENVIRONMENTS'
      THEN u.usage_metadata.base_environment_id
    WHEN u.billing_origin_product = 'DATA_SHARING'
      THEN u.usage_metadata.sharing_materialization_id
    ELSE u.billing_origin_product
  END AS ResourceName,
  -- 3.47 Resource Type (Conditional)
  CASE
    WHEN u.billing_origin_product = 'JOBS' THEN 'Job'
    WHEN u.billing_origin_product = 'DLT' THEN 'Spark Declarative Pipeline'
    WHEN u.billing_origin_product = 'LAKEFLOW_CONNECT' THEN 'LakeFlow Connect'
    WHEN u.billing_origin_product = 'ALL_PURPOSE' THEN 'Cluster'
    WHEN u.billing_origin_product = 'INTERACTIVE' THEN 'Compute'
    WHEN u.billing_origin_product = 'NOTEBOOKS' THEN 'Notebook'
    WHEN u.billing_origin_product = 'SQL' THEN 'SQL Warehouse'
    WHEN u.billing_origin_product = 'MODEL_SERVING' THEN 'Model Serving Endpoint'
    WHEN u.billing_origin_product = 'VECTOR_SEARCH' THEN 'Vector Search Endpoint'
    WHEN u.billing_origin_product = 'AI_GATEWAY' THEN 'AI Gateway'
    WHEN u.billing_origin_product = 'AI_FUNCTIONS' THEN 'AI Function'
    WHEN u.billing_origin_product = 'FOUNDATION_MODEL_TRAINING' THEN 'Foundation Model Training Run'
    WHEN u.billing_origin_product = 'AGENT_EVALUATION' THEN 'Agent Evaluation'
    WHEN u.billing_origin_product = 'AGENT_BRICKS' THEN 'Agent'
    WHEN u.billing_origin_product = 'AI_RUNTIME' THEN 'AI Runtime Workload'
    WHEN u.billing_origin_product = 'DATABASE' THEN 'Database Instance'
    WHEN u.billing_origin_product = 'ONLINE_TABLES' THEN 'Online Table'
    WHEN u.billing_origin_product = 'DEFAULT_STORAGE' THEN 'Storage'
    WHEN u.billing_origin_product = 'LAKEHOUSE_MONITORING' THEN 'Lakehouse Monitoring'
    WHEN u.billing_origin_product = 'DATA_QUALITY_MONITORING' THEN 'Data Quality Monitor'
    WHEN u.billing_origin_product = 'PREDICTIVE_OPTIMIZATION' THEN 'Predictive Optimization'
    WHEN u.billing_origin_product = 'CLEAN_ROOM' THEN 'Clean Room'
    WHEN u.billing_origin_product = 'DATA_CLASSIFICATION' THEN 'Data Classification'
    WHEN u.billing_origin_product = 'FINE_GRAINED_ACCESS_CONTROL' THEN 'Access Control Policy'
    WHEN u.billing_origin_product = 'NETWORKING' THEN 'Networking'
    WHEN u.billing_origin_product = 'SHARED_SERVERLESS_COMPUTE' THEN 'Serverless Compute'
    WHEN u.billing_origin_product = 'BASE_ENVIRONMENTS' THEN 'Base Environment'
    WHEN u.billing_origin_product = 'APPS' THEN 'Application'
    WHEN u.billing_origin_product = 'DATA_SHARING' THEN 'Data Share'
    ELSE COALESCE(u.billing_origin_product, 'Other')
  END AS ResourceType,
  -- 3.48 Service Category (Mandatory)
  CASE
    -- Compute
    WHEN u.billing_origin_product IN ('ALL_PURPOSE', 'INTERACTIVE', 'NOTEBOOKS', 'SHARED_SERVERLESS_COMPUTE')
      THEN 'Compute'
    -- Analytics
    WHEN u.billing_origin_product IN ('JOBS', 'DLT')
      THEN 'Analytics'
    -- AI and Machine Learning
    WHEN u.billing_origin_product IN (
      'MODEL_SERVING',
      'VECTOR_SEARCH',
      'FOUNDATION_MODEL_TRAINING',
      'AGENT_EVALUATION',
      'AI_GATEWAY',
      'AI_FUNCTIONS',
      'AGENT_BRICKS',
      'AI_RUNTIME'
    )
      THEN 'AI and Machine Learning'
    -- Storage
    WHEN u.billing_origin_product IN ('DEFAULT_STORAGE')
      THEN 'Storage'
    -- Databases
    WHEN u.billing_origin_product IN ('DATABASE', 'ONLINE_TABLES', 'SQL')
      THEN 'Databases'
    -- Management and Governance
    WHEN u.billing_origin_product IN (
      'LAKEHOUSE_MONITORING',
      'DATA_QUALITY_MONITORING',
      'PREDICTIVE_OPTIMIZATION',
      'CLEAN_ROOM',
      'DATA_SHARING'
    )
      THEN 'Management and Governance'
    -- Security
    WHEN u.billing_origin_product IN ('FINE_GRAINED_ACCESS_CONTROL', 'DATA_CLASSIFICATION')
      THEN 'Security'
    -- Networking
    WHEN u.billing_origin_product IN ('NETWORKING')
      THEN 'Networking'
    -- Integration
    WHEN u.billing_origin_product IN ('LAKEFLOW_CONNECT')
      THEN 'Integration'
    -- Developer Tools
    WHEN u.billing_origin_product IN ('BASE_ENVIRONMENTS')
      THEN 'Developer Tools'
    -- Web
    WHEN u.billing_origin_product IN ('APPS')
      THEN 'Web'
    ELSE 'Other'
  END AS ServiceCategory,
  -- 3.49 Service Name (Mandatory)
  u.billing_origin_product AS ServiceName,
  -- 3.50 Service Provider Name (Mandatory - NEW in FOCUS 1.3)
  'Databricks' AS ServiceProviderName,
  -- 3.51 Service Subcategory (Recommended)
  CASE
    -- Compute
    WHEN u.billing_origin_product = 'ALL_PURPOSE'
      THEN 'Virtual Machines'
    WHEN u.billing_origin_product = 'INTERACTIVE'
      THEN
        CASE
          WHEN upper(u.sku_name) LIKE '%SERVERLESS%' THEN 'Serverless Compute'
          ELSE 'Virtual Machines'
        END
    WHEN u.billing_origin_product IN ('NOTEBOOKS', 'SHARED_SERVERLESS_COMPUTE')
      THEN 'Serverless Compute'
    -- Analytics
    WHEN u.billing_origin_product IN ('JOBS', 'DLT')
      THEN 'Data Processing'
    -- AI and Machine Learning
    WHEN u.billing_origin_product = 'MODEL_SERVING'
      THEN 'AI Platforms'
    WHEN u.billing_origin_product IN ('FOUNDATION_MODEL_TRAINING', 'AGENT_BRICKS', 'AI_RUNTIME')
      THEN 'Generative AI'
    WHEN u.billing_origin_product IN ('AI_GATEWAY', 'AI_FUNCTIONS')
      THEN 'AI Platforms'
    WHEN u.billing_origin_product IN ('VECTOR_SEARCH', 'AGENT_EVALUATION')
      THEN 'Other (AI and Machine Learning)'
    -- Storage
    WHEN u.billing_origin_product = 'DEFAULT_STORAGE'
      THEN 'Object Storage'
    -- Databases
    WHEN u.billing_origin_product = 'SQL'
      THEN 'Data Warehouses'
    WHEN u.billing_origin_product IN ('DATABASE', 'ONLINE_TABLES')
      THEN 'Relational Databases'
    -- Management and Governance
    WHEN u.billing_origin_product IN ('LAKEHOUSE_MONITORING', 'DATA_QUALITY_MONITORING')
      THEN 'Observability'
    WHEN u.billing_origin_product = 'PREDICTIVE_OPTIMIZATION'
      THEN 'Cost Management'
    WHEN u.billing_origin_product IN ('CLEAN_ROOM', 'DATA_SHARING')
      THEN 'Other (Management and Governance)'
    -- Security
    WHEN u.billing_origin_product = 'DATA_CLASSIFICATION'
      THEN 'Security Posture Management'
    WHEN u.billing_origin_product = 'FINE_GRAINED_ACCESS_CONTROL'
      THEN 'Other (Security)'
    -- Networking
    WHEN u.billing_origin_product = 'NETWORKING'
      THEN 'Network Connectivity'
    -- Integration
    WHEN u.billing_origin_product = 'LAKEFLOW_CONNECT'
      THEN 'Other (Integration)'
    -- Developer Tools
    WHEN u.billing_origin_product = 'BASE_ENVIRONMENTS'
      THEN 'Development Environments'
    -- Web
    WHEN u.billing_origin_product = 'APPS'
      THEN 'Application Platforms'
    ELSE 'Other (Other)'
  END AS ServiceSubcategory,
  -- 3.52 SKU ID (Conditional)
  u.sku_name AS SkuId,
  -- 3.53 SKU Meter (Conditional)
  u.usage_type AS SkuMeter,
  -- 3.54 SKU Price Details (Conditional)
  to_json(
    map_from_entries(
      filter(
        transform(
          map_entries(from_json(to_json(u.product_features), 'map<string, string>')),
          e -> named_struct('key', concat('x_', e.key), 'value', e.value)
        ),
        kv -> kv.value IS NOT NULL
      )
    )
  ) AS SkuPriceDetails,
  -- 3.55 SKU Price ID (Conditional)
  u.sku_name AS SkuPriceId,
  -- 3.56 Sub Account ID (Conditional)
  u.workspace_id AS SubAccountId,
  -- 3.57 Sub Account Name (Conditional)
  u.workspace_name AS SubAccountName,
  -- 3.58 Sub Account Type (Conditional)
  'Workspace' AS SubAccountType,
  -- 3.59 Tags (Conditional)
  u.custom_tags AS Tags
FROM
  usage_with_pricing u;
