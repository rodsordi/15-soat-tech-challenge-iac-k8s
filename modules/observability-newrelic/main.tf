terraform {
  required_providers {
    newrelic = {
      source  = "newrelic/newrelic"
      version = "~> 3.40"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12.0"
    }
  }
}

resource "kubernetes_namespace" "newrelic" {
  metadata {
    name = var.namespace_name
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations, metadata[0].labels]
  }
}


resource "helm_release" "newrelic_bundle" {
  name             = "newrelic-bundle"
  repository       = "https://helm-charts.newrelic.com"
  chart            = "nri-bundle"
  version          = "5.0.3"
  namespace        = kubernetes_namespace.newrelic.metadata[0].name
  create_namespace = false

  set_sensitive {
    name  = "global.licenseKey"
    value = var.newrelic_license_key
  }

  set {
    name  = "global.cluster"
    value = var.cluster_name
  }

  set {
    name  = "global.lowDataMode"
    value = "false"
  }

  # DaemonSet de Infraestrutura nos Nós (Node & Pod metrics)
  set {
    name  = "newrelic-infrastructure.enabled"
    value = "true"
  }

  set {
    name  = "newrelic-infrastructure.resources.limits.cpu"
    value = "150m"
  }

  set {
    name  = "newrelic-infrastructure.resources.limits.memory"
    value = "256Mi"
  }

  set {
    name  = "newrelic-infrastructure.resources.requests.cpu"
    value = "30m"
  }

  set {
    name  = "newrelic-infrastructure.resources.requests.memory"
    value = "64Mi"
  }

  # Coleta de Logs via Fluent Bit (lê /var/log/pods no nó assincronamente)
  set {
    name  = "newrelic-logging.enabled"
    value = "true"
  }

  set {
    name  = "newrelic-logging.resources.limits.cpu"
    value = "100m"
  }

  set {
    name  = "newrelic-logging.resources.limits.memory"
    value = "128Mi"
  }

  set {
    name  = "newrelic-logging.resources.requests.cpu"
    value = "20m"
  }

  set {
    name  = "newrelic-logging.resources.requests.memory"
    value = "48Mi"
  }

  # Eventos de Ciclo de Vida do Kubernetes (OOMKill, Evictions, Restarts)
  set {
    name  = "nri-kube-events.enabled"
    value = "true"
  }

  # Desativação de componentes desnecessários para preservar recursos (FinOps)
  # A aplicação envia métricas OTLP diretamente via push; scraper redundante desativado
  set {
    name  = "nri-prometheus.enabled"
    value = "false"
  }

  # Pixie eBPF desativado para evitar sobrecarga de memória e requisitos de privilégios elevados
  set {
    name  = "newrelic-pixie.enabled"
    value = "false"
  }

  set {
    name  = "pixie-chart.enabled"
    value = "false"
  }

  depends_on = [kubernetes_namespace.newrelic]
}
