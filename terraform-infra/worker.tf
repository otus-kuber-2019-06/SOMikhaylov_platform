resource "google_compute_instance" "k8s-worker" {
  boot_disk {
    auto_delete = true

    initialize_params {
      image = "${var.worker-image}"
      size  = "${var.worker-size}"
    }
  }

  can_ip_forward = true
  count          = "${var.worker-count}"
  machine_type   = "${var.worker-type}"
  name           = "worker-${count.index}"
  tags           = ["worker"]
  zone           = "${var.zone}"


  network_interface {
    network_ip = "10.0.0.2${count.index}"
    subnetwork = "${google_compute_subnetwork.k8s-subnet.name}"
    access_config {
    }
  }

  service_account {
    scopes = ["compute-rw", "storage-ro", "service-management", "service-control", "logging-write", "monitoring"]
  }

}
