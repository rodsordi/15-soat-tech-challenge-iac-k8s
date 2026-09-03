# 🚀 Infraestrutura EKS, Rede & API Gateway (`15-soat-tech-challenge-iac-k8s`)

Repositório central de **Infraestrutura como Código (IaC)** responsável por provisionar a rede VPC Multi-AZ, o cluster gerenciado **AWS EKS**, o servidor de identidade **Keycloak**, o repositório de contêineres **AWS ECR** e o ponto único de entrada público via **AWS API Gateway**.

---

## 🎯 1. Descrição do Propósito

Este repositório estabelece a fundação de nuvem e orquestração de contêineres para todo o ecossistema do Tech Challenge:
* **Isolamento e Segurança de Rede**: Criação de VPC com subnets públicas e privadas, NAT Gateway para saída controlada à internet e grupos de segurança restritivos.
* **Orquestração de Microsserviços**: Provisionamento do cluster gerenciado **AWS EKS** com autoscaling de nós e Horizontal Pod Autoscaler (HPA).
* **Ponto Único de Entrada (Single Entrypoint)**: Exposição segura das APIs internas através do **AWS API Gateway (HTTP API v2)** integrado via **VPC Link** ao **Network Load Balancer (NLB) interno** da AWS.
* **Gestão de Identidades no Cluster**: Execução do **Keycloak 24** dentro do Kubernetes em modo seguro para fornecer autenticação OIDC à Lambda e aos microsserviços.
* **Repositório de Imagens**: Criação do **AWS ECR** (`garage-api`) com criptografia e varredura de vulnerabilidades contínua.

---

## 💻 2. Tecnologias Utilizadas

* **Infraestrutura como Código**: Terraform 1.6+ (com HCL modularizado em `modules/`).
* **Cloud Provider**: Amazon Web Services (AWS) no ambiente **AWS Academy Learner Lab**.
* **Orquestração de Contêineres**: AWS Elastic Kubernetes Service (EKS v1.29) com Managed Node Groups (`t3.small`).
* **Rede & Tráfego AWS**: AWS VPC, Internet Gateway, Elastic IP, NAT Gateway, AWS Network Load Balancer (NLB) interno e AWS API Gateway HTTP v2 com VPC Link.
* **Gerenciamento de Pacotes K8s**: Helm 3 (Helm Release para o `metrics-server`).
* **Gestão de Identidade & Acesso**: Keycloak 24.0.5, OpenID Connect (OIDC), OAuth2 e AWS IAM Role (`LabRole`).
* **Registro de Imagens**: Amazon Elastic Container Registry (ECR).
* **Automação de CI/CD**: GitHub Actions com runners `ubuntu-latest`.

---

## 🏛️ 3. Diagrama da Arquitetura do Repositório

```mermaid
graph TD
    Client([Usuário / Frontend / Postman]) -->|HTTPS:443| ApiGateway[AWS API Gateway HTTP API v2]
    
    subgraph AWS_VPC [AWS VPC 10.0.0.0/16 Multi-AZ]
        subgraph PublicSubnets [Subnets Públicas - 10.0.1.0/24 e 10.0.2.0/24]
            VpcLink[VPC Link Endpoint]
            NATGW[NAT Gateway]
            IGW[Internet Gateway]
        end
        
        ApiGateway -->|Roteia tráfego| VpcLink
        
        subgraph PrivateSubnets [Subnets Privadas - 10.0.10.0/24 e 10.0.20.0/24]
            InternalNLB[AWS NLB Interno :8080]
            
            subgraph EKSCluster [Cluster AWS EKS techchallenge-cluster]
                subgraph NamespaceGarage [Namespace: garage]
                    AppService[Service api-garage]
                    AppPods[Pods api-garage Spring Boot]
                    KeycloakService[Service keycloak ClusterIP :8080]
                    KeycloakPods[Pod Keycloak OIDC]
                    HPAScaler[Horizontal Pod Autoscaler]
                end
                
                MetricsServer[Metrics Server Pod]
            end
        end
        
        VpcLink -->|Listener ARN :8080| InternalNLB
        InternalNLB --> AppService
        AppService --> AppPods
        HPAScaler -.->|Monitora CPU| AppPods
        PrivateSubnets -->|Saída à Internet| NATGW
        NATGW --> IGW
    end

    ECR[AWS ECR garage-api] -.->|Pull de Imagens| AppPods
```

---

## ⚙️ 4. Governança e Execução: Pipeline GitHub Actions (Obrigatório)

> [!IMPORTANT]
> **POLÍTICA DE GOVERNANÇA DE DEVSECOPS: PROIBIDO APPLY MANUAL VIA PROMPT LOCAL**
> Para garantir rastreabilidade, auditoria, consistência de estado e conformidade de segurança, **nenhum membro da equipe deve executar `terraform apply` a partir do terminal local**. Todos os provisionamentos, alterações de infraestrutura e destituições devem ser executados exclusivamente através da **Pipeline de CI/CD do GitHub Actions**.

---

### 4.1. Configuração de Credenciais no GitHub Actions

Antes de disparar o pipeline, atualize as credenciais temporárias do **AWS Academy Learner Lab** no GitHub:

1. No painel do **AWS Academy**, inicie o laboratório (*Start Lab*).
2. Clique em **AWS Details** ➔ **AWS CLI** (*Show*) e copie os valores.
3. Atualize os **Secrets** do repositório no GitHub (*Settings > Secrets and variables > Actions*):
   * `AWS_ACCESS_KEY_ID`: Sua Access Key do laboratório.
   * `AWS_SECRET_ACCESS_KEY`: Sua Secret Key do laboratório.
   * `AWS_SESSION_TOKEN`: Seu Session Token temporário.
   * `DB_PASSWORD`: Senha mestra do banco de dados RDS.
   * `NEWRELIC_LICENSE_KEY`: Ingest License Key do New Relic.
   * `NEWRELIC_API_KEY`: User API Key do New Relic.

> 💡 **Dica de Produtividade**: Você também pode atualizar as credenciais AWS via GitHub CLI no seu terminal:
> ```bash
> gh secret set AWS_ACCESS_KEY_ID --body "SUA_KEY"
> gh secret set AWS_SECRET_ACCESS_KEY --body "SUA_SECRET"
> gh secret set AWS_SESSION_TOKEN --body "SEU_TOKEN"
> ```

---

### 4.2. Como Disparar o Deploy via GitHub Actions

#### Opção A: Execução Manual Controlada (Recomendado para Avaliações)
Você pode disparar qualquer ação (`plan`, `apply` ou `destroy`) diretamente pelo GitHub:

1. **Via Interface Web**:
   - Acesse a aba **Actions** do repositório no GitHub.
   - Selecione o workflow **Terraform EKS & App CI/CD Pipeline**.
   - Clique em **Run workflow**, selecione a branch `main` e escolha a ação desejada:
     - `apply`: Provisiona e atualiza toda a infraestrutura, workloads e observabilidade.
     - `plan`: Executa validação e gera o plano de execução sem alterar a nuvem.
     - `destroy`: Descomissiona todos os recursos criados para evitar custos.

2. **Via GitHub CLI (Sem abrir o navegador)**:
   ```bash
   # Executar Apply completo da infraestrutura
   gh workflow run terraform.yml -f action=apply

   # Apenas gerar o Plan
   gh workflow run terraform.yml -f action=plan

   # Acompanhar a execução em tempo real no terminal
   gh run watch
   ```

#### Opção B: Ciclo Automatizado de GitOps (Pull Request & Merge)
* **Pull Request (PR)** para `main`: Executa automaticamente `terraform fmt -check`, `terraform init`, `terraform validate` e `terraform plan`.
* **Merge na branch `main`**: Executa automaticamente o `terraform apply -auto-approve`, aplicando as alterações no cluster EKS.

---

### 4.3. Conectar ao Cluster via Kubeconfig (Apenas Consulta e Validação)

Após a conclusão com sucesso do job de `apply` no GitHub Actions, conecte-se ao cluster localmente para fins de inspeção:

```bash
# 1. Atualizar contexto local do kubectl
aws eks update-kubeconfig --region us-east-1 --name techchallenge-cluster

# 2. Verificar nós operacionais
kubectl get nodes

# 3. Verificar pods da aplicação e da observabilidade New Relic
kubectl get pods -n garage
kubectl get pods -n newrelic
```

---

## 📊 5. Observabilidade Integrada com New Relic

A observabilidade do cluster e da aplicação foi modernizada e unificada no **New Relic**, provisionada 100% como código (IaC):

* **Agente de Infraestrutura Kubernetes (`nri-bundle`)**:
  - DaemonSets `nri-infrastructure` e `newrelic-logging` coletando métricas de nós/pods e logs estruturados em JSON assincronamente.
* **OpenTelemetry APM Nativo**:
  - A API `api-garage` envia métricas e traces via protocolo OTLP diretamente para a New Relic com correlação de logs (*Logs in Context* com `trace.id` e `span.id`).
* **Dashboards Pré-Planejados em Código**:
  - `API Garage - Ordens de Serviço & Negócio`: Volume diário de ordens criadas, tempo médio de execução por status (`DIAGNOSING`, `EXECUTING`, `FINISHED`) e taxa de sucesso/falha.
  - `API Garage - Infraestrutura, Latência & Integrações`: Latência p95/p99 por rota, falhas de integrações (Postgres / AWS SQS), consumo de CPU/Memória K8s e Uptime de Pods.
* **Alertas Inteligentes**:
  - Incidentes disparados para falhas > 1% em ordens de serviço, exceções de mensageria SQS, banco de dados ou pods com status `isReady = 0`.

---

## 📑 6. Link para o Swagger e Postman das APIs

Como este repositório provisiona o **AWS API Gateway**, ele é a porta de entrada oficial da aplicação na nuvem:

### 🌐 Endpoints do Swagger / OpenAPI na Nuvem:
* **Swagger UI Oficial**: 
  ```
  https://igqc9vtfx9.execute-api.us-east-1.amazonaws.com/api/swagger-ui/index.html
  ```
* **OpenAPI 3 JSON Spec**: 
  ```
  https://igqc9vtfx9.execute-api.us-east-1.amazonaws.com/api/v3/api-docs
  ```

### 📬 Testes Rápidos via Postman / cURL:

```bash
# 1. Testar conexão através do API Gateway
curl -i --location 'https://igqc9vtfx9.execute-api.us-east-1.amazonaws.com/api/actuator/health'

# 2. Keycloak Endpoint Interno (via Pod no cluster):
# URL: http://keycloak.garage.svc.cluster.local:8080/realms/garage/.well-known/openid-configuration
```

