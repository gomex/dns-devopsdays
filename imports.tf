# Registros que a Cloudflare copiou do Registro.br quando a zona foi
# adicionada no painel. Eles já existiam, então o Terraform os adota em vez
# de criar. Depois do primeiro apply, estes imports não fazem mais nada e
# podem ser apagados num PR futuro.
#
# O ID de cada registro veio da API da Cloudflare (GET /zones/<zona>/dns_records).
locals {
  registros_existentes = {
    "CNAME www"              = "aa2e6dd5d5191df6e38dd8850c642e5e"
    "TXT _redirect.www"      = "7f37ed8bf002f76a106d690913e32578"
    "TXT _redirect.poa"      = "e626297575472a117f42a05552e2fae8"
    "TXT _redirect.salvador" = "0abcf3517b7bc2545895b51ec7da5422"
    "A links.salvador"       = "ea63cf7909a8922c7e7f049e314b63ee"
    "TXT links.salvador"     = "6b44f491a9f7f0dfb1da1cf9c76de18f"
    "A www.links.salvador"   = "9d0b1cfb35b65524c067742b7267742d"
  }
}

# Só importa o que ainda está no registros.yaml: se alguém tirar um desses
# registros do YAML, o import some junto, em vez de quebrar o plano.
import {
  for_each = { for chave, id in local.registros_existentes : chave => id if contains(keys(local.registros), chave) }

  to = cloudflare_dns_record.this[each.key]
  id = "${var.cloudflare_zone_id}/${each.value}"
}
