# tf-deploy-bigips-two-az

## Description

This Terraform module is used to deploy multiple F5 BIG-IPs in an AWS VPC, placing each BIG-IP into a **separate** availability zone and installing the declarative onboarding framework.

## Variables

### terraform.tfvars

| Variable | Description |
| -------- | ----------- |
| awsVpcName | The VPC name in AWS that the BIG-IPs will reside within |
| awsVpcAzCount | The number of AZs to deploy BIG-IPs into |
| awsNamePrefix | The prefix to all created objects name/tags within AWS |
| awsSshKeyName | The SSH key within the AWS region that the BIG-IPs will use to authenticate |
| awsRegion | The AWS region the VPC resides within |
| awsAmiId | The AMI ID for the BIG-IP image that will be used |
| awsInstanceType | The instance size/flavor of the BIG-IP instances |
| awsSecondaryIpCount | The number of secondary IP addresses to attach to external interface |
| awsVipCidrBlock | CIDR block for virtual addresses, which will be mapped to the external ENI of BIG-IP-1 |

### cloud-init.yaml

| Variable | Description |
| -------- | ----------- |
| TEMPADMINPWD | The **temporary** admin password |
| FN | Declarative onboarding RPM filename |
| RPMURL | Download link for declarative onboarding RPM |
| FILEPATH | Path to downloaded file on BIG-IP |
| CREDS | Credentials used to install declarative onboarding |
| IP | IP address of BIG-IP instance |

## Documentation

The Terraform module has been tested with the tf-create-vpc module, and expects to find specific naming schemes in place to identify subnets and other resources.  For example, with awsVpcAzCount set to 2, the module will query the subnets within the VPC for tags that end in az1 & az2, and for subnets that contain mgmt, external, and internal.  It will assign these subnets to the ENIs for the BIG-IP instances.

The VPC route table will be updated to add a route to the CIDR contained in awsVipCidrBlock, and initially points the route to the external ENI associated with BIG-IP-1.  The expectation is that this route will be maintained by the [F5 Cloud Failover](https://clouddocs.f5networks.net/products/extensions/f5-cloud-failover/latest/) extension, redirecting the route to the active BIG-IP.

All names/tags for objects will contain the value of the awsNamePrefix variable.  For example, with awsNamePrefix set to lipowsky-tf, the BIG-IPs will be tagged as lipowsky-tf-bigip-az1 and lipowsky-tf-bigip-az2.

No further licensing or configuration of the BIG-IP instances is performed.  It is expected that [F5 Declarative Onboarding](https://clouddocs.f5.com/products/extensions/f5-declarative-onboarding/latest/) will be used to configure and license the BIG-IP instances, in preparation for service deployment.
