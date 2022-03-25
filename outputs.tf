# Output value definitions

output "lambda_bucket_name" {
  description = "Name of the S3 bucket used to store function code."

  value = aws_s3_bucket.lambda_bucket.id
}

output "base_url" {
  description = "Base URL for API Gateway stage."

  value = aws_apigatewayv2_stage.lambda.invoke_url
}


## Database Stuff

output "rds_hostname" {
  description = "RDS instance hostname"
  value       = aws_db_instance.event_api_db.address
  sensitive   = true
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.event_api_db.port
  sensitive   = true
}

output "rds_username" {
  description = "RDS instance root username"
  value       = aws_db_instance.event_api_db.username
  sensitive   = true
}

output "event_database_password" {
  description = "Password for administrating the event database."
  value = aws_db_instance.event_api_db.password
  sensitive = true
}
