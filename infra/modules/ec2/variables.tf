variable "subnet_id" {
  type = string
}

variable "ec2_sg_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "key_name" {
  type = string
}

variable "database_url" {
  type      = string
  sensitive = true
}