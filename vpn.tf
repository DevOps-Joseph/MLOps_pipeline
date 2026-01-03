# Customer Gateway for Japan office
resource "aws_customer_gateway" "main" {
  bgp_asn    = var.customer_bgp_asn
  ip_address = var.customer_gateway_ip
  type       = "ipsec.1"

  tags = {
    Name = "${var.project_name}-customer-gateway"
    Location = "japan-office"
  }
}

# Virtual Private Gateway
resource "aws_vpn_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-vpn-gateway"
    Type = "site-to-site"
  }
}

# Site-to-Site VPN Connection
resource "aws_vpn_connection" "main" {
  customer_gateway_id = aws_customer_gateway.main.id
  type                = "ipsec.1"
  vpn_gateway_id      = aws_vpn_gateway.main.id
  static_routes_only  = true

  tags = {
    Name = "${var.project_name}-vpn-connection"
    Type = "site-to-site-encrypted"
  }
}

# VPN Connection Route for customer network
resource "aws_vpn_connection_route" "office" {
  vpn_connection_id      = aws_vpn_connection.main.id
  destination_cidr_block = var.allowed_ssh_cidr
}

# Route from VPC to customer network via VPN
resource "aws_route" "vpn_route" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = var.allowed_ssh_cidr
  vpn_gateway_id         = aws_vpn_gateway.main.id
}

# Propagate VPN routes to route table
resource "aws_vpn_gateway_route_propagation" "main" {
  vpn_gateway_id = aws_vpn_gateway.main.id
  route_table_id = aws_route_table.private.id
}