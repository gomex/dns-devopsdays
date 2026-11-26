# Testes que rodam sem conta na Cloudflare: o provider é simulado, então
# qualquer pessoa roda `terraform test` localmente e o PR de fork também.

mock_provider "cloudflare" {}

# A zona é importada, e provider simulado não importa nada sozinho: este
# bloco diz o que a "Cloudflare de mentira" devolve na importação.
override_resource {
  target = cloudflare_zone.this
  values = {
    id = "zona-de-teste"
  }
}

# O mesmo para os registros que já existiam na Cloudflare (imports.tf).
override_resource {
  target = cloudflare_dns_record.this
  values = {
    id = "registro-de-teste"
  }
}

variables {
  cloudflare_account_id = "conta-de-teste"
  cloudflare_zone_id    = "zona-de-teste"
}

# O arquivo de verdade: confere os registros que existem hoje.
run "registros_atuais" {
  command = plan

  assert {
    condition     = length(cloudflare_dns_record.this) == 13
    error_message = "O registros.yaml deveria gerar 13 registros."
  }

  assert {
    condition     = cloudflare_zone.this.name == "devopsdays.com.br"
    error_message = "A zona deveria ser devopsdays.com.br."
  }

  assert {
    condition     = alltrue([for r in cloudflare_dns_record.this : r.proxied == false])
    error_message = "redirect.name e Canva só funcionam sem proxy."
  }

  assert {
    condition     = cloudflare_dns_record.this["CNAME www"].name == "www.devopsdays.com.br"
    error_message = "O nome deveria virar o FQDN."
  }

  assert {
    condition     = cloudflare_dns_record.this["TXT _redirect.www"].content == "\"Redirect to https://devopsdays.org/events\""
    error_message = "O TXT deveria ganhar aspas."
  }

  assert {
    condition     = length([for k, r in cloudflare_dns_record.this : r if r.type == "NS" && r.name == "ms.devopsdays.com.br"]) == 4
    error_message = "O ms deveria estar delegado para 4 servidores de nome."
  }

  assert {
    condition     = cloudflare_dns_record.this["A links.salvador"].ttl == 3600
    error_message = "O TTL padrão deveria ser 3600."
  }
}

run "raiz_proxy_mx_e_dois_txt" {
  command = plan

  variables {
    arquivo_registros = "tests/exemplos/completo.yaml"
  }

  assert {
    condition     = cloudflare_dns_record.this["A @"].name == "exemplo.com.br"
    error_message = "@ deveria virar a raiz da zona."
  }

  assert {
    condition     = cloudflare_dns_record.this["A @"].ttl == 1 && cloudflare_dns_record.this["A @"].proxied
    error_message = "Com proxy, o TTL deveria ser automático (1)."
  }

  assert {
    condition     = cloudflare_dns_record.this["MX @"].priority == 5
    error_message = "A prioridade do MX deveria vir do YAML."
  }

  assert {
    condition     = cloudflare_dns_record.this["verificacao"].content == "\"ja-com-aspas\""
    error_message = "TXT que já tem aspas não deveria ganhar outras."
  }
}

# Erros que o pipeline precisa barrar antes de chegar na Cloudflare.

run "barra_chave_repetida" {
  command = plan
  variables {
    arquivo_registros = "tests/exemplos/chave-repetida.yaml"
  }
  expect_failures = [terraform_data.validacao]
}

run "barra_nome_com_dominio" {
  command = plan
  variables {
    arquivo_registros = "tests/exemplos/nome-com-dominio.yaml"
  }
  expect_failures = [terraform_data.validacao]
}

run "barra_cname_na_raiz" {
  command = plan
  variables {
    arquivo_registros = "tests/exemplos/cname-na-raiz.yaml"
  }
  expect_failures = [terraform_data.validacao]
}

run "barra_proxy_em_txt" {
  command = plan
  variables {
    arquivo_registros = "tests/exemplos/proxy-em-txt.yaml"
  }
  expect_failures = [terraform_data.validacao]
}

run "barra_tipo_invalido" {
  command = plan
  variables {
    arquivo_registros = "tests/exemplos/tipo-invalido.yaml"
  }
  expect_failures = [terraform_data.validacao]
}
