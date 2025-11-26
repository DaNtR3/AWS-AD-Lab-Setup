variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "allowed_ip" {
  description = "Your public IP for RDP access"
  default     = "YOUR_PUBLIC_IP/32"
}

variable "windows_ami" {
  description = "Windows Server AMI"
  default     = "ami-0568a51f9c63f2f7a" # Windows Server 2022 (us-east-1)
}

variable "keypair_name" {
  description = "Existing AWS keypair name"
}

variable "domain_name" {
  default = "example.local"
}

variable "netbios_name" {
  default = "EXAMPLE"
}

variable "ad_password" {
  default     = "EnterYourPassword"
  description = "SafeMode Administrator Password"
}
