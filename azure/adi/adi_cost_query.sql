-- Azure Databricks Integration (ADI) Cost Query
-- Compatible with Databricks SQL and Unity Catalog
--
-- ADI charges are billed directly by Databricks, not through the Azure invoice, so they do
-- not appear in Azure Cost Management exports. This query filters system.billing.usage to
-- ADI SKUs and prices them with system.billing.list_prices.
--
-- Usage: Run in Databricks SQL or a notebook. To pick up new ADI services, add their SKU
--        prefixes to the adi_skus list below. Prefixes also match any regional SKU variants.
--        The list of ADI Services is maintained at
--        https://learn.microsoft.com/en-us/azure/databricks/machine-learning/foundation-model-apis/supported-models
--
-- Note: Anthropic models use a similar SKU (PREMIUM_ANTHROPIC_MODEL_SERVING) but are not ADI
--       Services. They are billed through the Azure invoice and appear in Azure Cost Management
--       exports, so they are intentionally excluded here.
WITH adi_skus AS (
  SELECT * FROM VALUES
    ('PREMIUM_OPENAI_MODEL_SERVING', 'OpenAI'),
    ('PREMIUM_GEMINI_MODEL_SERVING', 'Google Gemini'),
    ('PREMIUM_ZHIPU_MODEL_SERVING', 'Zhipu AI'),
    ('PREMIUM_MOONSHOT_MODEL_SERVING', 'Moonshot AI'),
    ('PREMIUM_THINKING_MACHINES_MODEL_SERVING', 'Thinking Machines Lab'),
    ('PREMIUM_DEEPSEEK_MODEL_SERVING', 'DeepSeek')
    AS t(sku_prefix, provider)
),
list_prices AS (
  SELECT coalesce(price_end_time, date_add(current_date, 1)) AS coalesced_price_end_time, *
  FROM system.billing.list_prices
  WHERE currency_code = 'USD'
)
SELECT
  u.usage_date AS date,
  u.usage_start_time,
  u.usage_end_time,
  u.account_id,
  u.workspace_id,
  w.workspace_name,
  s.provider,
  u.sku_name,
  u.billing_origin_product,
  u.usage_metadata.endpoint_name AS endpoint_name,
  u.usage_metadata.endpoint_id AS endpoint_id,
  u.identity_metadata.run_as AS run_as,
  u.usage_quantity,
  u.usage_unit,
  lp.currency_code,
  CAST(lp.pricing.default AS DECIMAL(30, 15)) AS list_unit_price,
  CAST(COALESCE(u.usage_quantity * lp.pricing.default, 0) AS DECIMAL(30, 15)) AS price,
  u.custom_tags,
  u.record_id
FROM
  system.billing.usage u
    INNER JOIN adi_skus s
      ON startswith(u.sku_name, s.sku_prefix)
    LEFT JOIN list_prices lp
      ON u.sku_name = lp.sku_name
      AND u.usage_unit = lp.usage_unit
      AND u.account_id = lp.account_id
      -- Match usage time to the valid price window
      AND u.usage_end_time BETWEEN lp.price_start_time AND lp.coalesced_price_end_time
    LEFT JOIN system.access.workspaces_latest w
      ON u.account_id = w.account_id
      AND u.workspace_id = w.workspace_id
WHERE
  u.cloud = 'AZURE'
