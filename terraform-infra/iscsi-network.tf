resource "google_compute_network" "k8s-iscsi-network" {
  auto_create_subnetworks = false
  name                    = "k8s-iscsi-network"
}

resource "google_compute_subnetwork" "k8s-iscsi-subnet" {
  name          = "k8s-iscsi-subnet"
  ip_cidr_range = "192.168.0.0/24"
  region        = "${var.region}"
  network       = "${google_compute_network.k8s-iscsi-network.self_link}"
}

resource "google_compute_firewall" "iscsi-firewall" {
  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  name    = "iscsi-firewall"
  network = "${google_compute_network.k8s-iscsi-network.name}"

  source_ranges = ["192.168.0.0/24"]
}
