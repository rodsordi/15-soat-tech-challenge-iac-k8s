resource "kubernetes_service_account" "github_runner_sa" {
  depends_on = [kind_cluster.garage_cluster]

  metadata {
    name      = "github-runner-sa"
    namespace = kubernetes_namespace.garage.metadata[0].name
  }
}

resource "kubernetes_cluster_role_binding" "github_runner_admin" {
  depends_on = [kubernetes_service_account.github_runner_sa]

  metadata {
    name = "github-runner-admin-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.github_runner_sa.metadata[0].name
    namespace = kubernetes_service_account.github_runner_sa.metadata[0].namespace
  }
}

resource "null_resource" "build_and_load_image" {
  depends_on = [
    kind_cluster.garage_cluster
  ]

  triggers = {
    dockerfile_hash = filesha256("${path.module}/Dockerfile-runner")
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]

    command = <<-EOT
      set -e
      export MSYS_NO_PATHCONV=1
      docker build --network host -t custom-runner:latest -f "${path.module}/Dockerfile-runner" "${path.module}"
      docker save -o custom-runner.tar custom-runner:latest
      docker cp custom-runner.tar cluster-local-dev-control-plane:/custom-runner.tar
      docker exec cluster-local-dev-control-plane ctr -n k8s.io images import /custom-runner.tar
      rm -f custom-runner.tar
    EOT
  }
}

resource "kubernetes_deployment" "github_runner" {
  depends_on = [
    null_resource.build_and_load_image,
    kubernetes_cluster_role_binding.github_runner_admin
  ]

  metadata {
    name      = "github-runner"
    namespace = kubernetes_namespace.garage.metadata[0].name
  }

  spec {
    replicas = 2
    selector { match_labels = { app = "github-runner" } }

    template {
      metadata { labels = { app = "github-runner" } }
      spec {
        service_account_name = kubernetes_service_account.github_runner_sa.metadata[0].name

        host_aliases {
          ip        = docker_container.kind_registry.network_data[0].ip_address
          hostnames = ["kind-registry"]
        }

        container {
          name              = "github-runner"
          image             = "custom-runner:latest"
          image_pull_policy = "Never"

          env {
            name  = "REPO_URL"
            value = "https://github.com/rodsordi/15SOAT-TechChallenge"
          }
          env {
            name = "RUNNER_NAME"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }
          env {
            name  = "ACCESS_TOKEN"
            value = var.github_pat
          }
          env {
            name  = "LABELS"
            value = "local,k8s,kind"
          }
          env {
            name  = "DOCKER_HOST"
            value = "tcp://localhost:2375"
          }
          env {
            name  = "RUN_AS_ROOT"
            value = "true"
          }
          env {
            name  = "SONAR_TOKEN"
            value = sensitive(trimspace(data.local_file.sonar_token.content))
          }

          env {
            name  = "NVD_API_KEY"
            value = var.NVD_API_KEY
          }

          volume_mount {
            name       = "owasp-cache"
            mount_path = "/root/.owasp/dependency-check/data"
          }

          volume_mount {
            name       = "containerd-sock"
            mount_path = "/run/containerd/containerd.sock"
          }

          security_context {
            privileged = true
          }
        }

        container {
          name  = "dind"
          image = "docker:27-dind"
          args  = [
            "--host=tcp://0.0.0.0:2375",
            "--host=unix:///var/run/docker.sock",
            "--insecure-registry=kind-registry:5000"
          ]

          env {
            name  = "DOCKER_TLS_CERTDIR"
            value = ""
          }

          port {
            container_port = 2375
          }

          security_context {
            privileged = true
          }
        }

        volume {
          name = "containerd-sock"

          host_path {
            path = "/run/containerd/containerd.sock"
            type = "Socket"
          }
        }

        volume {
          name = "owasp-cache"

          host_path {
            path = "/var/owasp-cache-in-node"
            type = "DirectoryOrCreate"
          }
        }
      }
    }
  }
}

resource "kubernetes_deployment" "sonarqube" {
  metadata {
    name      = "sonarqube"
    namespace = kubernetes_namespace.garage.metadata[0].name
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations]
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "sonarqube" } }

    template {
      metadata { labels = { app = "sonarqube" } }
      spec {
        init_container {
          name    = "fix-volume-permissions"
          image   = "busybox:1.36"
          command = ["sh", "-c", "chown -R 1000:1000 /opt/sonarqube/data /opt/sonarqube/extensions"]

          security_context {
            run_as_user = 0
          }

          volume_mount {
            name       = "sonarqube-data"
            mount_path = "/opt/sonarqube/data"
          }

          volume_mount {
            name       = "sonarqube-extensions"
            mount_path = "/opt/sonarqube/extensions"
          }
        }

        container {
          name  = "sonarqube"
          image = "sonarqube:community"

          port {
            container_port = 9000
          }

          env {
            name  = "SONAR_ES_BOOTSTRAP_CHECKS_DISABLE"
            value = "true"
          }

          volume_mount {
            name       = "sonarqube-data"
            mount_path = "/opt/sonarqube/data"
          }

          volume_mount {
            name       = "sonarqube-extensions"
            mount_path = "/opt/sonarqube/extensions"
          }
        }

        volume {
          name = "sonarqube-data"

          host_path {
            path = "${var.sonar_data_host_path}/data"
            type = "DirectoryOrCreate"
          }
        }

        volume {
          name = "sonarqube-extensions"

          host_path {
            path = "${var.sonar_data_host_path}/extensions"
            type = "DirectoryOrCreate"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "sonarqube" {
  metadata {
    name      = "sonarqube"
    namespace = kubernetes_namespace.garage.metadata[0].name
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations]
  }

  spec {
    selector = { app = "sonarqube" }
    port {
      port        = 9000
      target_port = 9000
      node_port   = 30900
    }
    type = "NodePort"
  }
}

resource "null_resource" "sonar_setup" {
  depends_on = [kubernetes_deployment.sonarqube, kubernetes_service.sonarqube]

  triggers = {
    password_hash = sha256(var.sonar_admin_password)
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]

    command = <<-EOT
      set -eo pipefail
      export MSYS_NO_PATHCONV=1
      export KUBECONFIG="${replace(kind_cluster.garage_cluster.kubeconfig_path, "\\", "/")}"

      # Port-forward com auto-recuperação
      kubectl -n garage port-forward svc/sonarqube 19000:9000 >/dev/null 2>&1 &
      disown
      trap 'kill -9 $! 2>/dev/null || true' EXIT

      # Aguarda SonarQube ficar UP (com timeouts para resiliência)
      for i in {1..100}; do
        curl -s -m 5 --connect-timeout 2 http://127.0.0.1:19000/api/system/status | grep -q '"status":"UP"' && break
        kill -0 $! 2>/dev/null || { kubectl -n garage port-forward svc/sonarqube 19000:9000 >/dev/null 2>&1 & disown; }
        sleep 3
      done

      # Altera senha e revoga token anterior (ignora erros e evita travar)
      curl -s -m 10 --connect-timeout 3 -u admin:admin -X POST "http://127.0.0.1:19000/api/users/change_password?login=admin&previousPassword=admin&password=${var.sonar_admin_password}" >/dev/null || true
      curl -s -m 10 --connect-timeout 3 -u "admin:${var.sonar_admin_password}" -X POST "http://127.0.0.1:19000/api/user_tokens/revoke?name=terraform-token" >/dev/null || true

      # Gera o novo token e finaliza o port-forward para evitar travamentos do shell/pipes
      TOKEN=$(curl -s -m 10 --connect-timeout 3 -u "admin:${var.sonar_admin_password}" -X POST "http://127.0.0.1:19000/api/user_tokens/generate?name=terraform-token" | grep -o '"token":"[^"]*' | cut -d'"' -f4 || true)
      kill -9 $! 2>/dev/null || true  # Força o encerramento do kubectl port-forward em background
      [ -n "$TOKEN" ] || { echo "Falha ao obter token do SonarQube" >&2; exit 1; }
      echo -n "$TOKEN" > "${path.module}/.sonar_token"
    EOT
  }
}

data "local_file" "sonar_token" {
  depends_on = [null_resource.sonar_setup]
  filename   = "${path.module}/.sonar_token"
}

output "sonar_token" {
  description = "Token gerado via API do SonarQube (usar em SONAR_TOKEN / mvn -Dsonar.token)."
  value       = trimspace(data.local_file.sonar_token.content)
  sensitive   = true
}

