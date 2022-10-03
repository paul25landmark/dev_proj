provider "aws" {
  region = var.region
  access_key = var.access_key
  secret_key = var.secret_key

  default_tags {
    tags = {
      env = "vpc for testing"
      terraform = true
    }
  }
}


module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.13.0"

  name = var.name
  cidr = var.vpc_cidr_block

  azs              = var.azs
  private_subnets  = var.private_subnets
  public_subnets   = var.public_subnets
  database_subnets = var.database_subnets
  elasticache_subnets = var.elasticache_subnets

  enable_nat_gateway              = var.enable_nat_gateway
  one_nat_gateway_per_az          = var.one_nat_gateway_per_az
  enable_dns_hostnames            = var.enable_dns_hostnames
  enable_vpn_gateway              = var.enable_vpn_gateway
  create_database_subnet_group    = var.create_database_subnet_group
  create_elasticache_subnet_group = var.create_elasticache_subnet_group

  vpc_tags = {
    Name = var.name
  }

  tags = {
    Terraform = "true"
    Environment = var.environment
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }

  public_subnet_tags = {
    Tier                                            = "public"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
    "kubernetes.io/role/elb"                        = "1"
  }

  private_subnet_tags = {
    Tier                                            = "private"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"               = "1"
  }

  database_subnet_tags = {
    Tier                                            = "database"
  }

  elasticache_subnet_tags = {
    Tier                                            = "elasticache"
  }
}

# bastion host security group
resource "aws_security_group" "bastion_sg" {
  depends_on = [module.vpc]
  vpc_id = module.vpc.vpc_id
  name   = var.bastion_sg_name

  ingress {
    description = "allow SSH"
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.bastion_sg_name
  }


}

# bastion host ec2 instance
resource "aws_instance" "bastion" {
  depends_on = [
    aws_security_group.bastion_sg,
  ]
  ami = data.aws_ami.found-ami.id
  instance_type = "t2.micro"
  key_name = var.key_pair_name
  subnet_id = element(module.vpc.public_subnets, 0)
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true
  iam_instance_profile = "AmazonSSMRoleForInstancesQuickSetup"
  tags = {
      Name = var.bastion_name
  }
}

# find ami for bastion host
data "aws_ami" "found-ami" {
  most_recent = true
  owners = ["amazon"]

  filter {
    name   = "name"
    values = [var.bastion_ami_name]
  }
}

