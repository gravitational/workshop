output "node_1_private_ip" {
  value = google_compute_instance.cluster_node.*.network_interface.0.network_ip[0]
}

output "node_1_public_ip" {
  value = google_compute_instance.cluster_node.*.network_interface.0.access_config.0.nat_ip[0]
}

output "node_2_private_ip" {
  value = google_compute_instance.cluster_node.*.network_interface.0.network_ip[1]
}

output "node_2_public_ip" {
  value = google_compute_instance.cluster_node.*.network_interface.0.access_config.0.nat_ip[1]
}

output "node_3_private_ip" {
  value = google_compute_instance.cluster_node.*.network_interface.0.network_ip[2]
}

output "node_3_public_ip" {
  value = google_compute_instance.cluster_node.*.network_interface.0.access_config.0.nat_ip[2]
}

output "csv" {
  value = "${google_compute_instance.cluster_node.*.network_interface.0.access_config.0.nat_ip[0]},${google_compute_instance.cluster_node.*.network_interface.0.network_ip[0]},${google_compute_instance.cluster_node.*.network_interface.0.access_config.0.nat_ip[1]},${google_compute_instance.cluster_node.*.network_interface.0.network_ip[1]},${google_compute_instance.cluster_node.*.network_interface.0.access_config.0.nat_ip[2]},${google_compute_instance.cluster_node.*.network_interface.0.network_ip[2]}"
}

