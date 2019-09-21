variable "project" {
}

variable "region" {
  default = "europe-west3"
}
variable "zone" {
  default = "europe-west3-a"
}

variable "worker-type" {
  default = "n1-standard-1"
}

variable "worker-image" {
  default = "centos-cloud/centos-7"
}

variable "worker-size" {
  default = 100
}
