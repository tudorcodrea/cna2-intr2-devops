terraform {
  backend "s3" {
    bucket         = "introspect2-tf-state-660633971866"
    key            = "terraform/state"
    region         = "us-east-1"
    dynamodb_table = "introspect2-tf-locks"
    encrypt        = true
    profile        = "cna2"
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks.cluster_name,
      "--profile",
      var.aws_profile,
      "--region",
      var.aws_region
    ]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        module.eks.cluster_name,
        "--profile",
        var.aws_profile,
        "--region",
        var.aws_region
      ]
    }
  }
}