terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "1.85.0"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

provider "databricks" {
  host = var.databricks_host
}
