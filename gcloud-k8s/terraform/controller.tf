resource "google_compute_instance" "k8s-controller" {
  boot_disk {
    auto_delete = true

    initialize_params {
      image = "${var.controller-image}"
      size  = "${var.controller-size}"
    }
  }

  can_ip_forward = true
  count          = "${var.controller-count}"
  machine_type   = "${var.controller-type}"
  name           = "controller-${count.index}"

  network_interface {
    subnetwork = "${google_compute_subnetwork.k8s-subnet.name}"
    access_config {
    }
  }

  service_account {
    scopes = ["compute-rw", "storage-ro", "service-management", "service-control", "logging-write", "monitoring"]
  }

  tags = ["controller"]
  zone = "${var.zone}"
}
