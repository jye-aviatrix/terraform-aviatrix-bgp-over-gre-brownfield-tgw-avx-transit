# Validate if Aviatrix Transit have ASN number set, error out if no set.
resource "null_resource" "is_asn_set_on_avx_transit_gw_asn" {
  count = data.aviatrix_transit_gateway.avx_transit_gw.local_as_number == "" ? "Please make sure to set ASN on Aviatrix Transit" : 0 # Validate if Aviatrix Transit have ASN number set, error out if not set.
}

# Validate if Aviatrix Transit conflict with AWS TGW ASN number, error out if they are the same.
resource "null_resource" "is_asn_same_on_avx_transit_gw_and_aws_tgw" {
  count = data.aviatrix_transit_gateway.avx_transit_gw.local_as_number == var.aws_tgw_asn_number ? "Please make sure to set different ASN number on Aviatrix Transit and AWS Transit" : 0 # Validate if Aviatrix Transit conflict with AWS TGW ASN number, error out if they are the same.
}

# Validate if Aviatrix Transit have BGP ECMP enabled, error out if no enabled.
resource "null_resource" "is_bgp_ecmp_enabled_on_avx_transit_gw" {
  count = data.aviatrix_transit_gateway.avx_transit_gw.bgp_ecmp ? 0 : "Please make sure to enable BGP ECMP on Aviatrix Transit"# Validate if Aviatrix Transit have BGP ECMP enabled, error out if no enabled.
}

# Validate if AWS TGW have CIDR block set, error out if no set.
resource "null_resource" "is_cidr_block_set_on_aws_tgw" {
  count = length(data.aws_ec2_transit_gateway.tgw.transit_gateway_cidr_blocks) == 0 ? "Please make sure to set CIDR Block on AWS TGW for GRE Outer IP" : 0 # Validate if AWS TGW have CIDR block set, error out if no set.
}


# Validate if AWS TGW have ECMP enabled, error out if no enabled.
resource "null_resource" "is_ecmp_enabled_on_aws_tgw" {
  count = data.aws_ec2_transit_gateway.tgw.vpn_ecmp_support == "enable" ? 0 : "Please make sure to VPN ECMP enabled on AWS TGW" # Validate if AWS TGW have ECMP enabled, error out if no enabled.
}

# Validate if AWS TGW have Name tag defined, error out if no defnied.
resource "null_resource" "is_Name_tag_defined_on_aws_tgw" {
  count = data.aws_ec2_transit_gateway.tgw.tags.Name == null ? "Please make sure to define Name tag on AWS TGW" : 0 # Validate if AWS TGW have Name tag defined, error out if no defnied.
}

# Validate if AWS TGW have Name tag empty, error out if empty.
resource "null_resource" "is_Name_tag_empty_on_aws_tgw" {
  count = data.aws_ec2_transit_gateway.tgw.tags.Name == "" ? "Please make sure Name tag on AWS TGW is not empty" : 0 # Validate if AWS TGW have Name tag empty, error out if empty.
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
  count = local.total_BGP_inside_CIDR_ranges_27
  transport_attachment_id = aws_ec2_transit_gateway_vpc_attachment.tgw_to_avx_transit_vpc.id
  transit_gateway_id      = data.aws_ec2_transit_gateway.tgw.id
  tags = {
    "Name" = "${data.aviatrix_transit_gateway.avx_transit_gw.gw_name}-Connect-${count.index+1}"
  }
}


# In Aviatrix Transit Gateway VPC, create static route point TGW Cidr block to TGW
resource "aws_route" "route_to_tgw_cidr_block" {
  count                  = length(setproduct(flatten([for x in var.aviatrix_transit_gateway_route_table_names : data.aws_route_tables.avx_transit_gw_route_tables[x].ids]), data.aws_ec2_transit_gateway.tgw.transit_gateway_cidr_blocks))
  route_table_id         = setproduct(flatten([for x in var.aviatrix_transit_gateway_route_table_names : data.aws_route_tables.avx_transit_gw_route_tables[x].ids]), data.aws_ec2_transit_gateway.tgw.transit_gateway_cidr_blocks)[count.index][0]
  destination_cidr_block = setproduct(flatten([for x in var.aviatrix_transit_gateway_route_table_names : data.aws_route_tables.avx_transit_gw_route_tables[x].ids]), data.aws_ec2_transit_gateway.tgw.transit_gateway_cidr_blocks)[count.index][1]
  transit_gateway_id     = data.aws_ec2_transit_gateway.tgw.id

  timeouts {
    create = "5m"
  }
}

# From TGW Create GRE peering connection to Aviatrix transit via private connection.
# Use following to understand the logic
# is_ha == true
#
# 0 -> c0 Pr <-Index 0
#      c1 HA <-Index 1
#      c2 Pr <-Index 2 
#      c3 HA <-Index 3
# 1 -> c0 Pr <-Index 4
#      c1 HA <-Index 5
#      c2 Pr <-Index 6
#      c3 HA <-Index 7
# Remote peer -> Index mod 2==0 -> Primary GW
# Remote peer -> Index mod 2!=0 -> HA GW
#
# BGP CIDR = floor(index/4) -> index mod 4
#
# AWS Connect Index -> floor(index/4)
#
# is_ha == false
#
# 0 -> c0 Pr <-Index 0
#      c1 
#      c2 Pr <-Index 1 
#      c3 
# 1 -> c0 Pr <-Index 2
#      c1 
#      c2 Pr <-Index 3
#      c3 

# Remote peer -> Always primary GW
# BGP CIDR = floor(index/2) -> (index mod 2) * 2
# AWS Connect Index -> floor(index/2)
resource "aws_ec2_transit_gateway_connect_peer" "tgw_gre_peer" {
  count                         = local.is_ha ? local.total_BGP_inside_CIDR_ranges_27 * 4 : local.total_BGP_inside_CIDR_ranges_27 * 2
  peer_address                  = local.is_ha ? (count.index % 2 == 0 ? data.aviatrix_transit_gateway.avx_transit_gw.private_ip : data.aviatrix_transit_gateway.avx_transit_gw.ha_private_ip) : data.aviatrix_transit_gateway.avx_transit_gw.private_ip
  inside_cidr_blocks            = local.is_ha ? [local.BGP_inside_CIDR_ranges_29[floor(count.index / 4)][count.index % 4]] : [local.BGP_inside_CIDR_ranges_29[floor(count.index / 2)][(count.index % 2 * 2)]]
  transit_gateway_attachment_id = local.is_ha ? aws_ec2_transit_gateway_connect.attachment[floor(count.index/4)].id : aws_ec2_transit_gateway_connect.attachment[floor(count.index/2)].id 
  bgp_asn                       = data.aviatrix_transit_gateway.avx_transit_gw.local_as_number
  tags = {
    "Name" = local.is_ha ? "Peer-${(count.index % 4) + 1}-${count.index % 2 == 0 ? data.aviatrix_transit_gateway.avx_transit_gw.gw_name : data.aviatrix_transit_gateway.avx_transit_gw.ha_gw_name}" : "Peer-${(count.index % 2) * 2 + 1}-${data.aviatrix_transit_gateway.avx_transit_gw.gw_name}"
  }
}

# From Aviatrix Transit, create GRE peering connection to AWS TGW
# Use following to understand the logic
# is_ha == true
#
# 0 -> c0 <- Local +1  Remote +2 <-Index 0 Peer 0
#      c1 <- Local +1  Remote +2 <-Index 0 Peer 1
#      c2 <- Local +1  Remote +2 <-Index 1 Peer 2
#      c3 <- Local +1  Remote +2 <-Index 1 Peer 3
# 1 -> c0 <- Local +1  Remote +2 <-Index 2 Peer 4
#      c1 <- Local +1  Remote +2 <-Index 2 Peer 5
#      c2 <- Local +1  Remote +2 <-Index 3 Peer 6
#      c3 <- Local +1  Remote +2 <-Index 3 Peer 7
# Remote Peer -> index x 2, index x 2 + 1 
# Local Tunnels, first IP of CIDR range = floor(index/2) -> (Index mod 2)*2 , floor(index/2) -> (Index mod 2)*2 + 1
# Remote Tunnels, second IP of CIDR range = floor(index/2) -> (Index mod 2)*2 , floor(index/2) -> (Index mod 2)*2 + 1
#
# is_ha == false
#
# 0 -> c0 <- Local +1  Remote +2 <-Index 0 Peer 0
#      c1 
#      c2 <- Local +1  Remote +2 <-Index 1 Peer 1
#      c3 
# 1 -> c0 <- Local +1  Remote +2 <-Index 2 Peer 2
#      c1 
#      c2 <- Local +1  Remote +2 <-Index 3 Peer 3
#      c3 
# Remote Peer -> index
# Local Tunnels, first IP of CIDR range =  floor(index/2) -> (Index mod 2)*2
# Remote Tunnels, second IP of CIDR range = floor(index/2) -> (Index mod 2)*2
resource "aviatrix_transit_external_device_conn" "to_tgw" {
  count              = local.total_BGP_inside_CIDR_ranges_27 * 2
  vpc_id             = data.aviatrix_transit_gateway.avx_transit_gw.vpc_id
  connection_name    = "${data.aws_ec2_transit_gateway.tgw.tags.Name}-${count.index + 1}"
  gw_name            = data.aviatrix_transit_gateway.avx_transit_gw.gw_name
  connection_type    = "bgp"
  tunnel_protocol    = "GRE"
  bgp_local_as_num   = data.aviatrix_transit_gateway.avx_transit_gw.local_as_number
  bgp_remote_as_num  = data.aws_ec2_transit_gateway.tgw.amazon_side_asn
  remote_gateway_ip  = local.is_ha ? "${aws_ec2_transit_gateway_connect_peer.tgw_gre_peer[count.index * 2].transit_gateway_address},${aws_ec2_transit_gateway_connect_peer.tgw_gre_peer[count.index * 2 + 1].transit_gateway_address}" : aws_ec2_transit_gateway_connect_peer.tgw_gre_peer[count.index].transit_gateway_address
  direct_connect     = true
  ha_enabled         = false
  local_tunnel_cidr  = local.is_ha ? "${cidrhost(local.BGP_inside_CIDR_ranges_29[floor(count.index / 2)][(count.index % 2) * 2], 1)}/29,${cidrhost(local.BGP_inside_CIDR_ranges_29[floor(count.index / 2)][(count.index % 2) * 2 + 1], 1)}/29" : "${cidrhost(local.BGP_inside_CIDR_ranges_29[floor(count.index / 2)][(count.index % 2) * 2], 1)}/29"
  remote_tunnel_cidr = local.is_ha ? "${cidrhost(local.BGP_inside_CIDR_ranges_29[floor(count.index / 2)][(count.index % 2) * 2], 2)}/29,${cidrhost(local.BGP_inside_CIDR_ranges_29[floor(count.index / 2)][(count.index % 2) * 2 + 1], 2)}/29" : "${cidrhost(local.BGP_inside_CIDR_ranges_29[floor(count.index / 2)][(count.index % 2) * 2], 2)}/29"
}
