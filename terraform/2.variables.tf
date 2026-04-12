# terraform/variables.tf
variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "us-east-1"
}
variable "project_name" {
  description = "프로젝트 이름"
  type        = string
  default     = "boo-exercise"
}
variable "environment" {
  description = "환경 구분"
  type        = string
  default     = "dev"
}
variable "mongodb_password" {
  description = "MongoDB 비밀번호"
  type        = string
  sensitive   = true
  default     = "BooExercise2024"
}
variable "ssh_public_key" {
  description = "SSH 공개키"
  type        = string
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCoRNv3qVEDejGs/cz7Dtq6X8wkYwLy71ix8ct5W1F49pz6GLVQTj7j4BwSvlP6Spf7zxrHV0aMZUUpau1DH6LraymOkXoKSBiHFJeQaJlEIG9/WK22dcfrdnLMrLobPLr/gLz9xedqZeFZabBlTuZuUvNZMZyUYxkB3mRzUVf//RqOavyKuLrv/67GdwxxfT6B6c7SWKKRicApfIU4vcUY2z0lMcUorzTkczOkGPWxgNb5SmayeNhzLDA8I3X7zgMY2UlmVtvtCBVngecdFotXHtYZ3KTTfMXMOTLe/p9w1OUAKFjLlY/l4XkVb4VqBRGAVAX6aQLHLE8Nzjxy+ibowug9xLLl6LceBjSFv9PzsGN5cBjnIhu5qPzHfuyS5SsGHuD/Yk1vDQU8Qfs5A3jUQ80tHZ5X72Z7pAHw9h0rz/k2oGxpLSClCon6ILMUyw+0IdzfrGCEroDH/NRlnOZFDpw6BdViMWVihY37wIYrXv49DXX+hhoxcI/cIul+9//l0X6RQpxc+P3wPOLtHZW8rUlXBWhjvkOLg1ZuCq/B+a+liZxsrYkc7W9SwEkaJyJBk5hUL2lZjjU1WI+2MSnQouvgr703R9EgsjxiVS0PsL8BriLFK5LJlghJTZVkVltTmuikpvcl4A1Ux0SPKJtBKFzrJvrLhPvIK4oquUpx1w== sunghyun.boo@JL9P07T6TW"
}
