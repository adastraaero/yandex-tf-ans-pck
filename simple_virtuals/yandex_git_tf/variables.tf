variable "cloud_id" {
  description = "Cloud"
}
variable "folder_id" {
  description = "Folder"
}
variable "zone" {
  description = "Zone"
  # Значение по умолчанию
  default = "ru-central1-a"
}
variable "public_key_path" {
  # Описание переменной
  description = "/home/mity/.ssh/id_rsa.pub"
}
variable "image_id" {
  description = "Disk image"
}
variable "subnet_id" {
  description = "Subnet"
}

variable "instance_count" {
  description = "count instances"
  default     = 1
}

variable "service_account_key_file" {
  description = "/home/mity/Documents/OtusDevops/terraform.json"
}
