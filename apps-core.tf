# --- POSTGRES ---
resource "kubernetes_deployment" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.garage.metadata[0].name
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations]
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "postgres" } }
    template {
      metadata { labels = { app = "postgres" } }
      spec {
        container {
          name  = "postgres"
          image = "postgres:15"

          port {
            container_port = 5432
          }

          env {
            name  = "POSTGRES_USER"
            value = "postgres"
          }
          env {
            name  = "POSTGRES_PASSWORD"
            value = "postgres"
          }
          env {
            name  = "POSTGRES_DB"
            value = "postgres"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.garage.metadata[0].name
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations]
  }

  spec {
    selector = { app = "postgres" }
    port {
      port        = 5432
      target_port = 5432
      node_port   = 30432
    }
    type = "NodePort"
  }
}

# --- FLOCI ---
resource "kubernetes_deployment" "floci" {
  metadata {
    name      = "floci"
    namespace = kubernetes_namespace.garage.metadata[0].name
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations]
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "floci" } }
    template {
      metadata { labels = { app = "floci" } }
      spec {
        enable_service_links = false
        container {
          name  = "floci"
          image = "floci/floci:latest"
          port {
            container_port = 4566
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "floci" {
  metadata {
    name      = "floci"
    namespace = kubernetes_namespace.garage.metadata[0].name
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations]
  }

  spec {
    selector = { app = "floci" }
    port {
      port        = 4566
      target_port = 4566
      node_port   = 30666
    }
    type = "NodePort"
  }
}