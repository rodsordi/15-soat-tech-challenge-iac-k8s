# --- SERVICEACCOUNT & IRSA ---
resource "kubernetes_service_account" "garage_api_sa" {
  metadata {
    name      = "api-garage-sa"
    namespace = var.namespace_name
    annotations = {
      "eks.amazonaws.com/role-arn" = var.irsa_role_arn
    }
  }
}

# --- KUBERNETES SECRET FOR DB CREDENTIALS ---
resource "kubernetes_secret" "db_credentials" {
  metadata {
    name      = "api-garage-db-credentials"
    namespace = var.namespace_name
  }

  data = {
    username = var.db_username
    password = var.db_password
  }

  type = "Opaque"
}

# --- JAVA APPLICATION (15-soat-tech-challenge-garage) ---
resource "kubernetes_deployment" "garage_api" {
  wait_for_rollout = false

  metadata {
    name      = "api-garage"
    namespace = var.namespace_name
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations]
  }


  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "api-garage"
      }
    }

    template {
      metadata {
        labels = {
          app = "api-garage"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.garage_api_sa.metadata[0].name

        container {
          name  = "api-garage"
          image = var.image_url

          port {
            container_port = 8080
          }

          env {
            name  = "SPRING_DATASOURCE_URL"
            value = "jdbc:postgresql://${var.db_host}:${var.db_port}/${var.db_name}"
          }

          env {
            name = "SPRING_DATASOURCE_USERNAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.db_credentials.metadata[0].name
                key  = "username"
              }
            }
          }

          env {
            name = "SPRING_DATASOURCE_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.db_credentials.metadata[0].name
                key  = "password"
              }
            }
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }

          readiness_probe {
            http_get {
              path = "/actuator/health"
              port = 8080
            }
            initial_delay_seconds = 15
            period_seconds        = 10
          }

          liveness_probe {
            http_get {
              path = "/actuator/health"
              port = 8080
            }
            initial_delay_seconds = 30
            period_seconds        = 15
          }
        }
      }
    }
  }
}

# --- HORIZONTAL POD AUTOSCALER (HPA) ---
resource "kubernetes_horizontal_pod_autoscaler_v2" "garage_api_hpa" {
  metadata {
    name      = "api-garage-hpa"
    namespace = var.namespace_name
  }

  spec {
    min_replicas = 2
    max_replicas = 5

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.garage_api.metadata[0].name
    }

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }
  }
}

# Internal Network Load Balancer Service for AWS API Gateway VPC Link Integration
resource "kubernetes_service" "garage_api" {
  metadata {
    name      = "api-garage"
    namespace = var.namespace_name
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type"            = "nlb"
      "service.beta.kubernetes.io/aws-load-balancer-internal"        = "true"
      "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internal"
      "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "instance"
    }
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations]
  }

  spec {
    selector = {
      app = "api-garage"
    }

    port {
      name        = "http"
      port        = 8080
      target_port = 8080
      protocol    = "TCP"
    }

    type = "LoadBalancer"
  }
}

