# Load Balancer configuration for GCE

data "google_compute_network" "training" {
  name = "default"
}

resource "google_compute_firewall" "ssh" {
  name    = "${var.node_tag}-allow-ssh"
  network = data.google_compute_network.training.self_link

  allow {
    protocol = "tcp"
    ports    = ["22", "61822", "32009", "3009"]
  }
}

