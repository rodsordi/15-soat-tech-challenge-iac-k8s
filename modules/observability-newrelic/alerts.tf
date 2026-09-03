resource "newrelic_alert_policy" "garage_business_policy" {
  name                = "[${var.cluster_name}] Business & Platform Health"
  incident_preference = "PER_CONDITION"
}

# 1. Alertas para falhas no processamento de ordens de serviço (HTTP 5xx em /work-orders)
resource "newrelic_nrql_alert_condition" "work_order_failures" {
  account_id                   = var.newrelic_account_id
  policy_id                    = newrelic_alert_policy.garage_business_policy.id
  name                         = "Falha no Processamento de Ordens de Serviço (> 1% erros 5xx)"
  type                         = "static"
  enabled                      = true
  violation_time_limit_seconds = 3600

  nrql {
    query = "SELECT percentage(count(*), WHERE numeric(response.status) >= 500) FROM Transaction WHERE request.uri LIKE '%/work-orders%' AND appName LIKE '%api-garage%'"
  }

  critical {
    operator              = "above"
    threshold             = 1.0
    threshold_duration    = 300
    threshold_occurrences = "ALL"
  }
}

# 2. Alertas para falhas nas integrações críticas (PostgreSQL e AWS SQS)
resource "newrelic_nrql_alert_condition" "integration_failures" {
  account_id                   = var.newrelic_account_id
  policy_id                    = newrelic_alert_policy.garage_business_policy.id
  name                         = "Erros e Falhas nas Integrações (PostgreSQL / AWS SQS)"
  type                         = "static"
  enabled                      = true
  violation_time_limit_seconds = 3600

  nrql {
    query = "SELECT count(*) FROM TransactionError WHERE appName LIKE '%api-garage%' AND (error.class LIKE '%SQLException%' OR error.class LIKE '%SqsException%' OR error.class LIKE '%Postgres%')"
  }

  critical {
    operator              = "above"
    threshold             = 3
    threshold_duration    = 300
    threshold_occurrences = "AT_LEAST_ONCE"
  }
}

# 3. Alertas para Healthcheck e Uptime (Pods api-garage não saudáveis)
resource "newrelic_nrql_alert_condition" "pod_healthcheck_failed" {
  account_id                   = var.newrelic_account_id
  policy_id                    = newrelic_alert_policy.garage_business_policy.id
  name                         = "Healthcheck Failed - Pods Not Ready (isReady = 0)"
  type                         = "static"
  enabled                      = true
  violation_time_limit_seconds = 3600

  nrql {
    query = "SELECT count(*) FROM K8sPodSample WHERE namespaceName = 'garage' AND podName LIKE '%api-garage%' AND isReady = 0"
  }

  critical {
    operator              = "above"
    threshold             = 0
    threshold_duration    = 300
    threshold_occurrences = "ALL"
  }
}

# 4. Alertas para Latência das APIs (p95 acima de 2.000ms / 2s)
resource "newrelic_nrql_alert_condition" "api_latency_high" {
  account_id                   = var.newrelic_account_id
  policy_id                    = newrelic_alert_policy.garage_business_policy.id
  name                         = "Alta Latência nas APIs (p95 > 2s)"
  type                         = "static"
  enabled                      = true
  violation_time_limit_seconds = 3600

  nrql {
    query = "SELECT percentile(duration * 1000, 95) FROM Transaction WHERE appName LIKE '%api-garage%'"
  }

  critical {
    operator              = "above"
    threshold             = 2000
    threshold_duration    = 300
    threshold_occurrences = "ALL"
  }
}

# 5. Alertas para Consumo de Recursos do Kubernetes (Memória do Pod > 90% do Limit)
resource "newrelic_nrql_alert_condition" "pod_memory_pressure" {
  account_id                   = var.newrelic_account_id
  policy_id                    = newrelic_alert_policy.garage_business_policy.id
  name                         = "Consumo Excessivo de Memória no Pod (> 90%)"
  type                         = "static"
  enabled                      = true
  violation_time_limit_seconds = 3600

  nrql {
    query = "SELECT average(memoryWorkingSetBytes / memoryLimitBytes * 100) FROM K8sContainerSample WHERE namespaceName = 'garage' AND containerName = 'api-garage'"
  }

  critical {
    operator              = "above"
    threshold             = 90
    threshold_duration    = 300
    threshold_occurrences = "ALL"
  }
}

# 6. Alerta para Indisponibilidade do Keycloak (Autenticação OIDC)
resource "newrelic_nrql_alert_condition" "keycloak_unhealthy" {
  account_id                   = var.newrelic_account_id
  policy_id                    = newrelic_alert_policy.garage_business_policy.id
  name                         = "Keycloak Identity Server Down / Not Ready"
  type                         = "static"
  enabled                      = true
  violation_time_limit_seconds = 3600

  nrql {
    query = "SELECT count(*) FROM K8sPodSample WHERE namespaceName = 'garage' AND podName LIKE '%keycloak%' AND isReady = 0"
  }

  critical {
    operator              = "above"
    threshold             = 0
    threshold_duration    = 120
    threshold_occurrences = "ALL"
  }
}

# 7. Alerta para Esgotamento do Pool de Conexões do PostgreSQL (HikariCP Timeout)
resource "newrelic_nrql_alert_condition" "postgres_pool_exhausted" {
  account_id                   = var.newrelic_account_id
  policy_id                    = newrelic_alert_policy.garage_business_policy.id
  name                         = "PostgreSQL Connection Pool Saturated (HikariCP Timeout)"
  type                         = "static"
  enabled                      = true
  violation_time_limit_seconds = 3600

  nrql {
    query = "SELECT count(*) FROM TransactionError WHERE appName LIKE '%api-garage%' AND (error.class LIKE '%SQLTransientConnectionException%' OR error.message LIKE '%Connection is not available%')"
  }

  critical {
    operator              = "above"
    threshold             = 0
    threshold_duration    = 180
    threshold_occurrences = "AT_LEAST_ONCE"
  }
}

# 8. Alerta para Queries Lentas no PostgreSQL (Latência de Banco > 1s)
resource "newrelic_nrql_alert_condition" "postgres_slow_queries" {
  account_id                   = var.newrelic_account_id
  policy_id                    = newrelic_alert_policy.garage_business_policy.id
  name                         = "PostgreSQL Slow Queries (Database Latency > 1s)"
  type                         = "static"
  enabled                      = true
  violation_time_limit_seconds = 3600

  nrql {
    query = "SELECT average(databaseDuration * 1000) FROM Transaction WHERE appName LIKE '%api-garage%' AND databaseDuration > 0"
  }

  critical {
    operator              = "above"
    threshold             = 1000
    threshold_duration    = 300
    threshold_occurrences = "ALL"
  }
}

