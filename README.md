# AWS Active Directory Lab Setup

A complete Infrastructure-as-Code (IaC) solution for provisioning and configuring an Active Directory lab environment on AWS using Terraform and PowerShell.

## Overview

This project automates the deployment of a Windows Active Directory domain on AWS. It creates the necessary VPC infrastructure, security groups, and EC2 instances, then configures AD Domain Services with organizational units, security groups, and sample user accounts for testing and development purposes.

## Features

- **Automated VPC Setup**: Creates a VPC with public subnet, internet gateway, and route tables
- **Security Group Configuration**: Manages RDP, LDAP, and LDAPS traffic
- **Active Directory Installation**: Automatically installs and configures AD Domain Services
- **Organizational Structure**: Creates OUs for Users and Groups
- **Sample Objects**: Provisions 5 sample users and 5 sample groups with group memberships
- **Infrastructure as Code**: Fully declarative Terraform configuration for reproducibility

## Architecture

```
┌─────────────────────────────────────────────┐
│           AWS Region (us-east-1)            │
├─────────────────────────────────────────────┤
│  VPC (10.0.0.0/16)                          │
│  ┌────────────────────────────────────────┐ │
│  │  Public Subnet (10.0.1.0/24)          │ │
│  │  ┌──────────────────────────────────┐ │ │
│  │  │  Windows Server 2022 EC2 Instance│ │ │
│  │  │  - Active Directory Domain       │ │ │
│  │  │  - LDAP/LDAPS Services           │ │ │
│  │  └──────────────────────────────────┘ │ │
│  └────────────────────────────────────────┘ │
│  Internet Gateway                           │
└─────────────────────────────────────────────┘
```

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0.0
- AWS CLI configured with appropriate credentials
- Existing AWS EC2 keypair
- Your public IP address (for RDP access restrictions)

## Project Structure

```
AWS-AD-Lab-Setup/
├── README.md                 # This file
├── LICENSE                   # MIT License
├── terraform/
│   ├── main.tf              # VPC, subnet, security groups, EC2 instance
│   ├── variables.tf         # Input variables and defaults
│   ├── output.tf            # Output values (currently empty)
│   └── terraform.tf         # Terraform version and provider requirements
└── powershell/
    └── ad-setup.ps1.tpl     # PowerShell script for AD configuration
```

## Configuration

### Variables

Edit `terraform/variables.tf` to customize your deployment:

| Variable | Description | Default |
|----------|-------------|---------|
| `region` | AWS region for deployment | `us-east-1` |
| `allowed_ip` | Your public IP for RDP access (CIDR format) | `YOUR_PUBLIC_IP/32` |
| `windows_ami` | Windows Server 2022 AMI ID | `ami-0568a51f9c63f2f7a` (us-east-1) |
| `keypair_name` | Existing AWS EC2 keypair name | *Required* |
| `domain_name` | Active Directory domain name | `example.local` |
| `netbios_name` | NetBIOS name for the domain | `EXAMPLE` |
| `ad_password` | SafeMode Administrator password | `EnterYourPassword` |

## Sample Active Directory Objects

The PowerShell script creates the following structure:

### Organizational Units (OUs)
- `Users` - Contains user accounts
- `Groups` - Contains security groups

### Users
1. Alice Johnson (alicej@example.local)
2. Bob Smith (bobsmith@example.local)
3. Charlie Lee (charliel@example.local)
4. Dana White (danaw@example.local)
5. Evan Brown (evanb@example.local)

**Default Password**: `Welcome123!`

### Groups
- Group1 through Group5 (Global Security Groups)

Each user is automatically added to their corresponding group (Alice → Group1, Bob → Group2, etc.)

## Usage

### 1. Configure Your Variables

```bash
cd terraform
```

Edit `variables.tf` with your specific values:

```hcl
variable "allowed_ip" {
  default = "203.0.113.0/32"  # Replace with your public IP
}

variable "keypair_name" {
  default = "my-keypair"       # Your existing AWS keypair
}

variable "domain_name" {
  default = "mycompany.local"
}

variable "netbios_name" {
  default = "MYCOMPANY"
}

variable "ad_password" {
  default = "YourSecurePassword123!"
}
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review the Plan

```bash
terraform plan
```

### 4. Apply the Configuration

```bash
terraform apply
```

Terraform will:
- Create the VPC infrastructure
- Launch a Windows Server 2022 EC2 instance
- Execute the PowerShell script to configure Active Directory
- Initialize OUs, groups, and users

## Accessing the Lab Environment

### RDP Connection

Once deployed (typically 10-15 minutes for AD initialization):

1. Get the instance public IP from AWS Console or Terraform outputs
2. Use Remote Desktop Client to connect:
   - **Host**: `<public-ip>`
   - **Username**: `Administrator`
   - **Password**: Use the AD password from variables.tf

### Active Directory Access

Within the instance:
- **Domain**: `example.local` (or your configured domain_name)
- **LDAP**: Port 389
- **LDAPS**: Port 636

## Security Considerations

⚠️ **Important**: This is a lab environment. For production use:

- Change all default passwords
- Restrict RDP access to specific IPs (already implemented with `allowed_ip`)
- Use AWS Secrets Manager for sensitive data
- Enable CloudTrail logging
- Implement network segmentation
- Use VPN for remote access instead of direct RDP
- Regularly patch Windows and Active Directory

## Networking

### Security Group Rules

**Ingress**:
- **RDP (3389/TCP)**: From `allowed_ip` only
- **LDAP (389/TCP)**: From anywhere (0.0.0.0/0)
- **LDAPS (636/TCP)**: From anywhere (0.0.0.0/0)

**Egress**: All traffic to 0.0.0.0/0

## Troubleshooting

### AD Services Not Starting

- Connect via RDP to the instance
- Check Event Viewer for AD-related errors
- Review CloudWatch logs

### Cannot Connect via RDP

- Verify your public IP is correctly set in `allowed_ip`
- Confirm security group rules in AWS Console
- Check instance is in "running" state

### PowerShell Script Errors

- View EC2 System Log in AWS Console
- Check that Windows Server AMI ID is correct for your region

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

This will remove the VPC, subnet, security groups, and EC2 instance.

## Requirements

- Terraform >= 1.0.0
- AWS Provider >= 5.0
- Windows Server 2022 AMI (or update the AMI ID for your region)
- Sufficient AWS quota for VPC, EC2, and Elastic IPs in your region

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

Created by Daniel Sibaja (DaNtR3)

## Notes

- The EC2 instance runs Windows Server 2022
- AD initialization takes approximately 10-15 minutes after instance launch
- The PowerShell script is template-based and receives variables from Terraform
- All resources are tagged with descriptive names for easy identification in AWS Console

## Future Enhancements

Potential improvements for this project:

- Add Terraform outputs for instance IP and connection information
- Implement DNS records for the domain
- Add support for multiple domain controllers
- Integrate with AWS Secrets Manager for password management
- Add monitoring and alerting with CloudWatch
- Support for custom OU structures and user provisioning
