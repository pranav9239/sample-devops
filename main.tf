# Define fixed location for state file to maintain the state between runs
terraform {
  backend "local" {
    path = "../../../terraform/state/terraform/state/terraform.tfstate"
  }
}

# Define variables
variable "image_static_website" {
  description = "Docker image for static website"
  type        = string
  default     = "static-website"
}

variable "image_version_static_website" {
  description = "Docker image for static website"
  type        = string
  default     = "latest"
}

variable "location_static_website" {
  description = "Location of dockerfile for static website"
  type        = string
  default     = "./spotify-clone-website/"
}

variable "image_dynamic_website" {
  description = "Docker image for dynamic website"
  type        = string
  default     = "dynamic-website"
}

variable "image_version_dynamic_website" {
  description = "Docker image for static website"
  type        = string
  default     = "latest"
}

variable "location_dynamic_website" {
  description = "Location of dockerfile for dynamic website"
  type        = string
  default     = "./website-visit-tracker/"
}

variable "label_static" {
  description = "Label of static website"
  type        = string
  default     = "static"
}

variable "label_dynamic" {
  description = "Label of dynamic website"
  type        = string
  default     = "dynamic"
}

variable "num_replicas_static" {
  description = "Number of replicas for static website"
  type        = number
  default     = 2
}

variable "num_replicas_dynamic" {
  description = "Number of replicas for dynamic website"
  type        = number
  default     = 2
}

variable "container_port" {
  description = "Container port to be exposed"
  type        = number
  default     = 8080
}

variable "service_port_static" {
  description = "Service port to be exposed for static website"
  type        = number
  default     = 8001
}

variable "service_port_dynamic" {
  description = "Service port to be exposed for dynamic website"
  type        = number
  default     = 8002
}

variable "website_version" {
  description = "Version of the website"
  type        = string
  default     = "v1.0.0"
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

# Define namespace (optional)
resource "kubernetes_namespace" "namespace" {
  metadata {
    name = "tf"
  }
}

# Build Docker Image for static_website
/* resource "null_resource" "build_docker_image_static_website" {
  provisioner "local-exec" {
    command = "docker build -t ${var.image_static_website}:${var.image_version_static_website} ${var.location_static_website}"
  }

  triggers = {
    image_id = "${timestamp()}"
  }
} */

# Build Docker Image for dynamic_website
/* resource "null_resource" "build_docker_image_dynamic_website" {
  provisioner "local-exec" {
    command = "docker build -t ${var.image_dynamic_website}:${var.image_version_dynamic_website} ${var.location_dynamic_website}"
  }

  triggers = {
    image_id = "${timestamp()}"
  }
} */

# Deploy static_website
resource "kubernetes_deployment" "static_website_deployment" {
  #depends_on = [null_resource.build_docker_image_static_website]
  depends_on = [ kubernetes_namespace.namespace ]

  metadata {
    name      = "static-website-deployment"
    namespace = kubernetes_namespace.namespace.metadata[0].name
    labels = {
      app = var.label_static
    }
  }

  spec {
    replicas = var.num_replicas_static
    selector {
      match_labels = {
        app = var.label_static
      }
    }

    template {
      metadata {
        labels = {
          app = var.label_static
        }
      }
      spec {
        container {
          name              = "static-website-container"
          image             = var.image_static_website
          image_pull_policy = "Never"

          port {
            container_port = var.container_port
          }

          env {
            name = "WEBSITE_VERSION"
            value = var.website_version
          }
        }
      }
    }
  }
}

# Deploy dynamic_website
resource "kubernetes_deployment" "dynamic_website_deployment" {
  #depends_on = [null_resource.build_docker_image_dynamic_website]
  depends_on = [ kubernetes_namespace.namespace ]

  metadata {
    name      = "dynamic-website-deployment"
    namespace = kubernetes_namespace.namespace.metadata[0].name
    labels = {
      app = var.label_dynamic
    }
  }

  spec {
    replicas = var.num_replicas_dynamic
    selector {
      match_labels = {
        app = var.label_dynamic
      }
    }

    template {
      metadata {
        labels = {
          app = var.label_dynamic
        }
      }
      spec {
        container {
          name              = "dynamic-website-container"
          image             = var.image_dynamic_website
          image_pull_policy = "Never"

          port {
            container_port = var.container_port
          }

          env {
            name = "WEBSITE_VERSION"
            value = var.website_version
          }
        }
      }
    }
  }
}

# Service for static website using LoadBalancer
resource "kubernetes_service" "static_website_service" {
  depends_on = [ kubernetes_namespace.namespace ]

  metadata {
    name      = "static-website-service"
    namespace = kubernetes_namespace.namespace.metadata[0].name
  }

  spec {
    type = "LoadBalancer"
    selector = {
      app = var.label_static
    }

    port {
      port        = var.service_port_static
      target_port = var.container_port
    }
  }
}

# Service for dynamic website using LoadBalancer
resource "kubernetes_service" "dynamic_website_service" {
  depends_on = [ kubernetes_namespace.namespace ]

  metadata {
    name      = "dynamic-website-service"
    namespace = kubernetes_namespace.namespace.metadata[0].name
  }

  spec {
    type = "LoadBalancer"
    selector = {
      app = var.label_dynamic
    }

    port {
      port        = var.service_port_dynamic
      target_port = var.container_port
    }
  }
}

# Deploy container for running Uptime Kuma
resource "kubernetes_deployment" "uptime_kuma" {
  depends_on = [ kubernetes_namespace.namespace ]

  metadata {
    name      = "uptime-kuma"
    namespace = kubernetes_namespace.namespace.metadata[0].name
    labels = {
      app = "kuma"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "kuma"
      }
    }

    template {
      metadata {
        labels = {
          app = "kuma"
        }
      }
      spec {
        container {
          name              = "kuma-container"
          image             = "louislam/uptime-kuma:1"

          port {
            container_port = 3001
          }

          # Optional: Define an emptyDir volume if no persistent storage is needed
          volume_mount {
            name      = "uptime-kuma-storage"
            mount_path = "/app/data"
          }
        }

        volume {
          name = "uptime-kuma-storage"
          empty_dir {}
        }
      }
    }
  }
}

# Service for Uptime Kuma using LoadBalancer
resource "kubernetes_service" "uptime_kuma_service" {
  depends_on = [ kubernetes_namespace.namespace ]

  metadata {
    name      = "uptime-kuma-service"
    namespace = kubernetes_namespace.namespace.metadata[0].name
  }

  spec {
    type = "LoadBalancer"
    selector = {
      app = "kuma"
    }

    port {
      port        = 3001
      target_port = 3001
    }
  }
}
