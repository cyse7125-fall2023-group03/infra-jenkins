provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "vpc_1" {
  cidr_block = var.vpc_cidr[0]
  tags = {
    Name = "vpc_1"
  }
}

resource "aws_subnet" "public_subnets_1" {
  count                   = length(data.aws_availability_zones.available.names) > 2 ? 3 : 2
  cidr_block              = "${var.subnet_prefix_1}.${count.index + 1}.${var.subnet_suffix}"
  vpc_id                  = aws_vpc.vpc_1.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Type = var.public_tag
    Name = "${var.public_subnet_name}_${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnets_1" {
  count             = length(data.aws_availability_zones.available.names) > 2 ? 3 : 2
  cidr_block        = "${var.subnet_prefix_1}.${count.index + 4}.${var.subnet_suffix}"
  vpc_id            = aws_vpc.vpc_1.id
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Type = var.private_tag
    Name = "${var.private_subnet_name}_${count.index + 1}"
  }
}

resource "aws_internet_gateway" "internet_gateway_1" {
  vpc_id = aws_vpc.vpc_1.id
  tags = {
    Name = "internet_gateway_1"
  }
}


resource "aws_route_table" "public_route_table_1" {
  vpc_id = aws_vpc.vpc_1.id
  route {
    cidr_block = var.public_route_table_cidr
    gateway_id = aws_internet_gateway.internet_gateway_1.id
  }
  tags = {
    Name = "${var.public_tag}_routetable_1"
  }
}


resource "aws_route_table" "private_route_table_1" {
  vpc_id = aws_vpc.vpc_1.id
  tags = {
    Name = "${var.private_tag}_routetable_1"
  }
}


resource "aws_route_table_association" "public_subnets_association_1" {
  count          = length(aws_subnet.public_subnets_1.*.id)
  subnet_id      = aws_subnet.public_subnets_1[count.index].id
  route_table_id = aws_route_table.public_route_table_1.id
}


resource "aws_route_table_association" "private_subnets_association_1" {
  count          = length(aws_subnet.private_subnets_1.*.id)
  subnet_id      = aws_subnet.private_subnets_1[count.index].id
  route_table_id = aws_route_table.private_route_table_1.id
}

resource "aws_security_group" "jenkinsSg" {
  name = "Jenkins-Instance-sg"
  vpc_id = aws_vpc.vpc_1.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  
}

resource "aws_instance" "EC2-Jenkins" {
  ami                     = var.aws_ami
  instance_type           = "t2.micro"
  disable_api_termination = false
  ebs_optimized           = false
  root_block_device {
    volume_size           = 50
    volume_type           = "gp2"
    delete_on_termination = true
  }
  vpc_security_group_ids = [aws_security_group.jenkinsSg.id]
  subnet_id              = aws_subnet.public_subnets_1[0].id
  key_name               = "jenkins_ec2"
  tags = {
    Name = "Jenkins EC2 Instance"
  }
}

# resource "aws_key_pair" "ec2keypair" {
#   key_name   = "ec2"
#   public_key = file("~/.ssh/ec2.pub")
# }


data "aws_eip" "by_tags" {
  tags = {
    Name = "Jenkins_eip"
  }
}

resource "aws_eip_association" "eip_jenkins_assoc" {
  instance_id   = aws_instance.EC2-Jenkins.id
  allocation_id = data.aws_eip.by_tags.id
}

# resource "aws_eip" "Jenkins-eip" {
#   instance = aws_instance.EC2-Jenkins.id 
# }

data "aws_route53_zone" "primary" {
  name = var.domain_name
}

resource "aws_route53_record" "jenkinsDNS" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "${var.subdomain}.${var.domain_name}"
  type    = "A"
  ttl     = 60
  records = [data.aws_eip.by_tags.public_ip]
}



