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
# load balancer for controllers
resource "google_compute_address" "k8s-staticip" {
  name   = "k8s-staticip"
  region = "${var.region}"
}

resource "google_compute_firewall" "k8s_lbfirewall" {
  allow {
    protocol = "tcp"
  }

  name    = "k8s-lbfirewall"
  network = "${google_compute_network.k8s-network.name}"

  source_ranges = ["0.0.0.0/0"]

}

resource "google_compute_http_health_check" "k8s-lbhealthcheck" {
  host         = "kubernetes.default.svc.cluster.local"
  name         = "k8s-lbhealthcheck"
  request_path = "/healthz"
}

resource "google_compute_target_pool" "k8s-lbtartgetpool" {
  name = "k8s-lbtartgetpool"
  instances = [
    for controller in google_compute_instance.k8s-controller :
    "${var.zone}/${controller.name}"
  ]

  health_checks = [
    "${google_compute_http_health_check.k8s-lbhealthcheck.name}",
  ]
}

resource "google_compute_forwarding_rule" "k8s-lbforwarding" {
  ip_address = "${google_compute_address.k8s-staticip.address}"
  name       = "k8s-lbforwarding"
  port_range = "6443"
  target     = "${google_compute_target_pool.k8s-lbtartgetpool.self_link}"
}
