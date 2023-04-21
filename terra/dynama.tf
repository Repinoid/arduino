
# create Yandex Data Base
resource "yandex_ydb_database_serverless" "temper-ydb" {
  name      = "temper-ydb-serverless"
}
# =======================================================================
# create SERVICE ACCOUNT with YDB ADMIN role
resource "yandex_iam_service_account" "temper-ydb-admin-sa" {
  name        = "service-account-for-temper-ydb"
  folder_id   = var.folder_id
  description = "service account for temper YDB"
}
# Assign data base admin ROLE
resource "yandex_resourcemanager_folder_iam_member" "temper-ydb-role" {
#  role          = "editor"
  role          = "ydb.admin"
  folder_id     = var.folder_id
  member       = "serviceAccount:${yandex_iam_service_account.temper-ydb-admin-sa.id}"
}
resource "yandex_resourcemanager_folder_iam_member" "temper-s3-role" {
  role          = "storage.uploader"
  folder_id     = var.folder_id
  member       = "serviceAccount:${yandex_iam_service_account.temper-ydb-admin-sa.id}"
}
# create static KEY
resource "yandex_iam_service_account_static_access_key" "temper-ybd-static-key" {
  service_account_id = yandex_iam_service_account.temper-ydb-admin-sa.id
  description        = "Static Key for temper SA"
}
# create table
resource "yandex_function" "temper-ydb-create-table" {
  name               = "temper-create-table"
  description        = "create table for sensor YDB"
  user_hash          = data.archive_file.lambda.output_base64sha256
  runtime            = "python37"
  entrypoint         = "tabloid.create_iot_ydb_table"
  memory             = "256"
  execution_timeout  = "510"
  service_account_id = yandex_iam_service_account.temper-ydb-admin-sa.id
  environment = {
      AWS_ACCESS_KEY_ID     = yandex_iam_service_account_static_access_key.temper-ybd-static-key.access_key
      AWS_SECRET_ACCESS_KEY = yandex_iam_service_account_static_access_key.temper-ybd-static-key.secret_key
      AWS_DEFAULT_REGION    = var.compute-default-zone
      document_api_endpoint = yandex_ydb_database_serverless.temper-ydb.document_api_endpoint   # link to Y Data Base
    }
  content { zip_filename = "iot.zip" }
}

# write 2 file function  
resource "yandex_function" "temper-ydb-write" {
  name               = "temper-ydb-write"
  description        = "write to sensor YDB"
  user_hash          = data.archive_file.lambda.output_base64sha256
  runtime            = "python37"
  entrypoint         = "tabloid.write2table"
  memory             = "256"
  execution_timeout  = "10"
  service_account_id = yandex_iam_service_account.temper-ydb-admin-sa.id
  environment = {
      AWS_ACCESS_KEY_ID     = yandex_iam_service_account_static_access_key.temper-ybd-static-key.access_key
      AWS_SECRET_ACCESS_KEY = yandex_iam_service_account_static_access_key.temper-ybd-static-key.secret_key
      AWS_DEFAULT_REGION    = var.compute-default-zone
      document_api_endpoint = yandex_ydb_database_serverless.temper-ydb.document_api_endpoint
    }
  content {
        zip_filename =  "iot.zip"
    }
}
/*
# read from data base
resource "yandex_function" "ydb-read" {
  name               = "ydb-reader"
  description        = "ydb-read"
  user_hash          = "ydb-read_hash_0"
  runtime            = "python37"
  entrypoint         = "tablerab.read_table"
  memory             = "256"
  execution_timeout  = "10"
  service_account_id = yandex_iam_service_account.ydb-service-account.id
  environment = {
      AWS_ACCESS_KEY_ID     = yandex_iam_service_account_static_access_key.sa-static-key.access_key
      AWS_SECRET_ACCESS_KEY = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
      AWS_DEFAULT_REGION    = var.compute-default-zone
      document_api_endpoint = yandex_ydb_database_serverless.ydb.document_api_endpoint
    }
  content {
        zip_filename =  "ydb.zip"
    }
}
# QUERY function
resource "yandex_function" "ydb-query" {
  name               = "ydb-query"
  description        = "ydb-q"
  user_hash          = "ydb-q000"
  runtime            = "python37"
  entrypoint         = "tablerab.query"
  memory             = "256"
  execution_timeout  = "10"
  service_account_id = yandex_iam_service_account.ydb-service-account.id
  environment = {
      AWS_ACCESS_KEY_ID     = yandex_iam_service_account_static_access_key.sa-static-key.access_key
      AWS_SECRET_ACCESS_KEY = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
      AWS_DEFAULT_REGION    = var.compute-default-zone
      document_api_endpoint = yandex_ydb_database_serverless.ydb.document_api_endpoint
    }
  content {
        zip_filename =  "ydb.zip"
    }
}



output "ID" {
    value = "${yandex_ydb_database_serverless.ydb.id}"
}
output "document_api_endpoint" {
    value = "${yandex_ydb_database_serverless.ydb.document_api_endpoint}"
}
output "ydb_full_endpoint" {
    value = "${yandex_ydb_database_serverless.ydb.ydb_full_endpoint}"
}
output "database_path" {
    value = "${yandex_ydb_database_serverless.ydb.database_path}"
}
}
output "status" {
    value = "${yandex_ydb_database_serverless.ydb.status}"
}

*/
