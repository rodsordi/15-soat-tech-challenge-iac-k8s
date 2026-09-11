# Plano de Arquitetura: Migração do Banco de Dados do Keycloak para o Cluster Kubernetes (`iac-k8s`)

## Contexto e Problema Atual

Atualmente, o módulo do **Keycloak** em `15-soat-tech-challenge-iac-k8s` está configurado para se conectar a uma instância de banco de dados PostgreSQL externa (AWS RDS gerenciada pelo repositório `15-soat-tech-challenge-iac-db`).

Essa abordagem gera três problemas críticos:
1. **Dependência Circular e Acoplamento de Pipeline ("Ovo e a Galinha")**:
   - O repositório `iac-db` precisa da VPC e Subnets do EKS (`data.aws_vpc.eks_vpc`), devendo rodar **após** o `iac-k8s`.
   - O `iac-k8s` provisiona o Keycloak que tenta se conectar ao RDS gerenciado.
   - Quando o cluster EKS é recriado em uma nova VPC, o Keycloak entra em `CrashLoopBackOff` com erro `No route to host` até que o `iac-db` seja reexecutado.
2. **Violação de Bounded Context & Menor Privilégio**:
   - Dados de IAM (usuários, senhas, tokens e credenciais do Keycloak) compartilham a mesma instância RDS com os dados de domínio da oficina mecânica (`api-garage`).
3. **Complexidade e Limites na AWS Academy**:
   - A dependência de um RDS Multi-AZ externo atrasa o bootstrap da infraestrutura e gera vulnerabilidade a timeouts de rede e cotas.

---

## Proposta de Solução: PostgreSQL Dedicado para o Keycloak no Kubernetes

Tornar o módulo `modules/keycloak` em `15-soat-tech-challenge-iac-k8s` **100% autônomo e autocontido**:
1. Criar um `Deployment` leve de PostgreSQL (`postgres:15-alpine`) no namespace `garage`.
2. Criar um `Service` do tipo `ClusterIP` interno (`keycloak-db:5432`).
3. Apontar o `Deployment` do Keycloak diretamente para o serviço interno `keycloak-db`.
4. Remover a necessidade de passar o endpoint de banco RDS (`var.db_host`) para o módulo `keycloak`.

---

## Alterações Propostas

### Repositório `15-soat-tech-challenge-iac-k8s`

#### [MODIFY] `modules/keycloak/main.tf`
- Adicionar o recurso `kubernetes_deployment.keycloak_db`:
  - Imagem: `postgres:15-alpine`
  - Port: `5432`
  - Volume: `emptyDir: {}` montado em `/var/lib/postgresql/data` (compatibilidade total com a AWS Academy sem restrições de IAM Roles)
  - Resources: `requests: { cpu: "100m", memory: "128Mi" }`, `limits: { cpu: "500m", memory: "256Mi" }`
  - Credenciais extraídas do `kubernetes_secret.keycloak_secret`
- Adicionar o recurso `kubernetes_service.keycloak_db`:
  - Nome: `keycloak-db`
  - Porta: `5432`
  - Tipo: `ClusterIP` (visível apenas internamente no cluster)
- Ajustar `kubernetes_deployment.keycloak`:
  - Atualizar `KC_DB_URL_HOST` para `keycloak-db`
  - Atualizar `KC_DB_URL_DATABASE` para `keycloak`
  - Atualizar `KC_DB_USERNAME` para `keycloak`

#### [MODIFY] `modules/keycloak/variables.tf`
- Remover a obrigatoriedade de `db_host` e definir padrão interno `keycloak-db`.
- Definir valores padrão adequados para a base dedicada do Keycloak (`keycloak`).

#### [MODIFY] `main.tf`
- Remover a linha `db_host = var.db_host` da invocação do `module "keycloak"`, mantendo o módulo autônomo.

#### [MODIFY] `README.md`
- Atualizar o diagrama de arquitetura e tabela de componentes para refletir o PostgreSQL interno do Keycloak no Kubernetes.

---

## Plano de Verificação

### 1. Validação Local do Terraform
- Executar `terraform fmt -check` e `terraform validate` no diretório `15-soat-tech-challenge-iac-k8s`.

### 2. Validação no Cluster Kubernetes (EKS)
- Aplicar as alterações via `terraform apply` no cluster ativo:
  - Verificar se o pod `keycloak-db` sobe com status `Running (1/1)`.
  - Verificar se o pod `keycloak` conecta ao `keycloak-db`, executa a inicialização e atinge status `Running (1/1)`.
  - Verificar endpoint interno `/health/ready` e `/health/live`.
  - Validar a resolução de JWKS:
    `curl -s http://keycloak.garage.svc.cluster.local:8080/realms/garage/protocol/openid-connect/certs`
