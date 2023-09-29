# infra-jenkins

Steps to create the infrastructure using AWS on Cloud Providers.
terraform init
terraform fmt
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
terraform destroy -var-file=terraform.tfvars
