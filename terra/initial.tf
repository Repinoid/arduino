# =============================================================================
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}
provider "yandex" {
  token     = var.token
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.compute-default-zone
}
# ==========================================================================

# упаковка питон-файлов в ZIP
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "./tozip/" # папка с питон-файлами
  output_path = "iot.zip"
}
