resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations, metadata[0].labels]
  }
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = kubernetes_namespace.cert_manager.metadata[0].name
  version    = "v1.13.3"

  set {
    name  = "installCRDs"
    value = "true"
  }
}

resource "helm_release" "nginx_ingress" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "ingress-nginx"
  version    = "4.8.3"
  create_namespace = true

  wait          = false
  timeout       = 300

  set {
    name  = "controller.hostPort.enabled"
    value = "true"
  }

  set {
    name  = "controller.hostPort.ports.https"
    value = "9443"
  }

  set {
    name  = "controller.nodeSelector.ingress-ready"
    value = "true"
    type  = "string"
  }

  set {
    name  = "controller.watchIngressWithoutClass"
    value = "true"
  }

  set {
    name  = "controller.admissionWebhooks.enabled"
    value = "false"
  }
}

resource "kubernetes_namespace" "cattle_system" {
  metadata {
    name = "cattle-system"
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations, metadata[0].labels]
  }
}

resource "helm_release" "rancher" {
  depends_on = [helm_release.cert_manager, helm_release.nginx_ingress]

  name       = "rancher"
  repository = "https://releases.rancher.com/server-charts/stable"
  chart      = "rancher"
  namespace  = kubernetes_namespace.cattle_system.metadata[0].name
  version    = "v2.14.3"

  set {
    name  = "hostname"
    value = "rancher.local.dev"
  }

  set {
    name  = "bootstrapPassword"
    value = "admin"
  }

  set {
    name  = "replicas"
    value = "1"
  }

  set {
    name  = "ingress.tls.source"
    value = "rancher"
  }
}

resource "kubernetes_ingress_v1" "rancher_localhost_bypass" {
  depends_on = [helm_release.rancher]

  metadata {
    name      = "rancher-localhost-bypass"
    namespace = kubernetes_namespace.cattle_system.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"              = "nginx"
      "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
      "nginx.ingress.kubernetes.io/backend-protocol" = "HTTPS"
    }
  }

  spec {
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "rancher"
              port {
                number = 443
              }
            }
          }
        }
      }
    }
  }
}