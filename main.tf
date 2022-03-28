terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }

  required_version = "~> 1.0"
}

provider "aws" {
  region = var.aws_region
}


## Default VPC for getting everything to communicate (and where to put the database)

resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [aws_default_vpc.default.id]
  }
}


## S3 Bucket lambda_bucket for Lambda Function Archive Object lambda_event_api

resource "random_pet" "lambda_bucket_name" {
  prefix = "learn-terraform-functions"
  length = 4

  keepers = {
    id = "a" #Alphabetical until something works ig
  }
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = random_pet.lambda_bucket_name.id

  force_destroy = true
}

data "archive_file" "lambda_event_api" {
  type = "zip"

  source_dir  = "${path.module}/event-api"
  output_path = "${path.module}/event-api.zip"
}

resource "aws_s3_object" "lambda_event_api" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "event-api.zip"
  source = data.archive_file.lambda_event_api.output_path

  etag = filemd5(data.archive_file.lambda_event_api.output_path)
}


## Lambda Setup

resource "aws_iam_role" "lambda_vpc_exec" {
  name = "serverless_lambda_vpc"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_vpc_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}


## Gateway Setup

resource "aws_apigatewayv2_api" "lambda" {
  name          = "serverless_lambda_gw"
  protocol_type = "HTTP"
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"

  retention_in_days = 30
}

resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id

  name        = "serverless_lambda_stage"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}


## Database

resource "random_pet" "event_database_password" {
  length = 4

  keepers = {
    id = "a"
  }
}

resource "aws_security_group" "event_api_rds" {
  name = "event_api_rds"

  ingress {
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_parameter_group" "rds_default" {
  name   = "rds-default"
  family = "mariadb10.6"

  # Log connections?
}

resource "aws_db_subnet_group" "event_api_db" {
  name       = "default vpc subnets"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name = "The subnets for the default VPC"
  }
}

resource "aws_db_instance" "event_api_db" {
  allocated_storage     = 5               #  GiB
  engine                = "mariadb"
  engine_version        = "10.6"
  instance_class        = "db.t2.micro"
  db_name               = "event_api"
  username              = "admin"
  password              = random_pet.event_database_password.id
  skip_final_snapshot   = true

  db_subnet_group_name   = aws_db_subnet_group.event_api_db.id
  vpc_security_group_ids = [aws_security_group.event_api_rds.id]
  parameter_group_name   = aws_db_parameter_group.rds_default.name

  apply_immediately     = true  # CHANGE THIS FOR PRODUCTION
}


## Functions

# Put Example Value

resource "aws_lambda_function" "put_value" {
  function_name = "PutValue"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_event_api.key

  runtime = "nodejs14.x"
  handler = "put_value.handler"

  source_code_hash = data.archive_file.lambda_event_api.output_base64sha256

  role = aws_iam_role.lambda_vpc_exec.arn
  
  vpc_config {
    # Needs to be the same availability zone as the database?
	subnet_ids         = data.aws_subnets.default.ids
	security_group_ids = [aws_security_group.event_api_rds.id]
  }

  environment {
    variables = {
      db_endpoint = aws_db_instance.event_api_db.address
      db_user     = aws_db_instance.event_api_db.username
      db_pass     = aws_db_instance.event_api_db.password
      db_port     = aws_db_instance.event_api_db.port
      db_name     = aws_db_instance.event_api_db.db_name
    }
  }
}

resource "aws_cloudwatch_log_group" "put_value" {
  name = "/aws/lambda/${aws_lambda_function.put_value.function_name}"

  retention_in_days = 30
}

resource "aws_apigatewayv2_integration" "put_value" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.put_value.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "put_value" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "POST /value"
  target    = "integrations/${aws_apigatewayv2_integration.put_value.id}"
}

resource "aws_lambda_permission" "gateway_put_value" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.put_value.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

# Get Example Value

resource "aws_lambda_function" "get_value" {
  function_name = "GetValue"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_event_api.key

  runtime = "nodejs14.x"
  handler = "get_value.handler"

  source_code_hash = data.archive_file.lambda_event_api.output_base64sha256

  role = aws_iam_role.lambda_vpc_exec.arn
  
  vpc_config {
    # Needs to be the same availability zone as the database?
	subnet_ids         = data.aws_subnets.default.ids
	security_group_ids = [aws_security_group.event_api_rds.id]
  }

  environment {
    variables = {
      db_endpoint = aws_db_instance.event_api_db.address
      db_user     = aws_db_instance.event_api_db.username
      db_pass     = aws_db_instance.event_api_db.password
      db_port     = aws_db_instance.event_api_db.port
      db_name     = aws_db_instance.event_api_db.db_name
    }
  }
}

resource "aws_cloudwatch_log_group" "get_value" {
  name = "/aws/lambda/${aws_lambda_function.get_value.function_name}"

  retention_in_days = 30
}

resource "aws_apigatewayv2_integration" "get_value" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.get_value.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "get_value" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "GET /value"
  target    = "integrations/${aws_apigatewayv2_integration.get_value.id}"
}

resource "aws_lambda_permission" "gateway_get_value" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_value.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}
