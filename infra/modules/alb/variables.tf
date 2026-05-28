variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "alb_sg_id" { type = string }
variable "ec2_instance_id" { type = string }
variable "ec2_private_ip" { type = string }