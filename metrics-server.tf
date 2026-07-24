resource "null_resource" "metrics_server" {
  depends_on = [kind_cluster.garage_cluster]

  triggers = {
    cluster = kind_cluster.garage_cluster.id
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]

    command = <<-EOT
      set -eo pipefail
      export MSYS_NO_PATHCONV=1
      export KUBECONFIG="${replace(kind_cluster.garage_cluster.kubeconfig_path, "\\", "/")}"

      kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

      # kind's kubelet certs aren't valid for the hostnames metrics-server expects; required for it to reach kubelets.
      kubectl -n kube-system patch deployment metrics-server --type=json \
        -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

      kubectl -n kube-system rollout status deployment/metrics-server --timeout=120s

      for i in {1..30}; do
        status=$(kubectl get apiservice v1beta1.metrics.k8s.io -o jsonpath='{.status.conditions[0].status}' 2>/dev/null || true)
        [ "$status" = "True" ] && break
        sleep 5
      done
    EOT
  }
}
