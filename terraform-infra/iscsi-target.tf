resource "google_compute_disk" "iscsi-target-disk" {
  name = "iscsi-target-disk"
  size = "100"
  zone = "${var.zone}"
}

resource "google_compute_instance" "iscsi-target" {
  boot_disk {
    auto_delete = true

    initialize_params {
      image = "${var.worker-image}"
      size  = "${var.worker-size}"
    }
  }

  can_ip_forward = true
  machine_type   = "${var.worker-type}"
  name           = "iscsi-target"
  tags           = ["iscsi-target"]
  zone           = "${var.zone}"


  attached_disk {
    source = "${google_compute_disk.iscsi-target-disk.self_link}"
  }

  network_interface {
    network_ip = "10.0.0.100"
    subnetwork = "${google_compute_subnetwork.k8s-subnet.name}"
    access_config {
    }
  }
  network_interface {
    network_ip = "192.168.0.100"
    subnetwork = "${google_compute_subnetwork.k8s-iscsi-subnet.name}"
  }

  service_account {
    scopes = ["compute-rw", "storage-ro", "service-management", "service-control", "logging-write", "monitoring"]
  }

}
