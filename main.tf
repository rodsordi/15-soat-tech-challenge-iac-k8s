module "eks_cluster" {
  source                = "./modules/eks-cluster"
  cluster_name          = var.cluster_name
  node_instance_type    = var.node_instance_type
  use_existing_lab_role = var.use_existing_lab_role
}

resource "helm_release" "metrics_server" {
  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  namespace        = "kube-system"
  version          = "3.12.0"
  create_namespace = false

  depends_on = [module.eks_cluster]
}

module "ecr" {
  source = "./modules/ecr"
}

resource "kubernetes_namespace" "garage" {
  depends_on = [module.eks_cluster]

  metadata {
    name = "garage"
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations, metadata[0].labels]
  }
}

module "app_garage" {
  source         = "./modules/app-garage"
  namespace_name = kubernetes_namespace.garage.metadata[0].name
  image_url      = "${module.ecr.repository_url}:latest"
  db_host        = var.db_host
  db_password    = var.db_password
  irsa_role_arn  = module.eks_cluster.irsa_role_arn

  depends_on = [module.eks_cluster, helm_release.metrics_server]
}

module "api_gateway" {
  source             = "./modules/api-gateway"
  cluster_name       = var.cluster_name
  vpc_id             = module.eks_cluster.vpc_id
  subnet_ids         = module.eks_cluster.public_subnet_ids
  security_group_ids = [module.eks_cluster.vpc_link_security_group_id]

  depends_on = [module.eks_cluster, module.app_garage]
}
