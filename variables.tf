variable "awsAccessKey"         { default = "xxxxx" }
variable "awsSecretKey"         { default = "xxxxx" }
variable "awsTempAdminPassword" { default = "Ch4ngeMeImmediately!"}
variable "awsVpcName"           { default = "lipowsky-tf-vpc" }
variable "awsVpcAzCount"        { default = 2 }
variable "awsNamePrefix"        { default = "lipowsky-tf"}
variable "awsSshKeyName"        { default = "lipowsky-aws" }
variable "awsRegion"            { default = "us-east-2" }
variable "awsAmiId"             { default = "ami-0917a22a0995b3f87" }
variable "awsInstanceType"      { default = "m5.2xlarge" }