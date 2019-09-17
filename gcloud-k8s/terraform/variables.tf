variable "project" {
  default = "iron-module-249314"
}

variable "region" {
  default = "europe-west3"
}
variable "zone" {
  default = "europe-west3-a"
}

# controller settings
variable "controller-count" {
  default = 3
}

variable "controller-type" {
  default = "n1-standard-1"
}

variable "controller-image" {
  default = "ubuntu-os-cloud/ubuntu-1804-lts"
}

variable "controller-size" {
  default = 100
}

# worker settings
variable "worker-count" {
  default = 3
}

variable "worker-type" {
  default = "n1-standard-1"
}

variable "worker-image" {
  default = "ubuntu-os-cloud/ubuntu-1804-lts"
}

variable "worker-size" {
  default = 100
}
