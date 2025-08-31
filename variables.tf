variable "project_id" {
  description = "The ID of the GCP project"
  type        = string
  default     = "skilled-clover-429308-m2"
}

variable "region" {
  description = "The region to deploy resources"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The zone to deploy resources"
  type        = string
  default     = "us-central1-a"
}
