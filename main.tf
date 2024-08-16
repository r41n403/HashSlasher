terraform {
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

  tags = {
    Name = "HashSlasher"
  }
}

# Zip lambda code since Lambda function requires the code be zipped
data "archive_file" "code_zip" {
type        = "zip"
source_dir  = "${path.module}/code/"
output_path = "${path.module}/code/PlaintextToMD5Lambda.zip"
}


# Upload local lambda script to S3, add timestamp to it for safe keeping in case need to rollback quickly
resource "aws_s3_object" "lamda_script" {
  bucket = aws_s3_bucket.hash_slasher.bucket
  key = "PlaintextToMD5Lambda${timestamp()}.zip"
  source = "${data.archive_file.code_zip.output_path}"
}










