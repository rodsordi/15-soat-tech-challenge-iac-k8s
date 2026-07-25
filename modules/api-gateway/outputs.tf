output "api_gateway_url" {
  value       = aws_apigatewayv2_stage.default.invoke_url
  description = "AWS API Gateway Invoke URL"
}

output "vpc_link_id" {
  value       = aws_apigatewayv2_vpc_link.main.id
  description = "API Gateway VPC Link ID"
}
