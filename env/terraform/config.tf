variable "nodes" {
  description = "Number of cluster nodes."
  default     = "3"
}

variable "purpose" {
  description = "Environment purpose, will be used for billing."
  default     = "training"
}

variable "cluster_instance_type" {
  description = "VM instance type to use for the cluster nodes."
  default     = "n1-standard-4"
}

variable "vm_image" {
  description = "VM image reference."
  default     = "ubuntu-os-cloud/ubuntu-1604-xenial-v20180405"
}

variable "node_tag" {
  description = "GCE-friendly cluster name to use as a prefix for resources."
}

variable "disk_type" {
  description = "Type of disk to provision."
  default     = "pd-ssd"
}

variable "os_user" {
  description = "Name of the SSH user."
  default     = "ubuntu"
}

variable "ssh_key_path" {
  description = "Path to the public SSH key."
  default     = ""
}

variable "project" {
  description = "Project to deploy to, if not set the default provider project is used."
  default     = "kubeadm-167321"
}

variable "region" {
  description = "Region for resources."
  default     = "us-central1"
}

variable "zone" {
  description = "Zone for resources."
  default     = "us-central1-a"
}

variable "credentials" {
  description = "Path to application access credentials file."
  default     = ""
}

provider "google" {
  project     = var.project
  region      = var.region
  credentials = file(var.credentials)
}

terraform {
  backend "local" {}
}
