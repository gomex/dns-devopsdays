variable "cloudflare_account_id" {
  description = "ID da conta da Cloudflare onde a zona é criada."
  type        = string
}

variable "cloudflare_zone_id" {
  description = "ID da zona, criada à mão no painel. O Terraform importa a zona em vez de criá-la, para os tokens poderem ser restritos só a ela."
  type        = string
}

variable "arquivo_registros" {
  description = "Arquivo YAML com a zona e os registros. Os testes trocam por arquivos de exemplo."
  type        = string
  default     = "registros.yaml"
}
