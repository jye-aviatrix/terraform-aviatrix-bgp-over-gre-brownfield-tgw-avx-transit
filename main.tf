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