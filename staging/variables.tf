variable "name" {
    type = string
    description = "Name to be given for resources"
    default = "staging"
}
variable "compute_count" {
    type =  number
    description = "Number of compute resources like NICs / VMs "
    default = 2
}