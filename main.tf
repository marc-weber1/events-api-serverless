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
  prefix = "serverless-event-api"
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


## DynamoDB Database

resource "aws_dynamodb_table" "event_db" {
  name          = "event_api_db"
  billing_mode  = "PAY_PER_REQUEST"
  hash_key      = "name"
  range_key     = "start_time"

  attribute {
    name = "name"
    type = "S"
  }

  attribute {
    name = "start_time"
    type = "S"
  }

  # non-searchable details are not in the key schema
}


## Lambda Setup

resource "aws_iam_role" "event_api_lambda_exec" {
  name = "event_api_lambda_exec"

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

resource "aws_iam_policy" "DynamoReadWrite" {
  name = "EventDBReadWrite"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "dynamodb:BatchGetItem",
        "dynamodb:BatchWriteItem",
        "dynamodb:CreateTable",
        "dynamodb:DeleteItem",
        "dynamodb:DeleteTable",
        "dynamodb:DescribeTable",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:UpdateItem",
        "dynamodb:UpdateTable",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Effect = "Allow"
      Resource = [
        "${aws_dynamodb_table.event_db.arn}",
        "arn:aws:logs:*",
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.event_api_lambda_exec.id
  policy_arn = aws_iam_policy.DynamoReadWrite.arn
}


## Gateway Setup

resource "aws_apigatewayv2_api" "lambda" {
  name          = "event_api_gw"
  protocol_type = "HTTP"
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"

  retention_in_days = 30
}

resource "aws_apigatewayv2_stage" "development" {
  api_id = aws_apigatewayv2_api.lambda.id

  name        = "event_api_dev"
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


## Functions

# Create Event

resource "aws_lambda_function" "create_event" {
  function_name = "CreateEvent"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_event_api.key

  runtime   = "nodejs14.x"
  handler   = "create_event.handler"

  source_code_hash = data.archive_file.lambda_event_api.output_base64sha256

  role = aws_iam_role.event_api_lambda_exec.arn

  environment {
    variables = {
      aws_region    = var.aws_region
      event_db_name = aws_dynamodb_table.event_db.name
    }
  }
}

resource "aws_cloudwatch_log_group" "create_event" {
  name = "/aws/lambda/${aws_lambda_function.create_event.function_name}"

  retention_in_days = 30
}

resource "aws_apigatewayv2_integration" "create_event" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.create_event.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "create_event" {
  api_id    = aws_apigatewayv2_api.lambda.id

  route_key = "POST /create_event"
  target    = "integrations/${aws_apigatewayv2_integration.create_event.id}"
}

resource "aws_lambda_permission" "create_event" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_event.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}