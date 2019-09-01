resource "google_compute_network" "k8s-network" {
  auto_create_subnetworks = false
  name                    = "k8s-network"
}

resource "google_compute_subnetwork" "k8s-subnet" {
  name          = "k8s-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = "${var.region}"
  network       = "${google_compute_network.k8s-network.self_link}"
}

#Firewall
resource "google_compute_firewall" "k8s-internalfirewall" {
  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  name    = "k8s-internalfirewall"
  network = "${google_compute_network.k8s-network.name}"

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "k8s-externalfirewall" {
  name    = "k8s-externalfirewall"
  network = "${google_compute_network.k8s-network.name}"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22", "6443"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# External static IP
resource "google_compute_address" "k8s-staticip" {
  name   = "k8s-staticip"
  region = "${var.region}"
}
