#================== Наберите в PowerShell yc config list. Скопируйте 4 значения в default , заключив в кавычки =========================================
variable "token" {
	type = string
	default = "y0_AgAA*********************S1f0"
}
variable "cloud_id" {
  type    = string
  default = "b1g**********************jp"
}
variable "folder_id" {
  type    = string
  default = "b1gj***********************65t"
}
variable "compute-default-zone" {
  type    = string
  default = "ru-central1-b"
}
# ===============================================================


variable "sensor_password" {
	type = string
	default = "Password7password"				# пароль минимум 14 символов, из 3х разных типов (верх-них регистр, цифры)
}
