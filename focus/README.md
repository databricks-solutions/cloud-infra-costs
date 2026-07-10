# Databricks System Tables → FOCUS 1.4 Cost and Usage Dataset

Maps Databricks billing data from Unity Catalog system tables to a [FinOps Open Cost and Usage Specification (FOCUS) 1.4](https://focus.finops.org/focus-specification/v1-4/)-conformant Cost and Usage dataset.

All 65 FOCUS 1.4 columns are present. Fields not available in Databricks system tables are populated with `NULL`, as permitted by each column's conformance level.

A [FOCUS 1.3](focus_query_1_3.sql) variant is also provided for environments that require the prior spec version.

## Requirements

- Unity Catalog enabled with access to:
  - `system.billing.usage`
  - `system.billing.list_prices`
  - `system.access.workspaces_latest`
  - `system.compute.clusters`
  - `system.compute.warehouses`
  - `system.lakeflow.pipelines`

## Parameters

| Parameter | Description | Value |
|-----------|-------------|---------|
| `:account_prices` | Full path to the prices table. Use this value if you are **not** in the Account Prices Preview. | `system.billing.list_prices` |
| `:account_prices` | Full path to the prices table. Use this value if you **are** participating in the Account Prices Preview (AWS and GCP only). | `system.billing.account_prices` |

Set this as a Databricks SQL query parameter or substitute it directly in the query.

> Not sure if you're in the Account Prices Preview? Ask your Databricks account team.

## Usage

Set the parameter according to the descriptions above and run in Databricks SQL or a notebook.

## FOCUS 1.4 Column Coverage

| Section | Column | Conformance | Value |
|---------|--------|-------------|-------|
| 3.1.1 | AllocatedMethodId | Conditional | `NULL` |
| 3.1.2 | AllocatedMethodDetails | Recommended | `NULL` |
| 3.1.3 | AllocatedResourceId | Conditional | `NULL` |
| 3.1.4 | AllocatedResourceName | Conditional | `NULL` |
| 3.1.5 | AllocatedTags | Conditional | `NULL` |
| 3.1.6 | AvailabilityZone | Recommended | `NULL` |
| 3.1.7 | BilledCost | Mandatory | `usage_quantity × account_unit_price` |
| 3.1.8 | BillingAccountId | Mandatory | `account_id` |
| 3.1.9 | BillingAccountName | Mandatory | `account_id` (name not available in system tables) |
| 3.1.10 | BillingAccountType | Conditional | `NULL` |
| 3.1.11 | BillingCurrency | Mandatory | `currency_code` (USD) |
| 3.1.12 | BillingPeriodEnd | Mandatory | End of calendar month |
| 3.1.13 | BillingPeriodStart | Mandatory | Start of calendar month |
| 3.1.14 | CapacityReservationId | Conditional | `NULL` |
| 3.1.15 | CapacityReservationStatus | Conditional | `NULL` |
| 3.1.16 | ChargeCategory | Mandatory | `'Usage'` |
| 3.1.17 | ChargeClass | Mandatory | `NULL` |
| 3.1.18 | ChargeDescription | Mandatory | `sku_name` |
| 3.1.19 | ChargeFrequency | Recommended | `'Usage-Based'` |
| 3.1.20 | ChargePeriodEnd | Mandatory | `usage_end_time` |
| 3.1.21 | ChargePeriodStart | Mandatory | `usage_start_time` |
| 3.1.22 | CommitmentDiscountCategory | Conditional | `NULL` |
| 3.1.23 | CommitmentDiscountId | Conditional | `NULL` |
| 3.1.24 | CommitmentDiscountName | Conditional | `NULL` |
| 3.1.25 | CommitmentDiscountQuantity | Conditional | `NULL` |
| 3.1.26 | CommitmentDiscountStatus | Conditional | `NULL` |
| 3.1.27 | CommitmentDiscountType | Conditional | `NULL` |
| 3.1.28 | CommitmentDiscountUnit | Conditional | `NULL` |
| 3.1.29 | CommitmentProgramEligibilityDetails | Conditional | `NULL` *(new in 1.4)* |
| 3.1.30 | ConsumedQuantity | Conditional | `usage_quantity` |
| 3.1.31 | ConsumedUnit | Conditional | `usage_unit` |
| 3.1.32 | ContractApplied | Conditional | `NULL` |
| 3.1.33 | ContractedCost | Mandatory | `usage_quantity × account_unit_price` |
| 3.1.34 | ContractedUnitPrice | Conditional | Account-level unit price |
| 3.1.35 | EffectiveCost | Mandatory | `usage_quantity × account_unit_price` |
| 3.1.36 | HostProviderName | Mandatory | Mapped from `cloud` field (`AWS` → `Amazon Web Services`, etc.) |
| 3.1.37 | InvoiceDetailId | Conditional | `NULL` *(new in 1.4)* |
| 3.1.38 | InvoiceId | Conditional | `NULL` |
| 3.1.39 | InvoiceIssuerName | Mandatory | `'Databricks'` |
| 3.1.40 | ListCost | Mandatory | `usage_quantity × list_unit_price` |
| 3.1.41 | ListUnitPrice | Conditional | From `system.billing.list_prices` |
| 3.1.42 | PricingCategory | Conditional | `'Standard'` |
| 3.1.43 | PricingCurrency | Conditional | `currency_code` |
| 3.1.44 | PricingCurrencyContractedUnitPrice | Conditional | Account-level unit price |
| 3.1.45 | PricingCurrencyEffectiveCost | Conditional | `usage_quantity × account_unit_price` |
| 3.1.46 | PricingCurrencyListUnitPrice | Conditional | From list prices |
| 3.1.47 | PricingQuantity | Mandatory | `usage_quantity` |
| 3.1.48 | PricingUnit | Mandatory | `usage_unit` |
| 3.1.49 | RegionId | Conditional | Derived from `current_metastore()` |
| 3.1.50 | RegionName | Conditional | Derived from `current_metastore()` |
| 3.1.51 | ResourceId | Conditional | Mapped per `billing_origin_product` |
| 3.1.52 | ResourceName | Conditional | Resolved via system table joins |
| 3.1.53 | ResourceType | Conditional | Mapped per `billing_origin_product` |
| 3.1.54 | ServiceProviderName | Mandatory | `'Databricks'` |
| 3.1.55 | ServiceCategory | Mandatory | FOCUS taxonomy mapped from `billing_origin_product` |
| 3.1.56 | ServiceName | Mandatory | `billing_origin_product` |
| 3.1.57 | ServiceSubcategory | Recommended | FOCUS taxonomy mapped from `billing_origin_product` |
| 3.1.58 | SkuId | Conditional | `sku_name` |
| 3.1.59 | SkuMeter | Conditional | `usage_type` |
| 3.1.60 | SkuPriceDetails | Conditional | JSON of `product_features` with `x_`-prefixed keys |
| 3.1.61 | SkuPriceId | Conditional | `sku_name` |
| 3.1.62 | SubAccountId | Conditional | `workspace_id` |
| 3.1.63 | SubAccountName | Conditional | `workspace_name` |
| 3.1.64 | SubAccountType | Conditional | `'Workspace'` |
| 3.1.65 | Tags | Conditional | `custom_tags` |

## Notes

- Mapping is on a best-effort basis and will improve as additional data is exposed in system tables. Use the SQL script as a starting point and adapt as needed.
- `RegionId` and `RegionName` are derived from `current_metastore()`, which returns the metastore region rather than the per-workspace region. In multi-region deployments, join workspace metadata or map `workspace_url` to regions for greater accuracy.
- `EffectiveCost` equals `BilledCost` because commitment discount and savings plan data are not available in Databricks system tables.

## Attribution

FOCUS™ is a trademark of the FinOps Foundation. The FOCUS specification is licensed under [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/legalcode) by Joint Development Foundation Projects, LLC, FinOps Open Cost and Usage Specification (FOCUS) Series and its contributors.
