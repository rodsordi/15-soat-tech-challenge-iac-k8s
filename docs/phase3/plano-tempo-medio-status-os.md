# Planejamento Arquitetural: Tempo Médio de Execução por Status (Diagnóstico, Execução, Finalização)

Este documento define o planejamento técnico para implementação, instrumentação e visualização no New Relic do **"Tempo médio de execução por status (Diagnóstico, Execução, Finalização)"**, atendendo aos requisitos de observabilidade e métricas operacionais da oficina mecânica.

---

## 1. Contexto e Diagnóstico Atual

1. **Estado Atual no Banco de Dados (garage.work_order)**:
   - A tabela garage.work_order possui apenas created_at e updated_at.
   - As transições de status sobrescrevem a coluna status sem armazenar o momento exato em que a OS entrou ou saiu de cada estágio.
2. **Estado Atual no New Relic (work-orders-executive.json.tftpl)**:
   - O painel executivo atual exibe a métrica *"Tempo Medio de Execucao por Rota de Work Order (ms)"*, calculada sobre http.server.requests.
   - Isso reflete apenas o tempo de resposta da API HTTP (20ms a 50ms) ao receber um PATCH /v1/work-orders/{id}, e **não o tempo de permanência real da OS no estado operacional** da oficina (Diagnóstico pelo mecânico, Execução dos reparos, Finalização e entrega).
3. **Métricas de Serviços Unitários vs Ordem de Serviço**:
   - Para os serviços avulsos, a tabela estimated_service já possui inished_at e a rotina /v1/services/calculateAverageTime calcula o tempo médio em minutos.
   - Para a Ordem de Serviço (WorkOrder), é necessária a mesma capacidade de consolidação e discriminação para os status: **Diagnóstico**, **Execução** e **Finalização**.

---

## 2. Alternativas Técnicas

### 🥇 Opção 1 (Recomendada - Best Practice): Métricas de Negócio de Domínio via Micrometer + Painel Especializado no New Relic

Instrumentação nativa do ciclo de vida da OS na camada de domínio da aplicação com rastreamento persistido dos tempos de cada fase e publicação de métricas via **Micrometer Timer**.

#### Arquitetura:
1. **Modelagem de Dados (Flyway Migration V2__work_order_status_timestamps.sql)**:
   - Adicionar colunas de timestamp na tabela garage.work_order:
     - diagnosing_at TIMESTAMP (início do diagnóstico)
     - waiting_approval_at TIMESTAMP (término do diagnóstico / aguardando aprovação)
     - executing_at TIMESTAMP (aprovação do cliente e início da execução)
     - inished_at TIMESTAMP (conclusão de todos os serviços / fim da execução)
     - eleased_at TIMESTAMP (entrega e liberação do veículo ao cliente)
2. **Lógica de Domínio (WorkOrderUpdateUseCase / WorkOrder)**:
   - Ao transicionar de DIAGNOSING para WAITING_FOR_APPROVAL:
     - Calcula a duração de Diagnóstico: Duration.between(diagnosingAt, waitingApprovalAt).
     - Registra a métrica no Micrometer: meterRegistry.timer("garage.workorder.status.duration", "status", "DIAGNOSING").record(...).
   - Ao transicionar de EXECUTING para FINISHED:
     - Calcula a duração de Execução: Duration.between(executingAt, finishedAt).
     - Registra a métrica no Micrometer: meterRegistry.timer("garage.workorder.status.duration", "status", "EXECUTING").record(...).
   - Ao transicionar de FINISHED para RELEASED:
     - Calcula a duração de Finalização/Liberação: Duration.between(finishedAt, releasedAt).
     - Registra a métrica no Micrometer: meterRegistry.timer("garage.workorder.status.duration", "status", "FINISHED").record(...).
3. **Painel no New Relic (work-orders-executive.json.tftpl)**:
   - Criação da seção dedicada **"Tempo Médio de Execução por Status (Diagnóstico, Execução, Finalização)"**:
     - **Cards Billboards Individuais**: Diagnóstico, Execução e Finalização.
     - **Gráfico Comparativo de Barras**: SELECT average(garage.workorder.status.duration) FROM Metric WHERE metricName = 'garage.workorder.status.duration' FACET status SINCE 24 hours ago RAW
     - **Gráfico Temporal (Timeseries)**: Evolução diária dos SLAs de cada status.

- **Vantagens**:
  - Mede o tempo de negócio real com precisão matemática.
  - Métricas agregadas de alto desempenho sem overhead de parsing de logs.
  - Histórico persistido para relatórios e auditorias no PostgreSQL.
- **Trade-offs**:
  - Requer migration Flyway e adições na entidade WorkOrder.

---

### 🥈 Opção 2 (Alternativa): Log Estruturado de Transição de Estado com Agregação NRQL no New Relic

Emissão de eventos estruturados em log a cada transição de status da OS, delegando o cálculo do tempo médio à engine NRQL do New Relic.

#### Arquitetura:
1. No WorkOrderUpdateUseCase:
   - Ao transicionar de status, calcula o delta em relação a updated_at e gera um log formatado.
2. No New Relic:
   - Queries NRQL sobre a tabela Log agregando os tempos por regex/capture.
- **Vantagens**:
  - Não requer alteração no schema do PostgreSQL (sem migration Flyway).
- **Trade-offs**:
  - Maior custo computacional em consultas sobre logs no New Relic.
  - Menor retenção temporal em relação a métricas agregadas.

---

### 🥉 Opção 3 (Abordagem Minimalista): Discriminação por Latência HTTP da Transição de Status

Manter a observabilidade restrita à camada HTTP, agrupando a latência da chamada PATCH /v1/work-orders/{id} de acordo com o status alvo fornecido no payload da requisição.

- **Vantagens**: Escopo mínimo, sem modificações no domínio.
- **Trade-offs**: Mede apenas o tempo de processamento técnico da API (milissegundos) e não o tempo operacional real da oficina.
