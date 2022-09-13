# Aviatrix Transit Gateway Data Source
data "aviatrix_transit_gateway" "avx_transit_gw" {
  gw_name = var.gw_name
}

data "aws_ec2_transit_gateway" "tgw" {
  filter {
    name   = "options.amazon-side-asn"
    values = [var.aws_tgw_asn_number]
  }
}

data "aws_vpc" "avx_transit_vpc" {
  id = data.aviatrix_transit_gateway.avx_transit_gw.vpc_id
}

data "aws_subnets" "avx_transit_vpc_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aviatrix_transit_gateway.avx_transit_gw.vpc_id]
  }

  filter {
    name   = "tag:Name"
    values = ["*${var.aviatrix_transit_gateway_vpc_public_subnet_name_contains}*"] # insert values here
  }
}


data "aws_route_tables" "avx_transit_gw_route_tables" {
  for_each = toset(var.aviatrix_transit_gateway_route_table_names)
  vpc_id   = data.aviatrix_transit_gateway.avx_transit_gw.vpc_id

  filter {
    name   = "tag:Name"
    values = [each.value]
  }
}

# Create AWS TGW Attachment to Aviatrix Transit VPC
resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_to_avx_transit_vpc" {
  subnet_ids         = data.aws_subnets.avx_transit_vpc_subnets.ids
  transit_gateway_id = data.aws_ec2_transit_gateway.tgw.id
  vpc_id             = data.aviatrix_transit_gateway.avx_transit_gw.vpc_id
  tags = {
    "Name" = "${data.aviatrix_transit_gateway.avx_transit_gw.gw_name}-VPC"
  }
}

# Create AWS TGW Connect Attachment point to TGW VPC attachment
resource "aws_ec2_transit_gateway_connect" "attachment" {
  transport_attachment_id = aws_ec2_transit_gateway_vpc_attachment.tgw_to_avx_transit_vpc.id
  transit_gateway_id      = data.aws_ec2_transit_gateway.tgw.id
  tags = {
    "Name" = "${data.aviatrix_transit_gateway.avx_transit_gw.gw_name}-Connect"
  }
}


# In Aviatrix Transit Gateway VPC, create static route point TGW Cidr block to TGW
resource "aws_route" "route_to_tgw_cidr_block" {
count = length(setproduct(flatten([for x in var.aviatrix_transit_gateway_route_table_names : data.aws_route_tables.avx_transit_gw_route_tables[x].ids]),data.aws_ec2_transit_gateway.tgw.transit_gateway_cidr_blocks))
  route_table_id         = setproduct(flatten([for x in var.aviatrix_transit_gateway_route_table_names : data.aws_route_tables.avx_transit_gw_route_tables[x].ids]),data.aws_ec2_transit_gateway.tgw.transit_gateway_cidr_blocks)[count.index][0]
  destination_cidr_block = setproduct(flatten([for x in var.aviatrix_transit_gateway_route_table_names : data.aws_route_tables.avx_transit_gw_route_tables[x].ids]),data.aws_ec2_transit_gateway.tgw.transit_gateway_cidr_blocks)[count.index][1]
  transit_gateway_id     = data.aws_ec2_transit_gateway.tgw.id

  timeouts {
    create = "5m"
  }
}