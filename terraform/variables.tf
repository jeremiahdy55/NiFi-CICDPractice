variable "ami_id" {
  description = "Ubuntu Server 24.04 LTS (HVM),EBS General Purpose (SSD) Volume Type for us-west-2"
  default     = "ami-05f991c49d264708f" # us-west-2 ubuntu image
}

variable "instance_type_micro" {
  default = "t2.micro"
}

variable "instance_type_medium" {
  default = "t2.medium"
}

# Existing key-pair in AWS for NiFi server
variable "key_name" {
  type    = string
  default = "TF_NiFi_Server_KEY"
}


