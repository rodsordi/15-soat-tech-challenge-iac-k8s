resource "newrelic_one_dashboard_json" "dashboards" {
  for_each = fileset("${path.module}/dashboards", "*.json.tftpl")

  json = templatefile("${path.module}/dashboards/${each.value}", {
    account_id   = var.newrelic_account_id
    cluster_name = var.cluster_name
    app_name     = "api-garage"
  })
}
