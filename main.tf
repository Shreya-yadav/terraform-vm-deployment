provider "google" {
  project = var.project_id
  region  = var.region
}

# Create a Google Cloud Storage bucket to store the startup script
resource "google_storage_bucket" "jenkins_bucket" {
  name     = "${var.project_id}-jenkins-scripts"
  location = var.region
}

# Upload the startup script to the Google Cloud Storage bucket
resource "google_storage_bucket_object" "jenkins_startup_script" {
  name        = "install_jenkins.sh"
  bucket      = google_storage_bucket.jenkins_bucket.name
  source      = "install_jenkins.sh"
  content_type = "text/x-shellscript"
}

# Create the instance template
resource "google_compute_instance_template" "jenkins_template" {
  name         = "jenkins-template"
  machine_type = "e2-medium"

  disk {
    source_image = "projects/debian-cloud/global/images/family/debian-12"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata = {
    startup-script-url = "gs://skilled-clover-429308-m2-jenkins-scripts/install_jenkins.sh"
  }

  service_account {
    scopes = ["storage-ro", "logging-write", "monitoring"]
  }

  tags = ["jenkins"]
}

# Create a firewall rule to allow traffic to Jenkins
resource "google_compute_firewall" "jenkins_firewall" {
  name    = "jenkins-allow-http"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  allow {
    protocol = "icmp"
  }

  target_tags   = ["jenkins"]
  source_ranges = ["0.0.0.0/0"]
}

# Create an HTTP health check for autohealing
resource "google_compute_http_health_check" "jenkins_health_check" {
  name               = "jenkins-http-health-check"
  request_path       = "/"
  check_interval_sec = 30
  timeout_sec        = 10
  healthy_threshold  = 3
  unhealthy_threshold = 3
  port               = 8080
}

# Create the managed instance group
resource "google_compute_instance_group_manager" "jenkins_mig" {
  name               = "jenkins-mig"
  zone               = var.zone
  base_instance_name = "jenkins-instance"

  version {
    instance_template  = google_compute_instance_template.jenkins_template.self_link
  }

  target_size = 1  # Initial size, can be adjusted

  # Autohealing configuration
  auto_healing_policies {
    health_check      = google_compute_http_health_check.jenkins_health_check.id
    initial_delay_sec = 300  # 5 minutes
  }
}

# Create a firewall rule to allow HTTP traffic
resource "google_compute_firewall" "jenkins_http_firewall" {
  name    = "jenkins-http-firewall"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["jenkins"]
}

# Create Autoscaler for managed instance group
resource "google_compute_autoscaler" "jenkins_autoscaler" {
  name               = "jenkins-autoscaler"
  zone               = var.zone
  target             = google_compute_instance_group_manager.jenkins_mig.instance_group
  autoscaling_policy {
    min_replicas = 1
    max_replicas = 5

    # Scaling based on CPU utilization
    cpu_utilization {
      target = 0.5
    }
  }

  # Link the autoscaler to the instance group manager
  depends_on = [
    google_compute_instance_group_manager.jenkins_mig
  ]
}