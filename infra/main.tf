provider "aws" {
  region = var.aws_region
}

module "network" {
  source               = "./modules/network"
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  db_subnet_cidrs      = var.db_subnet_cidrs
}

module "security" {
  source = "./modules/security"
  vpc_id = module.network.vpc_id
}

module "rds" {
  source        = "./modules/rds"
  db_subnet_ids = module.network.db_subnet_ids
  rds_sg_id     = module.security.rds_sg_id
  db_name       = var.db_name
  db_username   = var.db_username
  db_password   = var.db_password
}

module "ec2" {
  source        = "./modules/ec2"
  subnet_id     = module.network.public_subnet_ids[0]
  ec2_sg_id     = module.security.ec2_sg_id
  instance_type = var.ec2_instance_type
  key_name      = var.key_name
  database_url  = "mysql+pymysql://${var.db_username}:${var.db_password}@${module.rds.endpoint}:3306/${var.db_name}"
}

module "alb" {
  source          = "./modules/alb"
  vpc_id          = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  alb_sg_id       = module.security.alb_sg_id
  ec2_instance_id = module.ec2.instance_id
  ec2_private_ip  = module.ec2.private_ip
}

module "cloudfront" {
  source       = "./modules/cloudfront"
  alb_dns_name = module.alb.alb_dns_name
}