# --- Secret for Keycloak Admin & DB Credentials ---
resource "kubernetes_secret" "keycloak_secret" {
  metadata {
    name      = "keycloak-credentials"
    namespace = var.namespace_name
  }

  data = {
    KEYCLOAK_ADMIN          = var.admin_username
    KEYCLOAK_ADMIN_PASSWORD = var.admin_password
    KC_DB_PASSWORD          = var.db_password
  }

  type = "Opaque"
}

# --- Keycloak Deployment on Kubernetes (EKS) ---
resource "kubernetes_deployment" "keycloak" {
  wait_for_rollout = false

  metadata {
    name      = "keycloak"
    namespace = var.namespace_name
    labels = {
      app = "keycloak"
    }
  }


  lifecycle {
    ignore_changes = [metadata[0].annotations]
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "keycloak"
      }
    }

    template {
      metadata {
        labels = {
          app = "keycloak"
        }
      }

      spec {
        container {
          name  = "keycloak"
          image = "quay.io/keycloak/keycloak:24.0.5"
          args  = ["start-dev", "--http-port=8080"]

          port {
            name           = "http"
            container_port = 8080
          }

          env {
            name  = "KC_DB"
            value = "postgres"
          }

          env {
            name  = "KC_DB_URL_HOST"
            value = var.db_host
          }

          env {
            name  = "KC_DB_URL_PORT"
            value = var.db_port
          }

          env {
            name  = "KC_DB_URL_DATABASE"
            value = var.db_name
          }

          env {
            name  = "KC_DB_USERNAME"
            value = var.db_username
          }

          env {
            name = "KC_DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.keycloak_secret.metadata[0].name
                key  = "KC_DB_PASSWORD"
              }
            }
          }

          env {
            name = "KEYCLOAK_ADMIN"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.keycloak_secret.metadata[0].name
                key  = "KEYCLOAK_ADMIN"
              }
            }
          }

          env {
            name = "KEYCLOAK_ADMIN_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.keycloak_secret.metadata[0].name
                key  = "KEYCLOAK_ADMIN_PASSWORD"
              }
            }
          }

          env {
            name  = "KC_PROXY_HEADERS"
            value = "xforwarded"
          }

          env {
            name  = "KC_HEALTH_ENABLED"
            value = "true"
          }

          env {
            name  = "KC_METRICS_ENABLED"
            value = "true"
          }


          resources {
            limits = {
              cpu    = "1000m"
              memory = "1024Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "512Mi"
            }
          }

          readiness_probe {
            http_get {
              path = "/health/ready"
              port = 8080
            }
            initial_delay_seconds = 60
            period_seconds        = 10
            timeout_seconds       = 5
          }

          liveness_probe {
            http_get {
              path = "/health/live"
              port = 8080
            }
            initial_delay_seconds = 90
            period_seconds        = 15
            timeout_seconds       = 5
          }
        }

      }
    }
  }
}

# --- Keycloak Internal NLB Service ---
resource "kubernetes_service" "keycloak" {
  metadata {
    name      = "keycloak"
    namespace = var.namespace_name
    labels = {
      app = "keycloak"
    }
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
      app = "keycloak"
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
