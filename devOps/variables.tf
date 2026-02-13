variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS profile to use"
  type        = string
  default     = "cna2"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "introspect2-eks"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.29"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "capacity_type" {
  description = "Capacity type for the node group (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "environment" {
  description = "Deployment environment tag (e.g., dev, test, prod)"
  type        = string
  default     = "dev"
}

variable "claims_service_lb_url" {
  description = "DNS name of the LoadBalancer for claims-service (update after K8s deployment)"
  type        = string
  default     = "a3c4edee04cc0470e82a81f6d9e84d13-2013895414.us-east-1.elb.amazonaws.com"
}

variable "backend_scheme" {
  description = "Scheme to use when calling the backend (http or https)"
  type        = string
  default     = "http"
}