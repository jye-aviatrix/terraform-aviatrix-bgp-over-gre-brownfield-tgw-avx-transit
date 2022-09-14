# Validate if Aviatrix Transit have ASN number set, error out if no set.
resource "null_resource" "is_asn_set_on_avx_transit_gw_asn" {
  count = data.aviatrix_transit_gateway.avx_transit_gw.local_as_number=="" ? "Please make sure to set ASN on Aviatrix Transit" : 0 # Validate if Aviatrix Transit have ASN number set, error out if not set.
}


# Validate if AWS TGW have CIDR block set, error out if no set.
resource "null_resource" "is_cidr_block_set_on_aws_tgw" {
  count = length(data.aws_ec2_transit_gateway.tgw.transit_gateway_cidr_blocks)==0 ? "Please make sure to set CIDR Block on AWS TGW for GRE Outer IP" : 0 # Validate if AWS TGW have CIDR block set, error out if no set.
}


# Validate if AWS TGW have ECMP enabled, error out if no enabled.
resource "null_resource" "is_ecmp_enabled_on_aws_tgw" {
  count = data.aws_ec2_transit_gateway.tgw.vpn_ecmp_support=="enable" ? 0: "Please make sure to VPN ECMP enabled on AWS TGW" # Validate if AWS TGW have ECMP enabled, error out if no enabled.
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

# From TGW Create GRE peering connection to Aviatrix transit via private connection.
resource "aws_ec2_transit_gateway_connect_peer" "tgw_gre_peer" {
  count                         = local.is_ha ? length(var.aws_tgw_BGP_inside_CIDR_ranges_27)*4 : length(var.aws_tgw_BGP_inside_CIDR_ranges_27)*2
  peer_address                  = local.is_ha ? (count.index % 2 == 0 ? data.aviatrix_transit_gateway.avx_transit_gw.private_ip : data.aviatrix_transit_gateway.avx_transit_gw.ha_private_ip) : data.aviatrix_transit_gateway.avx_transit_gw.private_ip
  inside_cidr_blocks            = local.is_ha ? [(cidrsubnets(var.aws_tgw_BGP_inside_CIDR_ranges_27[floor(count.index/4)], 2, 2, 2, 2))[count.index % 4]] : [(cidrsubnets(var.aws_tgw_BGP_inside_CIDR_ranges_27[floor(count.index/2)], 2, 2, 2, 2))[count.index % 2]]
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.attachment.id
  bgp_asn                       = data.aviatrix_transit_gateway.avx_transit_gw.local_as_number
  tags = {
    "Name" = local.is_ha ? "Peer-${count.index + 1}-${count.index % 2 == 0 ? data.aviatrix_transit_gateway.avx_transit_gw.gw_name : data.aviatrix_transit_gateway.avx_transit_gw.ha_gw_name}" : "Peer-${count.index + 1}-${data.aviatrix_transit_gateway.avx_transit_gw.gw_name}"
  }
}

# # From Aviatrix Transit, create GRE peering connection to AWS TGW
# resource "aviatrix_transit_external_device_conn" "to_tgw" {
#   count              = 2
#   vpc_id             = module.mc-transit.transit_gateway.vpc_id
#   connection_name    = "${var.aws_tgw_name}-${count.index + 1}"
#   gw_name            = module.mc-transit.transit_gateway.gw_name
#   connection_type    = "bgp"
#   tunnel_protocol    = "GRE"
#   bgp_local_as_num   = module.mc-transit.transit_gateway.local_as_number
#   bgp_remote_as_num  = aws_ec2_transit_gateway.tgw.amazon_side_asn
#   remote_gateway_ip  = "${aws_ec2_transit_gateway_connect_peer.tgw_gre_peer[count.index * 2].transit_gateway_address},${aws_ec2_transit_gateway_connect_peer.tgw_gre_peer[count.index * 2 + 1].transit_gateway_address}"
#   direct_connect     = true
#   ha_enabled         = false
#   local_tunnel_cidr  = "${cidrhost(local.aws_tgw_BGP_inside_CIDR_ranges_29[count.index * 2], 1)}/29,${cidrhost(local.aws_tgw_BGP_inside_CIDR_ranges_29[count.index * 2 + 1], 1)}/29"
#   remote_tunnel_cidr = "${cidrhost(local.aws_tgw_BGP_inside_CIDR_ranges_29[count.index * 2], 2)}/29,${cidrhost(local.aws_tgw_BGP_inside_CIDR_ranges_29[count.index * 2 + 1], 2)}/29"
# }
