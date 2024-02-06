# This is module to create vpc and other resources
resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = merge (   #merge function is two merge any number of type map
    var.common_tags,
    var.vpc_tags,          
    {
      Name = local.name
    }
    
    )
}

#creating internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = merge (
    var.common_tags,
    var.igw_tags,
    {
      Name = local.name
    }
  )
}

#Creating public subnet
resource "aws_subnet" "public" {
  count = length(var.public_subnets_cidr)
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnets_cidr[count.index]
  availability_zone = local.az_names[count.index]

  tags = merge(
    var.common_tags,
    var.public_subnets_tags,
    {
      Name = "${local.name}-public-${local.az_names[count.index]}"
    }
  )
}

#Creating pravite subnet
resource "aws_subnet" "private" {
  count = length(var.private_subnets_cidr)
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnets_cidr[count.index]
  availability_zone = local.az_names[count.index]

  tags = merge(
    var.common_tags,
    var.private_subnets_tags,
    {
      Name = "${local.name}-private-${local.az_names[count.index]}"
    }
  )
}

#Creating database subnet
resource "aws_subnet" "database" {
  count = length(var.database_subnets_cidr)
  vpc_id     = aws_vpc.main.id
  cidr_block = var.database_subnets_cidr[count.index]
  availability_zone = local.az_names[count.index]

  tags = merge(
    var.common_tags,
    var.database_subnets_tags,
    {
      Name = "${local.name}-database-${local.az_names[count.index]}"
    }
  )
}

#creating elastic ip
resource "aws_eip" "eip" {
  domain           = "vpc"
}

#creating NAT gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public[0].id  #[0] is nothing but first element in list

  tags = merge(
    var.common_tags,
    var.nat_gateway_tags,
    {
      Name = "${local.name}"
    }
  )

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.gw]
}

# Creating route table for public
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

   tags = merge(
    var.common_tags,
    var.public_route_table_tags,
    {
      Name = "${local.name}-public"
    }
  )
}

#creating route table for private
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

   tags = merge(
    var.common_tags,
    var.pravite_route_table_tags,
    {
      Name = "${local.name}-private"
    }
  )
}

#creating route table for database
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

   tags = merge(
    var.common_tags,
    var.database_route_table_tags,
    {
      Name = "${local.name}-database"
    }
  )
}

#Creating Routes
resource "aws_route" "public" {
  route_table_id            = aws_route_table.public.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.gw.id
}

resource "aws_route" "pravite" {
  route_table_id            = aws_route_table.private.id
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.main.id
}

resource "aws_route" "database" {
  route_table_id            = aws_route_table.database.id
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count = length(var.public_subnets_cidr)
  subnet_id = element(aws_subnet.public[*].id, count.index) #element function 
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnets_cidr)
  subnet_id = element(aws_subnet.private[*].id, count.index)
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "database" {
  count = length(var.database_subnets_cidr)
  subnet_id = element(aws_subnet.database[*].id, count.index)
  route_table_id = aws_route_table.database.id
}

