resource "kind_cluster" "garage_cluster" {
  name            = "cluster-local-dev"
  kubeconfig_path = "${path.module}/cluster-local-dev-config"

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    containerd_config_patches = [
      <<-TOML
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors."kind-registry:5000"]
        endpoint = ["http://kind-registry:5000"]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:5001"]
        endpoint = ["http://kind-registry:5000"]
      TOML
    ]

    node {
      role = "control-plane"

      labels = {
        "ingress-ready" = "true"
      }

      extra_port_mappings {
        container_port = 9443
        host_port      = 9443
      }

      extra_port_mappings {
        container_port = 30300 # grafana
        host_port      = 3000
      }
      extra_port_mappings {
        container_port = 30909 # prometheus
        host_port      = 9090
      }
      extra_port_mappings {
        container_port = 31686 # jaeger UI
        host_port      = 16686
      }
      extra_port_mappings {
        container_port = 30900 # sonarqube
        host_port      = 9000
      }
      extra_port_mappings {
        container_port = 30080 # api-garage
        host_port      = 8080
      }

      extra_mounts {
        host_path      = var.owasp_cache_host_path
        container_path = "/var/owasp-cache-in-node"
      }
    }
  }

  depends_on = [
    docker_container.kind_registry
  ]
}

resource "null_resource" "kind_registry_cleanup" {
  provisioner "local-exec" {
    command = "docker rm -f kind-registry 2>/dev/null || true"
  }
}

resource "docker_container" "kind_registry" {
  depends_on = [null_resource.kind_registry_cleanup]

  name     = "kind-registry"
  image    = "registry:2"
  start    = true
  must_run = true

  ports {
    internal = 5000
    external = 5001
  }

  networks_advanced {
    name = "kind"
  }

  restart = "unless-stopped"
}

resource "kubernetes_config_map" "local_registry_hosting" {
  metadata {
    name      = "local-registry-hosting"
    namespace = "kube-public"
  }

  data = {
    "localRegistryHosting.v1" = <<-EOF
      host: "localhost:5001"
      help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
    EOF
  }

  depends_on = [kind_cluster.garage_cluster]
}