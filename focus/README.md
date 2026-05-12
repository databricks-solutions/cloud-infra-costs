# Databricks System Tables → FOCUS 1.3 Query

Maps Databricks billing data from Unity Catalog system tables to the [FinOps Open Cost and Usage Specification (FOCUS) 1.3](https://focus.finops.org/focus-specification/v1-3/) schema.

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
| `:account_prices` | Full path to the prices table. Use this value if you are not in the Account Prices Preview | `system.billing.list_prices` |
| `:account_prices` | ull path to the prices table. Use this value if you are participating in the Account Prices Preview | `system.billing.list_prices` |

Set this as a Databricks SQL query parameter or substitute it directly in the query.

## Usage

Set the parameter according to the descriptions above and run in Databricks SQL or a notebook.

Then execute the query, or use the query parameter UI in Databricks SQL.

## FOCUS 1.3 Column Coverage

| # | Column | Status | Notes |
|---|--------|--------|-------|
| 3.1 | AvailabilityZone | Recommended | `NULL` — AZ not exposed in billing tables |
| 3.2 | BilledCost | Mandatory | `usage_quantity × account_unit_price` |
| 3.3 | BillingAccountId | Mandatory | `account_id` |
| 3.4 | BillingAccountName | Mandatory | `account_id` (name not available in system tables) |
| 3.5 | BillingAccountType | Conditional | `NULL` |
| 3.6 | BillingCurrency | Mandatory | `currency_code` (USD) |
| 3.7 | BillingPeriodEnd | Mandatory | End of calendar month |
| 3.8 | BillingPeriodStart | Mandatory | Start of calendar month |
| 3.9 | CapacityReservationId | Conditional | `NULL` |
| 3.10 | CapacityReservationStatus | Conditional | `NULL` |
| 3.11 | ChargeCategory | Mandatory | `'Usage'` |
| 3.12 | ChargeClass | Mandatory | `NULL` — no correction/adjustment data |
| 3.13 | ChargeDescription | Mandatory | `sku_name` |
| 3.14 | ChargeFrequency | Recommended | `'Usage-Based'` |
| 3.15 | ChargePeriodEnd | Mandatory | `usage_end_time` |
| 3.16 | ChargePeriodStart | Mandatory | `usage_start_time` |
| 3.17 | CommitmentDiscountCategory | Conditional | `NULL` |
| 3.18 | CommitmentDiscountId | Conditional | `NULL` |
| 3.19 | CommitmentDiscountName | Conditional | `NULL` |
| 3.20 | CommitmentDiscountQuantity | Conditional | `NULL` |
| 3.21 | CommitmentDiscountStatus | Conditional | `NULL` |
| 3.22 | CommitmentDiscountType | Conditional | `NULL` |
| 3.23 | CommitmentDiscountUnit | Conditional | `NULL` |
| 3.24 | ConsumedQuantity | Conditional | `usage_quantity` |
| 3.25 | ConsumedUnit | Conditional | `usage_unit` |
| 3.26 | ContractedCost | Mandatory | `usage_quantity × account_unit_price` |
| 3.27 | ContractedUnitPrice | Conditional | Account-level price |
| 3.28 | EffectiveCost | Mandatory | Same as BilledCost (no commitment discount data) |
| 3.29 | HostProviderName | Mandatory *(new in 1.3)* | Mapped from `cloud` field (AWS/Azure/GCP) |
| 3.30 | InvoiceId | Recommended | `NULL` |
| 3.31 | InvoiceIssuerName | Mandatory | `'Databricks'` |
| 3.32 | ListCost | Mandatory | `usage_quantity × list_unit_price` |
| 3.33 | ListUnitPrice | Conditional | From `system.billing.list_prices` |
| 3.34 | PricingCategory | Conditional | `'Standard'` |
| 3.35 | PricingCurrency | Conditional | `currency_code` |
| 3.36 | PricingCurrencyContractedUnitPrice | Conditional | Account-level price |
| 3.37 | PricingCurrencyEffectiveCost | Conditional | Same as EffectiveCost |
| 3.38 | PricingCurrencyListUnitPrice | Conditional | From list prices |
| 3.39 | PricingQuantity | Mandatory | `usage_quantity` |
| 3.40 | PricingUnit | Mandatory | `usage_unit` |
| 3.41 | ProviderName | *(deprecated in 1.3)* | `'Databricks'` — kept for backward compatibility |
| 3.42 | PublisherName | *(deprecated in 1.3)* | `'Databricks'` — kept for backward compatibility |
| 3.43 | RegionId | Conditional | Derived from `current_metastore()` |
| 3.44 | RegionName | Conditional | Derived from `current_metastore()` |
| 3.45 | ResourceId | Conditional | Mapped per `billing_origin_product` |
| 3.46 | ResourceName | Conditional | Resolved via system table joins |
| 3.47 | ResourceType | Conditional | Mapped per `billing_origin_product` |
| 3.48 | ServiceCategory | Mandatory | FOCUS taxonomy mapped from `billing_origin_product` |
| 3.49 | ServiceName | Mandatory | `billing_origin_product` |
| 3.50 | ServiceProviderName | Mandatory *(new in 1.3)* | `'Databricks'` |
| 3.51 | ServiceSubcategory | Recommended | FOCUS taxonomy mapped from `billing_origin_product` |
| 3.52 | SkuId | Conditional | `sku_name` |
| 3.53 | SkuMeter | Conditional | `usage_type` |
| 3.54 | SkuPriceDetails | Conditional | JSON of `product_features` with `x_` prefixed keys |
| 3.55 | SkuPriceId | Conditional | `sku_name` |
| 3.56 | SubAccountId | Conditional | `workspace_id` |
| 3.57 | SubAccountName | Conditional | `workspace_name` |
| 3.58 | SubAccountType | Conditional | `'Workspace'` |
| 3.59 | Tags | Conditional | `custom_tags` |

## Notes

- Mapping is on a best-effort level and will improve as additional data points are added to system tables. Customers may also use the SQL script as a starting point and make further changes
