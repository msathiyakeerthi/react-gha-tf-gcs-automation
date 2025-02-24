provider "google" {
  project = var.project_id
  region  = var.region
}

# Variables
variable "project_id" {
  type        = string
  description = "The GCP project ID"
}

variable "region" {
  type        = string
  default     = "us-east4"
  description = "The region for resources"
}

variable "zone" {
  type        = string
  default     = "us-east4-a"
  description = "The zone for resources"
}

variable "bucket_name" {
  type        = string
  description = "The name of the GCS bucket"
}

variable "location" {
  type        = string
  default     = "US"
  description = "The location for the GCS bucket"
}

variable "storage_class" {
  type        = string
  default     = "STANDARD"
  description = "The storage class for the GCS bucket"
}

variable "uniform_bucket_level_access" {
  type        = string
  default     = "true"
  description = "Enable uniform bucket-level access"
}

# Enable required APIs
resource "google_project_service" "services" {
  for_each = toset([
    "compute.googleapis.com",
    "storage.googleapis.com",
  ])
  project = var.project_id
  service = each.value
}

# VPC Network and Subnet
module "network" {
  source  = "terraform-google-modules/network/google"
  version = "~> 6.0"

  project_id   = var.project_id
  network_name = "poc-network"
  subnets = [
    {
      subnet_name   = "poc-subnet"
      subnet_ip     = "10.10.0.0/24"
      subnet_region = var.region
    }
  ]
}

# Firewall Rule
resource "google_compute_firewall" "default" {
  name    = "poc-firewall"
  network = module.network.network_name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["22", "80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["poc"]
}

# GCS Bucket
resource "google_storage_bucket" "bucket" {
  project                     = var.project_id
  name                        = var.bucket_name
  location                    = var.location
  storage_class               = var.storage_class
  uniform_bucket_level_access = var.uniform_bucket_level_access == "true"
}

# Compute Instance
resource "google_compute_instance" "poc_instance" {
  project      = var.project_id
  name         = "poc-instance"
  machine_type = "e2-standard-2"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "rhel-8-v20230810"
    }
  }

  network_interface {
    network    = module.network.network_name
    subnetwork = module.network.subnets_names[0]
    access_config {}
  }

  tags = ["poc"]
}
