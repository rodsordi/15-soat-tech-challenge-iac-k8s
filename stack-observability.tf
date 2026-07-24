resource "kubernetes_service_account" "kube_state_metrics" {
  metadata {
    name      = "kube-state-metrics"
    namespace = kubernetes_namespace.garage.metadata[0].name
  }
}

resource "kubernetes_cluster_role" "kube_state_metrics" {
  metadata {
    name = "kube-state-metrics"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "nodes", "namespaces"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["autoscaling"]
    resources  = ["horizontalpodautoscalers"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "kube_state_metrics" {
  metadata {
    name = "kube-state-metrics-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.kube_state_metrics.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.kube_state_metrics.metadata[0].name
    namespace = kubernetes_service_account.kube_state_metrics.metadata[0].namespace
  }
}

resource "kubernetes_deployment" "kube_state_metrics" {
  metadata {
    name      = "kube-state-metrics"
    namespace = kubernetes_namespace.garage.metadata[0].name
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "kube-state-metrics" } }

    template {
      metadata { labels = { app = "kube-state-metrics" } }
      spec {
        service_account_name = kubernetes_service_account.kube_state_metrics.metadata[0].name

        container {
          name  = "kube-state-metrics"
          image = "registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.13.0"

          args = [
            "--resources=pods,deployments,replicasets,horizontalpodautoscalers",
          ]

          port {
            container_port = 8080
            name           = "metrics"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "kube_state_metrics" {
  metadata {
    name      = "kube-state-metrics"
    namespace = kubernetes_namespace.garage.metadata[0].name
  }

  spec {
    selector = { app = "kube-state-metrics" }

    port {
      port        = 8080
      target_port = 8080
    }
  }
}

resource "kubernetes_deployment" "loki" {
  metadata {
    name      = "loki"
    namespace = kubernetes_namespace.garage.metadata[0].name
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations]
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "loki" } }

    template {
      metadata { labels = { app = "loki" } }
      spec {
        container {
          name  = "loki"
          image = "grafana/loki:latest"

          port {
            container_port = 3100
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "loki" {
  metadata {
    name      = "loki"
    namespace = kubernetes_namespace.garage.metadata[0].name
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations]
  }

  spec {
    selector = { app = "loki" }

    port {
      port        = 3100
      target_port = 3100
      node_port   = 30310
    }

    type = "NodePort"
  }
}

resource "kubernetes_deployment" "jaeger" {
  metadata {
    name      = "jaeger"
    namespace = kubernetes_namespace.garage.metadata[0].name
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations]
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "jaeger" } }

    template {
      metadata { labels = { app = "jaeger" } }
      spec {
        container {
          name  = "jaeger"
          image = "jaegertracing/all-in-one:latest"

          port {
            container_port = 16686
          }

          port {
            container_port = 4317
          }

          port {
            container_port = 4318
          }

          env {
            name  = "COLLECTOR_OTLP_ENABLED"
            value = "true"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "jaeger" {
  metadata {
    name      = "jaeger"
    namespace = kubernetes_namespace.garage.metadata[0].name
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations]
  }

  spec {
    selector = { app = "jaeger" }

    port {
      name        = "ui"
      port        = 16686
      target_port = 16686
      node_port   = 31686
    }

    port {
      name        = "otlp-grpc"
      port        = 4317
      target_port = 4317
      node_port   = 31717
    }

    port {
      name        = "otlp-http"
      port        = 4318
      target_port = 4318
      node_port   = 31718
    }

    type = "NodePort"
  }
}

resource "kubernetes_config_map" "prometheus_config" {
  metadata {
    name      = "prometheus-config"
    namespace = kubernetes_namespace.garage.metadata[0].name
  }

  data = {
    "prometheus.yml" = file("${path.module}/prometheus/prometheus.yml")
  }
}

resource "kubernetes_deployment" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.garage.metadata[0].name
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations]
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "prometheus" } }

    template {
      metadata { labels = { app = "prometheus" } }
      spec {
        container {
          name  = "prometheus"
          image = "prom/prometheus:latest"

          args = [
            "--config.file=/etc/prometheus/prometheus.yml",
            "--web.enable-otlp-receiver",
          ]

          port {
            container_port = 9090
          }

          volume_mount {
            name       = "prometheus-config"
            mount_path = "/etc/prometheus/prometheus.yml"
            sub_path   = "prometheus.yml"
          }
        }

        volume {
          name = "prometheus-config"
          config_map {
            name = kubernetes_config_map.prometheus_config.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.garage.metadata[0].name
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations]
  }

  spec {
    selector = { app = "prometheus" }

    port {
      port        = 9090
      target_port = 9090
      node_port   = 30909
    }

    type = "NodePort"
  }
}

resource "kubernetes_config_map" "grafana_provisioning" {
  metadata {
    name      = "grafana-provisioning"
    namespace = kubernetes_namespace.garage.metadata[0].name
  }

  data = {
    "datasources-jaeger.yml"     = file("${path.module}/grafana/provisioning/datasources/jaeger.yml")
    "datasources-loki.yml"       = file("${path.module}/grafana/provisioning/datasources/loki.yml")
    "datasources-prometheus.yml" = file("${path.module}/grafana/provisioning/datasources/prometheus.yml")
    "dashboards-provider.yml"    = file("${path.module}/grafana/provisioning/dashboards/dashboards.yml")
  }
}

resource "kubernetes_config_map" "grafana_dashboards_json" {
  metadata {
    name      = "grafana-dashboards-json"
    namespace = kubernetes_namespace.garage.metadata[0].name
  }

  data = {
    "jaeger-traces.json"      = file("${path.module}/grafana/provisioning/dashboards/json/jaeger-traces.json")
    "loki-metrics.json"       = file("${path.module}/grafana/provisioning/dashboards/json/loki-metrics.json")
    "prometheus-metrics.json" = file("${path.module}/grafana/provisioning/dashboards/json/prometheus-metrics.json")
    "hpa-scaling.json"        = file("${path.module}/grafana/provisioning/dashboards/json/hpa-scaling.json")
  }
}

resource "kubernetes_deployment" "grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.garage.metadata[0].name
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations]
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "grafana" } }

    template {
      metadata { labels = { app = "grafana" } }
      spec {
        container {
          name  = "grafana"
          image = "grafana/grafana:latest"

          port {
            container_port = 3000
          }

          env {
            name  = "GF_AUTH_ANONYMOUS_ENABLED"
            value = "true"
          }
          env {
            name  = "GF_AUTH_ANONYMOUS_ORG_ROLE"
            value = "Admin"
          }

          volume_mount {
            name       = "grafana-provisioning"
            mount_path = "/etc/grafana/provisioning/datasources/jaeger.yml"
            sub_path   = "datasources-jaeger.yml"
          }
          volume_mount {
            name       = "grafana-provisioning"
            mount_path = "/etc/grafana/provisioning/datasources/loki.yml"
            sub_path   = "datasources-loki.yml"
          }
          volume_mount {
            name       = "grafana-provisioning"
            mount_path = "/etc/grafana/provisioning/datasources/prometheus.yml"
            sub_path   = "datasources-prometheus.yml"
          }
          volume_mount {
            name       = "grafana-provisioning"
            mount_path = "/etc/grafana/provisioning/dashboards/dashboards.yml"
            sub_path   = "dashboards-provider.yml"
          }
          volume_mount {
            name       = "grafana-dashboards-json"
            mount_path = "/etc/grafana/provisioning/dashboards/json/jaeger-traces.json"
            sub_path   = "jaeger-traces.json"
          }
          volume_mount {
            name       = "grafana-dashboards-json"
            mount_path = "/etc/grafana/provisioning/dashboards/json/loki-metrics.json"
            sub_path   = "loki-metrics.json"
          }
          volume_mount {
            name       = "grafana-dashboards-json"
            mount_path = "/etc/grafana/provisioning/dashboards/json/prometheus-metrics.json"
            sub_path   = "prometheus-metrics.json"
          }
          volume_mount {
            name       = "grafana-dashboards-json"
            mount_path = "/etc/grafana/provisioning/dashboards/json/hpa-scaling.json"
            sub_path   = "hpa-scaling.json"
          }
        }

        volume {
          name = "grafana-provisioning"
          config_map {
            name = kubernetes_config_map.grafana_provisioning.metadata[0].name
          }
        }
        volume {
          name = "grafana-dashboards-json"
          config_map {
            name = kubernetes_config_map.grafana_dashboards_json.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.garage.metadata[0].name
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations]
  }

  spec {
    selector = { app = "grafana" }

    port {
      port        = 3000
      target_port = 3000
      node_port   = 30300
    }

    type = "NodePort"
  }
}
