variable "name" {
  type        = string
  description = "Name to be given for resources"
  default     = "staging"
}
variable "compute_count" {
  type        = number
  description = "Number of compute resources like NICs / VMs "
  default     = 2
  # based on value of this variable we create NIC / VMS / Backend Addresse pool of LB 
}
variable "vm" {
  type    = set(string)
  default = ["1", "2"]
}