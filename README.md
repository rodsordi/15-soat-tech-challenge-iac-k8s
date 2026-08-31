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

## 🎓 Conexão no AWS Learner Lab (AWS Academy)

Este projeto foi preparado para rodar no ambiente **AWS Academy Learner Lab**. Devido às restrições de permissão e tempo de sessão do laboratório, observe os seguintes requisitos:

### 1. Obtenção das Credenciais Temporárias
Toda vez que uma nova sessão do laboratório é iniciada (*Start Lab*), as credenciais temporárias mudam.
1. No console do AWS Learner Lab, clique em **Start Lab** (aguarde o indicador ficar verde).
2. Clique no botão **AWS Details** e selecione **AWS CLI** (link *Show*).
3. Copie as variáveis `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` e `AWS_SESSION_TOKEN`.

### 2. Exportação no Terminal Local
- **PowerShell (Windows)**:
  ```powershell
  $env:AWS_ACCESS_KEY_ID="COPIE_SUA_KEY"
  $env:AWS_SECRET_ACCESS_KEY="COPIE_SUA_SECRET"
  $env:AWS_SESSION_TOKEN="COPIE_SEU_TOKEN"
  $env:AWS_DEFAULT_REGION="us-east-1"
  ```
- **Bash / Linux / macOS**:
  ```bash
  export AWS_ACCESS_KEY_ID="COPIE_SUA_KEY"
  export AWS_SECRET_ACCESS_KEY="COPIE_SUA_SECRET"
  export AWS_SESSION_TOKEN="COPIE_SEU_TOKEN"
  export AWS_DEFAULT_REGION="us-east-1"
  ```

### 3. Restrição de IAM (`LabRole`)
- No Learner Lab, **não é permitido criar novas IAM Roles** (erro `AccessDenied`).
- Por padrão, a variável `use_existing_lab_role = true` reutiliza a IAM Role pré-criada `LabRole`. **Mantenha esta variável ativada (`true`)**.

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

### 🔌 Conectando ao Cluster EKS após o `apply`

Após o `terraform apply`, atualize seu `kubeconfig` local para interagir com o EKS via `kubectl`:

```bash
# Método 1: via AWS CLI
aws eks update-kubeconfig --region us-east-1 --name techchallenge-cluster

# Método 2: via script auxiliar do repositório
source use-kubeconfig.sh
```

Verifique se a conexão está funcionando:
```bash
kubectl get nodes
kubectl get pods -n garage
```

---

## 🤖 Automação via GitHub Actions

O repositório inclui a pipeline automatizada `.github/workflows/terraform.yml`. Configure as seguintes **Repository Secrets**:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN` *(Necessário renovar no GitHub Secrets a cada nova sessão do Learner Lab)*
- `AWS_REGION` (`us-east-1`)
- `DB_HOST` (Endpoint do RDS criado no `iac-db`)
- `DB_PASSWORD` (Senha do banco PostgreSQL)

---

## ⚠️ Preservação do Orçamento do Laboratório (Budget)

> [!CAUTION]
> **ATENÇÃO AO ORÇAMENTO DO LEARNER LAB**:
> - O encerramento do timer da sessão do Learner Lab desliga instâncias EC2, **mas NÃO encerra clusters EKS ou NAT Gateways**. Eles continuarão consumindo seu orçamento de US$ 50/100.
> - Se o orçamento atingir 100%, sua conta AWS do laboratório será **desativada permanentemente** e todo o progresso será perdido.
> - Sempre execute `terraform destroy -auto-approve` ao finalizar os testes do dia.

