output "servidores_de_nome" {
  description = "Servidores DNS da Cloudflare para cadastrar no Registro.br."
  value       = cloudflare_zone.this.name_servers
}

output "status_da_zona" {
  description = "pending até o Registro.br apontar para a Cloudflare; depois, active."
  value       = cloudflare_zone.this.status
}
