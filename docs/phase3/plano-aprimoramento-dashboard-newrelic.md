# Plano Arquitetural: Aprimoramento do Dashboard Executivo de Negócios (New Relic)

## 1. Contexto & Diagnóstico Atual
Atualmente, o dashboard executivo [`work-orders-executive.json.tftpl`](file:///c:/git/fiap/15-soat-tech-challenge-iac-k8s/modules/observability-newrelic/dashboards/work-orders-executive.json.tftpl) possui apenas 4 widgets focados estritamente na rota de Ordens de Serviço (`/v1/work-orders`).
Entretanto, a aplicação `api-garage` ingere com sucesso no New Relic todo o ciclo operacional da oficina mecânica através da métrica `http.server.requests` e das métricas de infraestrutura, incluindo:
* **Cadastros operacionais**: Novos clientes (`/v1/customers`), veículos vinculados (`/v1/customers/{id}/vehicles`), peças de estoque (`/v1/inventory-materials`) e serviços prestados (`/v1/services`).
* **Mensageria assíncrona**: Notificações processadas via AWS SNS/SQS (`/v1/notifications`).
* **Rotinas batch / SLA**: Cálculo de tempo médio de serviços (`/v1/services/calculateAverageTime`).
* **Segurança e Acessos**: Logins e autenticações JWT (`/auth/login`) e gestão de mecânicos (`/v1/employees`).

---

## 2. Opções de Melhores Práticas de Arquitetura

### Opção 1 (Recomendada): Dashboard Executivo Multidimensional com Abas e Variáveis de Filtro Dinâmico
* **Abordagem**:
  1. **Filtros Globais Interativos no Topo (Template Variables)**:
     - Adição de dropdowns de seleção no topo do dashboard do New Relic permitindo filtrar instantaneamente por **Rota de Negócio (`uri`)**, **Método HTTP (`method`)** e **Status HTTP (`status`)**.
  2. **Estrutura em 2 Abas Temáticas (Pages)**:
     - **Página 1: "Work Orders & SLAs Executivos"**:
       - *Volume de OS Criadas (24h)* (Billboard)
       - *Transições de Status de OS (24h)* (Billboard)
       - *Taxa Geral de Sucesso das OS (%)* (Billboard)
       - *Erros / Exceções em OS (24h)* (Billboard)
       - *Distribuição de Requisições por Rota de OS* (Gráfico de Pizza)
       - *Tempo Médio de Resposta por Operação (ms)* (Gráfico de Linha temporal)
       - *Throughput Operacional de Ordens de Serviço por Minuto* (Gráfico de Área)
     - **Página 2: "Operações da Oficina, Cadastros & Mensageria Cloud"**:
       - *Novos Clientes Cadastrados (24h)* (Billboard)
       - *Novos Veículos Vinculados (24h)* (Billboard)
       - *Novos Materiais no Estoque (24h)* (Billboard)
       - *Notificações Assíncronas Processadas (AWS SQS)* (Billboard)
       - *Volume de Autenticações & Logins (24h)* (Billboard)
       - *Execução da Rotina de Cálculo de Tempo Médio de Serviços* (Tabela com timestamp)
       - *Distribuição Geral de Volume por Entidade da Oficina* (Gráfico de Barras)
* **Vantagens**:
  - Visão 360° do negócio para a diretoria/gestores da oficina mecânica.
  - Navegação limpa e organizada por abas, evitando poluição visual.
  - Facilidade de diagnóstico rápido com filtros dinâmicos.
* **Impacto**: Baixo risco de infraestrutura; 100% retrocompatível; executado via pipeline Terraform no GitHub Actions.

---

### Opção 2: Adição de Novos Widgets na Mesma Página (Página Única Expandida)
* **Abordagem**:
  - Manter apenas 1 página, adicionando 4 novos widgets na parte inferior (grid 12x12).
* **Desvantagens**:
  - Exige rolagem vertical excessiva; mistura métricas executivas de SLA de ordens com métricas de estoque e logins em uma mesma tela.

---

### Opção 3: Dashboards Separados (1 Dashboard por Domínio)
* **Abordagem**:
  - Criar novos arquivos de dashboard Terraform: 1 para Clientes/Veículos, 1 para Estoque/Serviços e 1 para Ordens.
* **Desvantagens**:
  - Fragmenta a visualização executiva em múltiplos links no New Relic One, dificultando a visão holística do negócio.

---

## 3. Recomendação
Recomenda-se a adoção da **Opção 1 (Recomendada)** por proporcionar uma experiência executiva moderna, organizada em abas e com filtros interativos nativos do New Relic One.
