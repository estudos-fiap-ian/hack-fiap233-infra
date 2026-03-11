output "api_endpoint" {
  description = "Public invoke URL of the API Gateway"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "api_id" {
  description = "ID of the HTTP API"
  value       = aws_apigatewayv2_api.main.id
}

output "vpc_link_id" {
  description = "ID of the VPC Link"
  value       = aws_apigatewayv2_vpc_link.main.id
}

output "authorizer_id" {
  description = "ID of the Lambda authorizer"
  value       = aws_apigatewayv2_authorizer.jwt.id
}
