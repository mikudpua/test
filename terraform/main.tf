provider "aws" {
  access_key = ""
  secret_key = ""
  region     = "us-east-1"
}
#----------------------------------------------------------------
data "aws_availability_zones" "available" {}
data "aws_ami" "ubuntu" {
  owners      = ["099720109477"]
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}
#==============================================================================

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "${var.env}-vpc"
  }
}
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.env}-igw"
  }
}
resource "aws_subnet" "public_subnets" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = element(var.public_subnet_cidrs, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.env}-public-${count.index + 1}"
  }
}
resource "aws_route_table" "public_subnets" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "${var.env}-route-public-subnets"
  }
}
resource "aws_route_table_association" "public_routes" {
  count          = length(aws_subnet.public_subnets[*].id)
  route_table_id = aws_route_table.public_subnets.id
  subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
}
#------------------------------------------------------------------
resource "aws_security_group" "web" {
  name   = "Dynamic Security Group"
  vpc_id = aws_vpc.main.id

  dynamic "ingress" {
    for_each = ["8080", "80", "443", "3306"]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "Dynamic SecurityGroup"
    Owner = "miku"
  }
}
#--------------server-----------------------------------------
resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = "gc"
  vpc_security_group_ids = [aws_security_group.web.id]
  subnet_id              = aws_subnet.public_subnets[0].id
  user_data              = file("user_data.sh")

  tags = {
    Name  = "app_server"
    Owner = "miku"
  }
}
resource "aws_instance" "db_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = "gc"
  vpc_security_group_ids = [aws_security_group.web.id]
  subnet_id              = aws_subnet.public_subnets[0].id
  user_data              = file("user_data.sh")

  tags = {
    Name  = "db_server"
    Owner = "miku"
  }
}
resource "aws_instance" "docker" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = "gc"
  vpc_security_group_ids = [aws_security_group.web.id]
  subnet_id              = aws_subnet.public_subnets[0].id
  user_data              = file("user_data_docker.sh")

  tags = {
    Name  = "docker"
    Owner = "miku"
  }
}
