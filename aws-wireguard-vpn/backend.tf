terraform {
  backend "s3" {
    bucket  = "rzc777-terraform-state"
    key     = "aws-wireguard-vpn/terraform.tfstate"
    region  = "ap-southeast-1"
    encrypt = true
  }
}
