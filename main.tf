terraform {
  # Have terraform pull/save state in S3 bucket and store lock state to dynamodb table
  backend "s3" {
    bucket = "terraform-state-rain"
    dynamodb_table = "terraform-state-lock-dynamo"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
    region = "us-east-1"
}


#Create S3 bucket to store terraform state file
resource "aws_s3_bucket" "terraform-state-rain" {
  bucket = "terraform-state-rain"

# Prevent bucket deletion
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "terraform-state-rain"
  }
}

# Set bucket S3 versioning to enabled on terraform state bucket
resource "aws_s3_bucket_versioning" "versioning_tfstate" {
  bucket = aws_s3_bucket.terraform-state-rain.id
versioning_configuration {
  status =  "Enabled"
  }
}



# Create DynamoDB table, set to On-Demand read/write billing, set partition key as HashValue
resource "aws_dynamodb_table" "hash_table" {
    name = "hash_table"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "HashValue"

    attribute {
        name = "HashValue"
        type = "S"
      
    }

    tags = {
        Name = "HashTable"
    }
  
}

# Create S3 bucket to store lambda code
resource "aws_s3_bucket" "hash_slasher" {
  bucket = "hashslasher"

# Prevent bucket deletion
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "HashSlasher"
  }
}

# Set versioning to enabled on s3 bucket
resource "aws_s3_bucket_versioning" "versioning_hash_slasher" {
  bucket = aws_s3_bucket.hash_slasher.id
versioning_configuration {
  status =  "Enabled"
  }
}


# Zip lambda code since Lambda function requires the code be zipped
data "archive_file" "code_zip" {
type        = "zip"
source_dir  = "${path.module}/code/"
output_path = "${path.module}/code/PlaintextToMD5Lambda.zip"
}

# Upload local lambda script to S3 to backup
resource "aws_s3_object" "lamda_script" {
  bucket = aws_s3_bucket.hash_slasher.bucket
  key = "PlaintextToMD5Lambda.zip"
  source = "${data.archive_file.code_zip.output_path}"
}

#Create role/assume role for lambda function
resource "aws_iam_role" "HasherRole" {
  name               = "HasherRole"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Create IAM policy document that will get referenced when create IAM Policy
data "aws_iam_policy_document" "hasher-put-document" {
  statement{
    actions = ["dynamodb:PutItem"]
    resources = ["arn:aws:dynamodb:us-east-1:*:table/hash_table"]
    effect = "Allow"
  }
}

# Create IAM Policy
resource "aws_iam_policy" "hasher-put-policy" {
  name =  "hasher-put"
  description = "Allows hasher lambda function to perform GetItem on hash_table dynamodb table"
  policy = data.aws_iam_policy_document.hasher-put-document.json
}

#Create IAM Policy attachment
resource "aws_iam_role_policy_attachment" "attachment" {
  role = aws_iam_role.HasherRole.name
  policy_arn = aws_iam_policy.hasher-put-policy.arn
  
}


# Create lambda function "Hasher"
resource "aws_lambda_function" "Hasher" {
  filename = "${data.archive_file.code_zip.output_path}"
  function_name = "Hasher"
  role = aws_iam_role.HasherRole.arn
  handler = "lambda_function.lambda_handler"
  runtime = "python3.12"
}







