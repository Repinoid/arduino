# ========================== REGISTRY & DEVICE =================================
# create IoT registry
resource "yandex_iot_core_registry" "temper_registry" {
  name        = "temper-registry"
  description = "registry for temp humid sensor"
  passwords = [
    var.sensor_password, # ПАРОЛЬ для реестра, пока не задействован, назначаем как на устройстве
  ]
  certificates = [
    file("certificates/reestr-cert.pem"), # файл сертификата РЕЕСТРА
  ]
}
# вывод ID реестра 
output "yandex_iot_core_registry_ID" {
  value = yandex_iot_core_registry.temper_registry.id
}
# create IoT device
resource "yandex_iot_core_device" "temper_device" {
  registry_id = yandex_iot_core_registry.temper_registry.id
  name        = "sensor_1"
  description = "sensor device ID"
  passwords = [
    var.sensor_password, # ПАРОЛЬ для устройства
  ]
  certificates = [
    file("certificates/device-cert.pem") # файл сертификата СЕНСОРА
  ]
}
# вывод ID устройства
output "yandex_iot_core_device_my_device" {
  value = yandex_iot_core_device.temper_device.id
}
# ==== create IoT SERVICE ACCOUNT with INVOKER role - имеет право запускать функцию ===========
resource "yandex_iam_service_account" "temper-invoker-sa" {
  name        = "temper-invoker-sa"
  folder_id   = var.folder_id
  description = "service account for invoker"
}
# create static ACCESS KEY 
resource "yandex_iam_service_account_static_access_key" "temper-static-key" {
  service_account_id = yandex_iam_service_account.temper-invoker-sa.id
  description        = "Static Key for temper SA"
}
# одна роль для сервисного аккаунта инвокера
resource "yandex_resourcemanager_folder_iam_member" "invoker-role-for-trigger" {
  folder_id = var.folder_id
  role      = "serverless.functions.invoker"
  member   = "serviceAccount:${yandex_iam_service_account.temper-invoker-sa.id}" 
}
#================================ создание ТРИГГЕРа, invoking by IoT message ===========
resource "yandex_function_trigger" "temper_trigger" {
  name        = "temper-trigger-function"
  description = "<триггер функции обработки данных с датчика>"
  iot {                                                           # iot field - means IoT trigger declaration
    registry_id = yandex_iot_core_registry.temper_registry.id
    device_id   = yandex_iot_core_device.temper_device.id
    topic       = "$devices/${yandex_iot_core_device.temper_device.id}/events"
  }
  function {
    id                 = yandex_function.temper_function.id
    service_account_id = yandex_iam_service_account.temper-invoker-sa.id
  }
}
# создание функции, вызываемой ТРИГГЕРОМ
resource "yandex_function" "temper_function" {
  name               = "temper-function"
  description        = "функция обработки данных с датчика"
  runtime            = "python37"
  entrypoint         = "tabloid.trigga"
  memory             = "256"
  execution_timeout  = "110"
  # ========== функция пишет в базу данных, поэтому её серв. акк. и ключи - для YDB with admin.role
  service_account_id = yandex_iam_service_account.temper-ydb-admin-sa.id
  environment = {                         # KEYS that declared for YDB, trigger function writes to DB
    AWS_ACCESS_KEY_ID     = yandex_iam_service_account_static_access_key.temper-ybd-static-key.access_key
    AWS_SECRET_ACCESS_KEY = yandex_iam_service_account_static_access_key.temper-ybd-static-key.secret_key
    AWS_DEFAULT_REGION    = var.compute-default-zone
    document_api_endpoint = yandex_ydb_database_serverless.temper-ydb.document_api_endpoint   # link to Y Data Base
  }
  user_hash = data.archive_file.lambda.output_base64sha256 #хеш-сумма архива.при любом изменении функция пересоздаётся
  content { zip_filename = "iot.zip" }
}

# create h-file for arduino C++ code, deviceID & registerID values
resource "local_file" "key_devid" {
  filename = "../nodemcu/secret_ids.h"
# строки между EOT должны быть строго как в создаваемом файле, т.е., например, без пробелов в начале строки
  content  = <<EOT
const char  MQTT_USER[]     = "${yandex_iot_core_device.temper_device.id}" ;          // id устройства, сиречь датчика
const char  MQTT_REGISTRY[] = "${yandex_iot_core_registry.temper_registry.id}" ;      // id реестра, может быть использован при расширении архитектуры
const char  MQTT_PASS[]     = "${var.sensor_password}" ;                              // задаётся в key.tf
  EOT
}

# create file for Python code, keys for access to database - задел на потОм
resource "local_file" "key_ybd" {
  filename = "../python/secret_ybd_keys.py"
  content  = <<EOT
AWS_ACCESS_KEY_ID     = "${yandex_iam_service_account_static_access_key.temper-ybd-static-key.access_key}"
AWS_SECRET_ACCESS_KEY = "${yandex_iam_service_account_static_access_key.temper-ybd-static-key.secret_key}"
document_api_endpoint = "${yandex_ydb_database_serverless.temper-ydb.document_api_endpoint}"   # link to Y Data Base 
  EOT
}

