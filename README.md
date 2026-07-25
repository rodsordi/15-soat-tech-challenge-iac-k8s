# 🚀 IaC EKS & Java Application (`15-soat-tech-challenge-iac-k8s`)

Este repositório contém o código Terraform modularizado para provisionamento do cluster **AWS EKS**, infraestrutura de rede segura, **AWS API Gateway**, **AWS ECR** e implantação da **Aplicação Java (`api-garage`)**.

---

## 🏛️ Arquitetura de Rede e Segurança

```
Usuário (Internet) ➔ AWS API Gateway (HTTP) ➔ VPC Link ➔ EKS Ingress ➔ Serviço ClusterIP ➔ Pod Java (Subnet Privada) ➔ AWS RDS PostgreSQL
```

- **Ponto Único de Entrada**: AWS API Gateway público via VPC Link.
- **Isolamento de Nós**: Nós do EKS executados exclusivamente em **Subnets Privadas**.
- **Restrição de Portas**: Serviço Kubernetes configurado como `ClusterIP` (sem portas públicas no Pod).
- **ServiceAccount & IRSA**: Autenticação via IAM Roles for Service Accounts (`api-garage-sa`).
- **Autoscaling (HPA)**: Mapeado autoscale de 2 a 5 pods por utilização de CPU (70%).

---

## 🛠️ Módulos do Terraform (`modules/`)

| Módulo | Descrição |
| :--- | :--- |
| **`modules/eks-cluster`** | VPC Multi-AZ, Subnets Públicas/Privadas, NAT Gateway, Roles do IAM (AWS Academy `LabRole`) e EKS Managed Node Group (`t3.small`). |
| **`modules/api-gateway`** | HTTP API Gateway com VPC Link roteando solicitações públicas para o cluster interno. |
| **`modules/ecr`** | Repositório AWS ECR (`garage-api`) para armazenamento das imagens Docker com scan-on-push ativo. |
| **`modules/app-garage`** | Deployment Spring Boot, ServiceAccount com IRSA, Kubernetes Secret para DB, HPA e Ingress. |

---

## ⚙️ Execução Local do Terraform

```bash
terraform init
terraform plan -var-file="terraform.tfvars.example"
terraform apply -auto-approve
```

---

## 🤖 Automação via GitHub Actions

O repositório inclui a pipeline automatizada `.github/workflows/terraform.yml`. Configure as seguintes **Repository Secrets**:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN` (Necessário para a AWS Academy)
- `AWS_REGION` (`us-east-1`)
- `DB_HOST` (Endpoint do RDS criado no `iac-db`)
- `DB_PASSWORD` (Senha do banco PostgreSQL)
