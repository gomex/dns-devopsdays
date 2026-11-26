locals {
  config = yamldecode(file(var.arquivo_registros))
  zona   = local.config.zona

  tipos_permitidos = ["A", "AAAA", "CNAME", "TXT", "MX", "CAA", "SRV", "NS"]

  # Cada registro ganha uma chave estável, "<TIPO> <nome>". Ela é o endereço
  # do recurso no state: mudar o conteúdo atualiza o registro, mas mudar o
  # nome ou o tipo apaga e recria. Para ter dois registros do mesmo tipo no
  # mesmo nome (dois TXT, por exemplo), use o campo `chave`.
  lista = [
    for r in local.config.registros : merge(r, {
      chave = try(r.chave, "${upper(r.tipo)} ${r.nome}")
      tipo  = upper(r.tipo)
      fqdn  = r.nome == "@" ? local.zona : "${r.nome}.${local.zona}"
    })
  ]

  # Agrupa antes de montar o mapa: chave repetida vira a mensagem da
  # validação abaixo, e não um erro confuso do Terraform.
  por_chave        = { for r in local.lista : r.chave => r... }
  chaves_repetidas = [for k, v in local.por_chave : k if length(v) > 1]

  registros = { for k, v in local.por_chave : k => v[0] }
}

# As regras de quem edita o YAML. Se alguma falhar, o plano para aqui com
# uma mensagem explicando o que corrigir, antes de tocar na Cloudflare.
resource "terraform_data" "validacao" {
  input = local.zona

  lifecycle {
    precondition {
      condition     = length(local.chaves_repetidas) == 0
      error_message = "Registros com a mesma chave: ${join(", ", local.chaves_repetidas)}. Use o campo `chave` para diferenciar."
    }
    precondition {
      condition     = alltrue([for r in local.lista : contains(local.tipos_permitidos, r.tipo)])
      error_message = "Tipo de registro não suportado. Use um destes: ${join(", ", local.tipos_permitidos)}."
    }
    precondition {
      condition     = alltrue([for r in local.lista : !endswith(r.nome, ".${local.zona}") && r.nome != local.zona])
      error_message = "Escreva o `nome` sem o domínio: `www`, e não `www.${local.zona}`. Para a raiz, use `@`."
    }
    precondition {
      condition     = alltrue([for r in local.lista : !(r.tipo == "CNAME" && r.nome == "@")])
      error_message = "CNAME na raiz do domínio (@) não é permitido. Use A/AAAA."
    }
    precondition {
      condition     = alltrue([for r in local.lista : !try(r.proxy, false) || contains(["A", "AAAA", "CNAME"], r.tipo)])
      error_message = "`proxy: true` só vale para registros A, AAAA e CNAME."
    }
  }
}

resource "cloudflare_zone" "this" {
  account = { id = var.cloudflare_account_id }
  name    = local.zona
  type    = "full"
}

resource "cloudflare_dns_record" "this" {
  for_each = local.registros

  zone_id = cloudflare_zone.this.id
  name    = each.value.fqdn
  type    = each.value.tipo
  ttl     = try(each.value.proxy, false) ? 1 : try(each.value.ttl, 3600)
  proxied = try(each.value.proxy, false)
  comment = try(each.value.comentario, null)

  # A Cloudflare guarda o TXT entre aspas. Pôr as aspas aqui evita que todo
  # plano mostre uma diferença que não existe.
  content = each.value.tipo == "TXT" && !startswith(each.value.conteudo, "\"") ? "\"${each.value.conteudo}\"" : each.value.conteudo

  priority = each.value.tipo == "MX" ? try(each.value.prioridade, 10) : null

  depends_on = [terraform_data.validacao]
}
