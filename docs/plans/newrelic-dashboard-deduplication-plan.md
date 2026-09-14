# Plano de Implementação: Prevenção e Limpeza de Dashboards Duplicados no New Relic

## 1. Contexto e Problema
O New Relic é uma plataforma SaaS persistente cujos recursos (como dashboards) não são removidos automaticamente quando o laboratório efêmero da AWS Academy é destruído ou quando suas credenciais expiram.
A cada nova sessão ou execução da pipeline Terraform (`terraform.yml`), um novo bucket S3 de estado (`terraform.tfstate`) é inicializado. Como o Terraform inicia com o estado vazio, ele chama a API do New Relic para criar os 4 dashboards gerenciados (`work-orders-executive`, `technical-integrations-k8s`, `keycloak-identity` e `postgresql-database`).
Como a API do New Relic não bloqueia nomes repetidos, isso gerou o acúmulo de réplicas de dashboards órfãos criados em dias anteriores (03/09, 10/09, 11/09, 13/09).

---

## 2. Solução Técnica Proposta (Opção 1 - Step Automatizado Pré-Apply)
Implementar uma automação no pipeline CI/CD do repositório `15-soat-tech-challenge-iac-k8s` que garanta a **idempotência de dashboards no New Relic SaaS**, mesmo sob perda periódica do `tfstate` da AWS Academy.

### Fluxo de Execução:
1. **Script de Higienização (`scripts/cleanup-newrelic-dashboards.sh`)**:
   - Disparado no GitHub Actions após o `terraform init` e antes do `terraform plan/apply`.
   - Consulta a API GraphQL NerdGraph do New Relic para listar os dashboards existentes com os nomes do projeto.
   - Verifica o estado atual do Terraform (`terraform state list` / `terraform state show`):
     - Se o Terraform já rastreia o GUID de um dashboard no state ativo, ele é preservado.
     - Se existirem dashboards com os nomes do projeto cujos GUIDs **não** constam no state atual (dashboards órfãos de labs anteriores), o script invoca a mutação `dashboardDelete(guid: "...")` via GraphQL NerdGraph.
     - Se o state estiver vazio (novo lab), remove réplicas órfãs prévias para que o `terraform apply` crie uma única versão limpa e registre seu GUID no state atual.
2. **Integração no Workflow (`.github/workflows/terraform.yml`)**:
   - Novo step: `Clean Up Orphan New Relic Dashboards`.
   - Utiliza o secret `NEWRELIC_API_KEY` já configurado no repositório.

---

## 3. Arquivos Envolvidos
- `[NEW]` `scripts/cleanup-newrelic-dashboards.sh`: Script idempotente em Bash/curl/jq para auditoria e deleção de dashboards órfãos via NerdGraph API.
- `[MODIFY]` `.github/workflows/terraform.yml`: Inclusão do step pré-apply no job de automação do Terraform.

---

## 4. Plano de Verificação e Rollback
1. **Higienização Inicial**: Execução imediata do script para deletar as 4 cópias antigas (03/09, 10/09, 11/09, 13/09), mantendo apenas a versão atual de hoje (14/09).
2. **Consulta via NerdGraph**: Validação de que exatamente 4 dashboards (e suas abas) permanecem ativos.
3. **Teste de Idempotência**: Simular execução do step confirmando que nenhum dashboard ativo em uso é afetado.