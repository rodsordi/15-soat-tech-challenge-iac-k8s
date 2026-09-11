# 🚀 Infraestrutura EKS, Rede & API Gateway (`15-soat-tech-challenge-iac-k8s`)

Repositório central de **Infraestrutura como Código (IaC)** responsável por provisionar a rede VPC Multi-AZ, o cluster gerenciado **AWS EKS**, o servidor de identidade **Keycloak**, o repositório de contêineres **AWS ECR** e o ponto único de entrada público via **AWS API Gateway**.

---

## 🎯 1. Descrição do Propósito

Este repositório estabelece a fundação de nuvem e orquestração de contêineres para todo o ecossistema do Tech Challenge:
* **Isolamento e Segurança de Rede**: Criação de VPC com subnets públicas e privadas, NAT Gateway para saída controlada à internet e grupos de segurança restritivos.
* **Orquestração de Microsserviços**: Provisionamento do cluster gerenciado **AWS EKS** com autoscaling de nós e Horizontal Pod Autoscaler (HPA).
* **Mensageria Assíncrona & Event-Driven**: Provisionamento de **Amazon SNS** e **Amazon SQS** com Dead Letter Queue (DLQ), política de redrive e subscrição fanout gerenciada via módulo `modules/messaging`.
* **Armazenamento de Estado Remoto (Amazon S3)**: Persistência centralizada e segura do estado do Terraform (`k8s/terraform.tfstate`) no bucket `techchallenge-fiap-tfstate-890958457263` com versionamento ativo e auto-provisionamento resiliente no CI/CD.
* **Ponto Único de Entrada (Single Entrypoint)**: Exposição segura das APIs internas através do **AWS API Gateway (HTTP API v2)** integrado via **VPC Link** ao **Network Load Balancer (NLB) interno** da AWS.
* **Gestão de Identidades no Cluster**: Execução do **Keycloak 24** dentro do Kubernetes em modo seguro para fornecer autenticação OIDC à Lambda e aos microsserviços.
* **Repositório de Imagens**: Criação do **AWS ECR** (`garage-api`) com criptografia e varredura de vulnerabilidades contínua.

---

## 💻 2. Tecnologias Utilizadas

* **Infraestrutura como Código**: Terraform 1.6+ (com HCL modularizado em `modules/`).
* **Cloud Provider**: Amazon Web Services (AWS) no ambiente **AWS Academy Learner Lab**.
* **Orquestração de Contêineres**: AWS Elastic Kubernetes Service (EKS v1.29) com Managed Node Groups (`t3.small`).
* **Mensageria Assíncrona**: Amazon Simple Notification Service (SNS) e Amazon Simple Queue Service (SQS) com DLQ.
* **Armazenamento em Nuvem & Backend**: Amazon Simple Storage Service (S3) com versionamento habilitado para isolamento e governança de estado (`tfstate`).
* **Rede & Tráfego AWS**: AWS VPC, Internet Gateway, Elastic IP, NAT Gateway, AWS Network Load Balancer (NLB) interno e AWS API Gateway HTTP v2 com VPC Link.
* **Gerenciamento de Pacotes K8s**: Helm 3 (Helm Release para o `metrics-server`).
* **Gestão de Identidade & Acesso**: Keycloak 24.0.5, OpenID Connect (OIDC), OAuth2 e AWS IAM Role (`LabRole`).
* **Registro de Imagens**: Amazon Elastic Container Registry (ECR).
* **Automação de CI/CD**: GitHub Actions com runners `ubuntu-latest`.

---

## 🏛️ 3. Diagrama da Arquitetura do Repositório

```mermaid
graph TB
    Client(["Usuário / Frontend / Postman"]) -->|"HTTPS :443 (Bearer JWT)"| ApiGateway["AWS API Gateway HTTP API v2<br/>(8sggxeps4j.execute-api.us-east-1.amazonaws.com)"]

    subgraph AWS_Cloud ["Nuvem AWS (us-east-1)"]
        
        subgraph AWS_VPC ["AWS VPC (10.0.0.0/16) - Multi-AZ"]
            
            subgraph PublicSubnets ["Subnets Públicas (10.0.1.0/24 & 10.0.2.0/24)"]
                VpcLink["VPC Link Endpoint"]
                NATGW["AWS NAT Gateway"]
                IGW["Internet Gateway (IGW)"]
            end

            subgraph PrivateSubnets ["Subnets Privadas (10.0.10.0/24 & 10.0.20.0/24)"]
                InternalNLB["AWS Network Load Balancer (NLB Interno :8080)"]

                subgraph EKSCluster ["Cluster AWS EKS (techchallenge-cluster)"]
                    
                    subgraph NamespaceGarage ["Namespace: garage"]
                        AppService["K8s Service: api-garage (:8080)"]
                        AppPods["Pods: api-garage (Spring Boot 4.x / Java 25)<br/>Clean Arch | Stateless JWT RS256"]
                        HPA["Horizontal Pod Autoscaler (HPA)"]
                        KeycloakService["K8s Service: keycloak (:8080)"]
                        KeycloakPods["Pod: Keycloak OIDC Server (v24)"]
                        KeycloakDBSvc["K8s Service: keycloak-db (:5432)"]
                        KeycloakDB["Pod: Keycloak DB (PostgreSQL 15 Alpine)"]
                    end

                    subgraph NamespaceKubeSystem ["Namespace: kube-system"]
                        MetricsServer["Metrics Server Pod"]
                    end
                end
            end

            VpcLink -->|"Listener TCP :8080"| InternalNLB
            InternalNLB --> AppService
            AppService --> AppPods
            AppPods -->|"Validação JWKS Local (/certs)"| KeycloakService
            KeycloakService --> KeycloakPods
            KeycloakPods -->|"Persistência IAM (:5432)"| KeycloakDBSvc
            KeycloakDBSvc --> KeycloakDB
            HPA -.->|"Métricas de CPU/Memória"| MetricsServer
            MetricsServer -.->|"Coleta métricas"| AppPods
            PrivateSubnets -->|"Saída à Internet / AWS APIs"| NATGW
            NATGW --> IGW
        end

        subgraph Managed_Services ["Serviços Gerenciados AWS & IaC"]
            ECR["AWS ECR garage-api<br/>(Repositório de Imagens)"]
            S3State[("AWS S3 Bucket: Remote State<br/>techchallenge-fiap-tfstate-890958457263<br/>k8s/terraform.tfstate")]
            
            subgraph AWSMessaging ["modules/messaging (Mensageria Assíncrona)"]
                SNSTopic["AWS SNS Topic<br/>api-garage_notification-creation_topic"]
                SQSQueue["AWS SQS Queue<br/>api-garage_notification-creation_queue"]
                SQSDLQ["AWS SQS DLQ<br/>api-garage_notification-creation_queue_dlq"]
            end
        end

        subgraph ObservabilityStack ["Observabilidade & APM (modules/observability-newrelic)"]
            NewRelic["New Relic One (APM Centralizado)<br/>Distributed Tracing OTLP / Métricas / Dashboards"]
        end

        ApiGateway -->|"Roteia tráfego privado"| VpcLink
        ECR -.->|"Pull de Imagem :latest"| AppPods
        AppPods -->|"1. Publica Evento (WAITING_FOR_APPROVAL)"| SNSTopic
        SNSTopic -->|"2. Subscrição Fanout"| SQSQueue
        SQSQueue -->|"3. Consumo Assíncrono (@SqsListener)"| AppPods
        SQSQueue -.->|"Redrive após 3 falhas"| SQSDLQ
        AppPods -.->|"Telemetria OTLP (:4318)"| NewRelic
    end
```

### 🗄️ Backend Remoto de Estado no Amazon S3

O Terraform utiliza o **Amazon S3** como backend remoto para persistência centralizada do arquivo de estado (`tfstate`), garantindo consistência, bloqueio e auditoria:

| Parâmetro | Valor Configurado | Descrição |
| :--- | :--- | :--- |
| **Bucket S3** | `techchallenge-fiap-tfstate-890958457263` | Bucket dedicado ao armazenamento do estado de infraestrutura |
| **Chave do Estado (`key`)** | `k8s/terraform.tfstate` | Caminho do estado isolado para este repositório de Kubernetes |
| **Região AWS** | `us-east-1` | Mesma região dos recursos de rede, computação e mensageria |
| **Versionamento** | `Status=Enabled` | Histórico completo de alterações e reversão de versões do `tfstate` |
| **Provisionamento Automático** | GitHub Actions Pipeline | Step `Ensure Terraform State S3 Bucket Exists` que cria o bucket automaticamente caso o laboratório seja reiniciado |

---

### 📬 Módulo de Mensageria (`modules/messaging`)

Provisiona os tópicos e filas totalmente integrados ao pod da aplicação `api-garage`:

| Recurso | Nome do Recurso no Terraform | Identificador AWS | Finalidade |
| :--- | :--- | :--- | :--- |
| **SNS Topic** | `aws_sns_topic.notification_creation_topic` | `api-garage_notification-creation_topic` | Recepção pub/sub de eventos do ciclo de vida da OS |
| **SQS Queue** | `aws_sqs_queue.notification_creation_queue` | `api-garage_notification-creation_queue` | Fila bufferizada com retenção de 4 dias e visibilidade de 30s |
| **SQS DLQ** | `aws_sqs_queue.notification_creation_dlq` | `api-garage_notification-creation_queue_dlq` | Dead Letter Queue com 14 dias de retenção |
| **Subscription** | `aws_sns_topic_subscription.notification_sqs_sub` | Protocolo `sqs` | Encaminhamento fanout automático do SNS para a SQS |
| **Queue Policy**| `aws_sqs_queue_policy.notification_queue_policy` | Resource-based Policy | Autorização da ação `sqs:SendMessage` concedida ao SNS |

As referências (`topic_name` e `queue_name`) são injetadas automaticamente no módulo `modules/app-garage` e expostas como variáveis de ambiente no pod:
* `SNS_ENABLED = "true"`
* `SQS_ENABLED = "true"`
* `NOTIFICATION_TOPIC = "api-garage_notification-creation_topic"`
* `NOTIFICATION_QUEUE = "api-garage_notification-creation_queue"`

---

## ⚙️ 4. Governança e Execução: Pipeline GitHub Actions (Obrigatório)

> [!IMPORTANT]
> **POLÍTICA DE GOVERNANÇA DE DEVSECOPS: PROIBIDO APPLY MANUAL VIA PROMPT LOCAL**
> Para garantir rastreabilidade, auditoria, consistência de estado e conformidade de segurança, **nenhum membro da equipe deve executar `terraform apply` a partir do terminal local**. Todos os provisionamentos, alterações de infraestrutura e destituições devem ser executados exclusivamente através da **Pipeline de CI/CD do GitHub Actions**.

> [!CAUTION]
> **DIRETRIZ MANDATÓRIA DE SEGURANÇA: NUNCA MAPEAR DADOS SENSÍVEIS NO CÓDIGO FONTE**
> É **estritamente proibido** versionar senhas, tokens, API Keys, License Keys ou credenciais em qualquer arquivo de código fonte (`.tf`, `.tfvars`, `.yaml`, `.json`, `.properties`, `.env` ou scripts).
> Todos os segredos e dados sensíveis **devem ser obrigatoriamente configurados nos Segredos da Pipeline (GitHub Actions Secrets)** e injetados de forma dinâmica e segura em tempo de execução.


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
   - Clique em **Run workflow**, selecione a branch `master` e escolha a ação desejada:
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

#### Opção B: Ciclo Automatizado de GitOps (Merge na `master`)
* **Branch `feature/*` e Pull Requests**: O Terraform **não é executado** em branches de feature ou durante a abertura de PRs, evitando execuções desnecessárias ou falhas por ausência de credenciais temporárias do laboratório.
* **Merge na branch `master`**: O pipeline é disparado automaticamente e executa o `terraform apply -auto-approve` no cluster EKS.



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
  https://6t8e18w3f8.execute-api.us-east-1.amazonaws.com/api/swagger-ui/index.html
  ```
* **OpenAPI 3 JSON Spec**: 
  ```
  https://6t8e18w3f8.execute-api.us-east-1.amazonaws.com/api/v3/api-docs
  ```

### 📬 Testes Rápidos via Postman / cURL:

```bash
# 1. Testar conexão através do API Gateway
curl -i --location 'https://6t8e18w3f8.execute-api.us-east-1.amazonaws.com/api/actuator/health'

# 2. Keycloak Endpoint Interno (via Pod no cluster):
# URL: http://keycloak.garage.svc.cluster.local:8080/realms/garage/.well-known/openid-configuration
```

