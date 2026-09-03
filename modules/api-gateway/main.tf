# --- AWS API Gateway VPC Link ---
resource "aws_apigatewayv2_vpc_link" "main" {
  name               = "${var.cluster_name}-vpc-link"
  security_group_ids = var.security_group_ids
  subnet_ids         = var.subnet_ids

  tags = {
    Name = "${var.cluster_name}-vpc-link"
  }
}

# --- HTTP API Gateway ---
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.cluster_name}-api-gateway"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["*"]
    max_age       = 300
  }

  tags = {
    Name = "${var.cluster_name}-api-gateway"
  }
}

# --- Internal NLB & Listener Discovery ---
data "aws_lb" "internal_nlb" {
  tags = {
    "kubernetes.io/service-name" = "garage/api-garage"
  }
}

data "aws_lb_listener" "nlb_listener" {
  load_balancer_arn = data.aws_lb.internal_nlb.arn
  port              = 8080
}

# --- Integration via VPC Link ---
resource "aws_apigatewayv2_integration" "eks" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "HTTP_PROXY"
  integration_uri        = data.aws_lb_listener.nlb_listener.arn
  integration_method     = "ANY"
  connection_type        = "VPC_LINK"
  connection_id          = aws_apigatewayv2_vpc_link.main.id
  payload_format_version = "1.0"
}


# --- Route ANY /{proxy+} ---
resource "aws_apigatewayv2_route" "proxy" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.eks.id}"
}

# --- $default Stage ---
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true
}
