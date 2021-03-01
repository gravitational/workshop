resource "google_compute_instance_group" "training" {
  description = "Instance group with all instances for the training"
  name        = "${var.node_tag}-grp"
  zone        = var.zone
  network     = data.google_compute_network.training.self_link
  instances   = google_compute_instance.cluster_node.*.self_link
}

resource "google_compute_instance" "cluster_node" {
  description  = "Node that will be a part of the cluster"
  count        = var.nodes
  name         = "${var.node_tag}-cluster-node-${count.index + 1}"
  machine_type = var.cluster_instance_type
  zone         = var.zone

  tags = [
    var.node_tag,
  ]

  labels = {
    cluster = var.node_tag
    purpose = var.purpose
  }

  network_interface {
    network = data.google_compute_network.training.self_link

    access_config {
      # Ephemeral IP
    }
  }

  metadata = {
    # Enable OS login using IAM roles
    enable-oslogin = "true"
    # ssh-keys controls access to an instance using a custom SSH key
    ssh-keys = "${var.os_user}:${file(var.ssh_key_path)}"
  }

  metadata_startup_script = data.template_file.bootstrap_cluster_node[count.index].rendered

  boot_disk {
    initialize_params {
      image = var.vm_image
      type  = var.disk_type
      size  = 50
    }

    auto_delete = "true"
  }

  attached_disk {
    source = google_compute_disk.etcd[count.index].self_link
    mode   = "READ_WRITE"
  }

  attached_disk {
    source = google_compute_disk.system[count.index].self_link
    mode   = "READ_WRITE"
  }

  service_account {
    scopes = [
      "compute-rw",
      "storage-ro",
    ]
  }
}

resource "google_compute_disk" "etcd" {
  count = var.nodes
  name  = "${var.node_tag}-disk-etcd-${count.index}"
  type  = var.disk_type
  zone  = var.zone
  size  = 10

  labels = {
    cluster = var.node_tag
    purpose = var.purpose
  }
}

resource "google_compute_disk" "system" {
  count = var.nodes
  name  = "${var.node_tag}-disk-system-${count.index}"
  type  = var.disk_type
  zone  = var.zone
  size  = 50

  labels = {
    cluster = var.node_tag
    purpose = var.purpose
  }
}

data "template_file" "bootstrap_cluster_node" {
  count    = var.nodes
  template = file("./bootstrap-cluster-node.sh.tpl")

  vars = {
    ssh_user = var.os_user
    hostname = "node-${count.index + 1}"
  }
}

