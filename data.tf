# Aviatrix Transit Gateway Data Source
data "aviatrix_transit_gateway" "avx_transit_gw" {
  gw_name = var.gw_name
}

data "aws_ec2_transit_gateway" "tgw" {
  filter {
    name   = "options.amazon-side-asn"
    values = [var.aws_tgw_asn_number]
  }

  filter {
    name = "state"
    values = ["available"]
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

