###############################################################################
# Lambda Authorizer — JWT validation
###############################################################################

data "archive_file" "authorizer" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambda/authorizer"
  output_path = "${path.module}/../../lambda/authorizer.zip"
}

resource "aws_lambda_function" "authorizer" {
  function_name    = "${var.project_name}-jwt-authorizer"
  filename         = data.archive_file.authorizer.output_path
  source_code_hash = data.archive_file.authorizer.output_base64sha256
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  role             = var.lambda_role_arn
  timeout          = 5

  environment {
    variables = {
      JWT_SECRET = var.jwt_secret
    }
  }

  tags = {
    Name = "${var.project_name}-jwt-authorizer"
  }
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*"
}

resource "aws_apigatewayv2_authorizer" "jwt" {
  api_id                            = aws_apigatewayv2_api.main.id
  authorizer_type                   = "REQUEST"
  authorizer_uri                    = aws_lambda_function.authorizer.invoke_arn
  authorizer_payload_format_version = "2.0"
  enable_simple_responses           = true
  name                              = "${var.project_name}-jwt-authorizer"
}
