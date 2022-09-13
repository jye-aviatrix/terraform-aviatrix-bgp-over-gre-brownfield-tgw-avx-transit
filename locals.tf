locals {
  is_ha = data.aviatrix_transit_gateway.avx_transit_gw.ha_gw_name==null ? false : true # Check if Avx HA Transit GW is enabled.
}