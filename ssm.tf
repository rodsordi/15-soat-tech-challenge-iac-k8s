# --- AWS Systems Manager (SSM) Parameter Store ---
# Publishes dynamically provisioned endpoints for external consumers (Lambda, E2E, Frontend)

data "aws_lb" "keycloak_nlb" {
  tags = {
    "kubernetes.io/service-name" = "garage/keycloak"
  }

  depends_on = [module.keycloak]
}

data "aws_lb" "garage_nlb" {
  tags = {
    "kubernetes.io/service-name" = "garage/api-garage"
  }

  depends_on = [module.app_garage]
}

resource "aws_ssm_parameter" "keycloak_url" {
  name        = "/garage/keycloak/url"
  type        = "String"
  value       = "http://${data.aws_lb.keycloak_nlb.dns_name}:8080"
  description = "Keycloak internal NLB endpoint URL for Auth Lambda"
  overwrite   = true

  tags = {
    Project     = "SOAT-TechChallenge"
    ManagedBy   = "Terraform"
    Environment = "production"
  }
}

resource "aws_ssm_parameter" "garage_api_url" {
  name        = "/garage/api/url"
  type        = "String"
  value       = "http://${data.aws_lb.garage_nlb.dns_name}:8080"
  description = "API Garage internal NLB endpoint URL for catalog propagation"
  overwrite   = true

  tags = {
    Project     = "SOAT-TechChallenge"
    ManagedBy   = "Terraform"
    Environment = "production"
  }
}

resource "aws_ssm_parameter" "api_gateway_url" {
  name        = "/garage/api-gateway/url"
  type        = "String"
  value       = "${trimsuffix(module.api_gateway.api_gateway_url, "/")}/api"
  description = "Public API Gateway URL for Garage API"
  overwrite   = true

  tags = {
    Project     = "SOAT-TechChallenge"
    ManagedBy   = "Terraform"
    Environment = "production"
  }
}
