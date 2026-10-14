# Azure Databricks Integration (ADI) Costs

Azure Databricks Integration (ADI) services, such as OpenAI and Gemini models served on Azure Databricks, are billed directly by Databricks rather than through the Azure invoice. Because of this, ADI charges do not appear in Azure Cost Management exports and are not included in the Actuals, Amortized, or FOCUS pipelines.

The [ADI cost query](adi_cost_query.sql) fills this gap by filtering `system.billing.usage` to ADI SKUs and pricing them with `system.billing.list_prices`. The same query powers the **ADI Costs** page of the Azure Cost Dashboard.

## Requirements

- Unity Catalog enabled with access to:
  - `system.billing.usage`
  - `system.billing.list_prices`
  - `system.access.workspaces_latest`

## ADI SKUs

ADI charges are identified by SKU. The query matches usage whose SKU starts with one of the following prefixes in its `adi_skus` list, which also picks up any regional SKU variants:

| SKU prefix | Provider |
|-----|----------|
| `PREMIUM_OPENAI_MODEL_SERVING` | OpenAI |
| `PREMIUM_GEMINI_MODEL_SERVING` | Google Gemini |
| `PREMIUM_ZHIPU_MODEL_SERVING` | Zhipu AI |
| `PREMIUM_MOONSHOT_MODEL_SERVING` | Moonshot AI |
| `PREMIUM_THINKING_MACHINES_MODEL_SERVING` | Thinking Machines Lab |
| `PREMIUM_DEEPSEEK_MODEL_SERVING` | DeepSeek |

The current list of ADI Services is maintained in the [Azure Databricks supported models documentation](https://learn.microsoft.com/en-us/azure/databricks/machine-learning/foundation-model-apis/supported-models).

> **Note:** Anthropic models are billed with a similarly named SKU (`PREMIUM_ANTHROPIC_MODEL_SERVING`) but are **not** ADI Services. Anthropic usage is billed through the Azure invoice, already appears in Azure Cost Management exports, and is intentionally excluded from this query to avoid double counting.

As new services are added to ADI, add their SKU prefixes to the `adi_skus` list in both `adi_cost_query.sql` and the **ADI Costs** dataset in `azure/src/azure_cost_dashboard.lvdash.json`.

## Usage

Run the query in Databricks SQL or a notebook. No parameters are required.

## Output Columns

| Column | Source |
|--------|--------|
| `date` | `usage_date` |
| `usage_start_time`, `usage_end_time` | Usage window |
| `account_id`, `workspace_id`, `workspace_name` | Account and workspace |
| `provider` | Model provider for the ADI SKU |
| `sku_name`, `billing_origin_product` | SKU and originating product |
| `endpoint_name`, `endpoint_id` | Serving endpoint from `usage_metadata` |
| `run_as` | Identity from `identity_metadata` |
| `usage_quantity`, `usage_unit` | Billed quantity |
| `currency_code`, `list_unit_price` | List price for the SKU at the time of usage |
| `price` | `usage_quantity × list_unit_price` |
| `custom_tags` | Tags applied to the usage |
| `record_id` | Usage record identifier |

## Limitations

- Costs are calculated at **list price** and do not reflect negotiated discounts.
- The global **Cost Type**, **Meter Category**, and **Vendor** filters on the Azure Cost Dashboard apply to Azure Cost Management data only and do not affect the ADI Costs page. The **Date** filter applies to all pages.
