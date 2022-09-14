variable "gw_name" {
  description = "Provide Aviatrix Transit Gateway Name to locate it"
  type = string
}

variable "aws_tgw_asn_number" {
  description = "Provide AWS TGW ASN number to locate it"
  type = number
}

variable "aviatrix_transit_gateway_vpc_public_subnet_name_contains" {
  description = "Assuming the public subnet for Aviatrix Transit Gateway has been created by Aviatrix VPC Creator tool, which will have name matching: Public-gateway-and-firewall-mgmt"
  type = string
  default = "Public-gateway-and-firewall-mgmt"
}

variable "aviatrix_transit_gateway_route_table_names" {
    description = "Provide list of route tables to be modified. Destination point to TGW CIDR block will be pointing to TGW"
    type = list  
}

variable "BGP_inside_CIDR_ranges_27" {
  description = "Provide list of 169.254.x.x/27 IP ranges. Each range will be divided to four TGW BGP inside /29 CIDR"
  type = list
}