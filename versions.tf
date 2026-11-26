terraform {
  required_version = ">= 1.10"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.29"
    }
  }

  # O state fica num bucket do R2, que fala a API do S3. O endereço do R2
  # leva o ID da conta, então ele vem da variável de ambiente
  # AWS_ENDPOINT_URL_S3 em vez de ficar escrito aqui. As credenciais são
  # AWS_ACCESS_KEY_ID e AWS_SECRET_ACCESS_KEY de um token do R2.
  backend "s3" {
    bucket = "dns-devopsdays-terraform"
    key    = "devopsdays.com.br/terraform.tfstate"
    region = "auto"

    # O R2 não é a AWS: essas checagens só fazem sentido lá.
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_path_style              = true

    # Trava o state com um arquivo .tflock no próprio bucket.
    use_lockfile = true
  }
}

# O token vem da variável de ambiente CLOUDFLARE_API_TOKEN.
provider "cloudflare" {}
