# Cloud Infra Costs

> **Featured by the FinOps Foundation** — Databricks is one of only **two providers** ([alongside Vercel](https://focus.finops.org/get-started/)) shipping a [FOCUS **v1.3**](https://focus.finops.org/focus-specification/v1-3/) data generator. The script is linked from the official [FinOps Foundation FOCUS site](https://focus.finops.org/) and lives in [`focus/`](focus/README.md).

For Databricks non-serverless compute, total cost of ownership (TCO) information is fragmented between cloud cost reports (e.g., AWS CUR, Azure Cost Mgmt) & Databricks system tables (richer granularity & metadata). While many users are becoming increasingly familiar with Databricks system tables, joining with Azure & AWS cost reports can be cumbersome.

This solution helps automate and simplify this process - with it, users can report on the total infra (VM, networking, storage) and Databricks costs (DBUs) of their classic compute, in unified dashboards.

The solution is broken down into three pieces — pick the one that matches how your cost data is exported:
- [**FOCUS v1.3**](focus/README.md) — vendor-neutral [FinOps Open Cost and Usage Specification](https://focus.finops.org/focus-specification/v1-3/) output from Databricks system tables. Recommended if you want a single, standardized schema across cloud providers.
- [**Azure**](azure/README.md) — unifies Azure Cost Management exports (Actuals, Amortized, FOCUS) with Databricks system tables.
- [**AWS**](aws/README.md) — unifies AWS CUR with Databricks system tables.

<img width="1444" height="653" alt="Screenshot 2025-11-05 at 10 58 37 AM" src="https://github.com/user-attachments/assets/611b8cf5-cf23-4c98-84a9-eab3776669fe" />


## How to get help

Databricks support doesn't cover this content. For questions or bugs, please open a GitHub issue and the team will help on a best effort basis.


## License

&copy; 2025 Databricks, Inc. All rights reserved. The source in this notebook is provided subject to the Databricks License [https://databricks.com/db-license-source].  All included or referenced third party libraries are subject to the licenses set forth below.

| library                                | description             | license    | source                                              |
|----------------------------------------|-------------------------|------------|-----------------------------------------------------|
| HashiCorp Terraform                    | Infrastructure as code tool | [BUSL 1.1](https://www.hashicorp.com/bsl)   | https://github.com/hashicorp/terraform              |
| hashicorp/azurerm Terraform provider   | Azure Resource Manager provider for Terraform | [MPL 2.0](https://www.mozilla.org/en-US/MPL/2.0/)    | https://github.com/hashicorp/terraform-provider-azurerm |
| databricks/databricks Terraform provider | Databricks provider for Terraform | [Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0) | https://github.com/databricks/terraform-provider-databricks |
| Apache Spark (PySpark)                 | Distributed data processing engine (runtime dependency) | [Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0) | https://github.com/apache/spark                     |
