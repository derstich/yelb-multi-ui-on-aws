# Projekt & Region
variable "project_name" {
  type        = string
  default     = "illumio-yelb-ec2"
  description = "Name-Präfix für Ressourcen"
}

variable "aws_region" {
  type        = string
  default     = "eu-central-1"
  description = "AWS Region"
}

# Netzwerk
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "public_subnet_2_cidr" {
  type        = string
  default     = "10.0.2.0/24"
  description = "Zweites Public Subnet für den ALB"
}

# Separates Subnet für den Voter (gleiche VPC)
variable "voter_subnet_cidr" {
  type        = string
  default     = "10.0.10.0/24"
  description = "CIDR des separaten Public Subnet für den Voter in der bestehenden VPC"
}

# EC2 Allgemein
variable "instance_type" {
  type    = string
  default = "t3.micro"
}

# Anzahl UI-Instanzen hinter dem ALB
variable "ui_count" {
  type        = number
  default     = 4
  description = "Wie viele yelb-ui Instanzen hinter dem ALB laufen"
}

# Voter EC2
variable "voter_instance_type" {
  type        = string
  default     = "t3.micro"
  description = "Instance Type für den Voter"
}

variable "voter_interval_seconds" {
  type        = number
  default     = 60
  description = "Intervall in Sekunden zwischen Votes der Voter-Instanz"
}

# SSH & Sicherheit
variable "ssh_cidr" {
  type        = string
  default     = ""
  description = "CIDR für SSH-Zugriff (z. B. 203.0.113.5/32); leer = kein SSH"
}

# Automatisches KeyPair
variable "generated_key_name" {
  type        = string
  default     = "illumio-yelb-key"
  description = "Name des automatisch erzeugten EC2 KeyPairs"
}

variable "pem_output_path" {
  type        = string
  default     = "./illumio-yelb-key.pem"
  description = "Lokaler Pfad für die erzeugte PEM-Datei"
}

# Optional: GHCR (Illumio-Fork)
variable "use_ghcr_illumio_images" {
  type        = bool
  default     = false
  description = "true = GHCR (Illumio-Fork) Images nutzen; false = mreferre DockerHub"
}

variable "ghcr_username" {
  type        = string
  default     = ""
  description = "GitHub Benutzername für GHCR Login (falls benötigt)"
}

variable "ghcr_token" {
  type        = string
  default     = ""
  description = "GitHub Personal Access Token (GHCR; falls privat)"
  sensitive   = true
}
