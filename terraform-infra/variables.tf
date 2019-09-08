variable "project" {
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
  default = "centos-cloud/centos-7"
}

variable "controller-size" {
  default = 100
}

# worker settings
variable "worker-count" {
  default = 2
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
