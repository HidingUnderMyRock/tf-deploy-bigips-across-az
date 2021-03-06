variable "awsVpcName" {}
variable "awsVpcAzCount" {}
variable "awsNamePrefix" {}
variable "awsSshKeyName" {}
variable "awsRegion" {}
variable "awsAmiId" {}
variable "awsInstanceType" {}
variable "awsSecondaryIpCount" {}
variable awsVipCidrBlock {}

terraform {
    required_version = ">= 0.12"
}

provider "aws" {
    region                      = var.awsRegion
#    access_key                  = var.awsAccessKey
#    secret_key                  = var.awsSecretKey
}

data "aws_vpc" "lipowsky-tf-vpc" {
    tags = {
        Name                    = var.awsVpcName
    }
}

# Retrieve subnet IDs from VPC, adding to index in AZ order

data "aws_subnet_ids" "awsVpcMgmtSubnets" {
    vpc_id                      = data.aws_vpc.lipowsky-tf-vpc.id
    count                       = var.awsVpcAzCount
    tags = {
        Name                    = "*mgmt*az${count.index+1}"
    }
}

data "aws_subnet_ids" "awsVpcExternalSubnets" {
    vpc_id                      = data.aws_vpc.lipowsky-tf-vpc.id
    count                       = var.awsVpcAzCount
    tags = {
        Name                    = "*external*az${count.index+1}"
    }
}

data "aws_subnet_ids" "awsVpcInternalSubnets" {
    vpc_id                      = data.aws_vpc.lipowsky-tf-vpc.id
    count                       = var.awsVpcAzCount
    tags = {
        Name                    = "*internal*az${count.index+1}"
    }
}

# Retrieve security group IDs from VPC

data "aws_security_groups" "awsVpcMgmtSecurityGroup" {
    filter {
        name                    = "vpc-id"
        values                  = ["${data.aws_vpc.lipowsky-tf-vpc.id}"]
    }
    tags = {
        Name                    = "*mgmt*"
    }
}

data "aws_security_groups" "awsVpcExternalSecurityGroup" {
    filter {
        name                    = "vpc-id"
        values                  = ["${data.aws_vpc.lipowsky-tf-vpc.id}"]
    }
    tags = {
        Name                    = "*external*"
    }
}

data "aws_security_groups" "awsVpcInternalSecurityGroup" {
    filter {
        name                    = "vpc-id"
        values                  = ["${data.aws_vpc.lipowsky-tf-vpc.id}"]
    }
    tags = {
        Name                    = "*internal*"
    }
}

# Retrieve route table ID from VPC for external VLAN

data "aws_route_table" "awsRouteTable" {
    vpc_id                      = "${data.aws_vpc.lipowsky-tf-vpc.id}"
}

# Create ENIs in each of the above subnets & assign security group

resource "aws_network_interface" "mgmt-enis" {
    count                       = length(data.aws_subnet_ids.awsVpcMgmtSubnets[*].ids)
    subnet_id                   = tolist(data.aws_subnet_ids.awsVpcMgmtSubnets[count.index].ids)[0]
    security_groups             = data.aws_security_groups.awsVpcMgmtSecurityGroup.ids
    tags = {
        Name                    = "${var.awsNamePrefix}-bigip-az${count.index+1}-eth0"
    }
}

resource "aws_network_interface" "external-enis" {
    count                       = length(data.aws_subnet_ids.awsVpcExternalSubnets[*].ids)
    subnet_id                   = tolist(data.aws_subnet_ids.awsVpcExternalSubnets[count.index].ids)[0]
    security_groups             = data.aws_security_groups.awsVpcExternalSecurityGroup.ids
    tags = {
        Name                    = "${var.awsNamePrefix}-bigip-az${count.index+1}-eth1"
    }
    private_ips_count           = var.awsSecondaryIpCount

    # Write address info to file upon instance creation
    provisioner "local-exec" {
        command = "echo External: ${self.private_ip} >> ${var.awsNamePrefix}-bigip-az${count.index+1}.info"
    }
}

resource "aws_network_interface" "internal-enis" {
    count                       = length(data.aws_subnet_ids.awsVpcInternalSubnets[*].ids)
    subnet_id                   = tolist(data.aws_subnet_ids.awsVpcInternalSubnets[count.index].ids)[0]
    security_groups             = data.aws_security_groups.awsVpcInternalSecurityGroup.ids
    tags = {
        Name                    = "${var.awsNamePrefix}-bigip-az${count.index+1}-eth2"
    }

    # Write address info to file upon instance creation
    provisioner "local-exec" {
        command = "echo Internal: ${self.private_ip} >> ${var.awsNamePrefix}-bigip-az${count.index+1}.info"
    }
}

# Create EIPs for management ENIs

resource "aws_eip" "mgmt-eips" {
    count                       = length(data.aws_subnet_ids.awsVpcMgmtSubnets[*].ids)
    network_interface           = aws_network_interface.mgmt-enis[count.index].id
    vpc                         = true
}

# Create EIPs for external ENIs

resource "aws_eip" "external-eips" {
    count                       = length(data.aws_subnet_ids.awsVpcExternalSubnets[*].ids)
    network_interface           = aws_network_interface.external-enis[count.index].id
    vpc                         = true
}

# Create route for virtual addresses in VPC route table

resource "aws_route" "awsVipRoute" {
    route_table_id              = data.aws_route_table.awsRouteTable.id
    destination_cidr_block      = var.awsVipCidrBlock
    network_interface_id        = aws_network_interface.external-enis[0].id
}

# Create F5 BIG-IP instances in each AZ

resource "aws_instance" "f5_bigip" {
    count                       = length(data.aws_subnet_ids.awsVpcMgmtSubnets[*].ids)
    instance_type               = var.awsInstanceType
    ami                         = var.awsAmiId
    key_name                    = var.awsSshKeyName
    network_interface {
        network_interface_id       = aws_network_interface.mgmt-enis[count.index].id
        device_index            = 0
    }
    network_interface {
        network_interface_id       = aws_network_interface.external-enis[count.index].id
        device_index            = 1
    }
    network_interface {
        network_interface_id       = aws_network_interface.internal-enis[count.index].id
        device_index            = 2
    }
    tags = {
        Name                    = "${var.awsNamePrefix}-bigip-az${count.index+1}"
    }
    user_data                   = file("cloud-init.yaml")
    
    # Write address info to file upon instance creation
    provisioner "local-exec" {
        command = "echo Mgmt-Int: ${self.private_ip} >> ${var.awsNamePrefix}-bigip-az${count.index+1}.info"
    }
    provisioner "local-exec" {
        command = "echo Mgmt-Ext: ${self.public_ip} >> ${var.awsNamePrefix}-bigip-az${count.index+1}.info"
    }
    provisioner "local-exec" {
        command = "echo Public-DNS: ${self.public_dns} >> ${var.awsNamePrefix}-bigip-az${count.index+1}.info"
    }
    
    # Delete address info file upon instance destruction - Windows syntax
    provisioner "local-exec" {
        when    = destroy
        command = "del ${var.awsNamePrefix}-bigip-az${count.index+1}.info"
    }
}