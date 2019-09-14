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
  tags           = ["controller"]
  zone           = "${var.zone}"

  network_interface {
    network_ip = "10.0.0.1${count.index}"
    subnetwork = "${google_compute_subnetwork.k8s-subnet.name}"
    access_config {
    }
  }

  network_interface {
    network_ip = "192.168.0.1${count.index}"
    subnetwork = "${google_compute_subnetwork.k8s-iscsi-subnet.name}"
  }

  service_account {
    scopes = ["compute-rw", "storage-ro", "service-management", "service-control", "logging-write", "monitoring"]
  }
}
