locals {
  is_ha = data.aviatrix_transit_gateway.avx_transit_gw.ha_gw_name==null ? false : true # Check if Avx HA Transit GW is enabled.
  total_BGP_inside_CIDR_ranges_27 = length(var.BGP_inside_CIDR_ranges_27)
  BGP_inside_CIDR_ranges_29 = {for index, cidr in var.BGP_inside_CIDR_ranges_27: index=>cidrsubnets(cidr, 2, 2, 2, 2)}
}