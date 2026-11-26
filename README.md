# dns-devopsdays

DNS do **devopsdays.com.br** na Cloudflare, gerenciado com **Terraform**.

## Contextualização

O domínio é registrado no Registro.br, e os registros DNS ficavam no painel de lá, onde só quem tinha a senha conseguia mexer. Aqui eles viram código: qualquer pessoa da comunidade pode propor uma mudança por Pull Request, o pipeline testa e mostra o que vai mudar e, depois do merge e de uma aprovação, aplica na Cloudflare.

Ou seja, ninguém precisa da senha de nenhum painel para ajudar, e toda mudança fica registrada no histórico do git.

## Como propor uma mudança

Você só precisa editar o [`registros.yaml`](registros.yaml). Por exemplo, para criar `recife.devopsdays.com.br` redirecionando para a página do evento:

```yaml
  - nome: recife
    tipo: CNAME
    conteudo: alias.redirect.name
  - nome: _redirect.recife
    tipo: TXT
    conteudo: Redirect to https://devopsdays.org/events/2027-recife/welcome
```

Perceba que o `nome` vai **sem** o domínio, e que o TXT vai sem aspas: o Terraform cuida disso. A explicação de cada campo está no topo do arquivo.

Antes de abrir o PR, se quiser, rode os testes na sua máquina (não precisa de conta na Cloudflare):

```bash
terraform init -backend=false
terraform test
```

## O que o pipeline faz

Pense numa esteira com três estações, em que cada uma só libera a próxima se tudo estiver certo:

1. **testes** (todo PR, inclusive de fork): confere a formatação, valida o código e roda o `terraform test` com a Cloudflare simulada. É aqui que um nome com o domínio repetido, um CNAME na raiz ou um tipo inválido são barrados, com uma mensagem dizendo o que corrigir.
2. **plano**: mostra, no resumo do job, exatamente o que vai mudar na Cloudflare. Usa tokens **só de leitura**. Em PR de fork o GitHub não entrega segredo nenhum, então o plano aparece depois do merge, antes da aprovação.
3. **aplicar** (só na `main`): roda no environment `producao`, que pede a aprovação de quem mantém o repositório. Só ele tem os tokens de escrita.

Além disso, o workflow **drift** roda todo dia e falha se alguém mudou algo direto no painel da Cloudflare. A regra é: mudança no DNS entra **por PR**, NUNCA pelo painel.

## Configuração inicial (uma vez só)

Essa parte é para quem mantém o repositório.

Todos os tokens são **da conta** da Cloudflare (*Account API tokens*), e não de uma pessoa: se quem os criou sair, eles continuam funcionando. E os da Cloudflare enxergam **só** o `devopsdays.com.br`. Por isso a zona foi criada à mão no painel e importada pelo Terraform no primeiro apply, já que um token restrito a uma zona não consegue criar a própria zona.

1. **Zona.** No painel, *Add a domain* → `devopsdays.com.br`, plano Free. Pule a revisão dos registros: quem cuida deles é este repositório. Copie o **Zone ID**, que fica na coluna da direita da visão geral da zona.
2. **Bucket do state.** No R2, crie o bucket `dns-devopsdays-terraform`.
3. **Tokens do R2** (*R2 > Manage API tokens > Create Account API token*), restritos a esse bucket:
   - leitura (*Object Read only*) → secrets do repositório `R2_LEITURA_ACCESS_KEY_ID` e `R2_LEITURA_SECRET_ACCESS_KEY`;
   - escrita (*Object Read & Write*) → secrets do environment `producao` `R2_ESCRITA_ACCESS_KEY_ID` e `R2_ESCRITA_SECRET_ACCESS_KEY`.
4. **Tokens da Cloudflare** (*Manage Account > Account API Tokens > Create Token > Custom token*), com *Zone Resources: Include · Specific zone · devopsdays.com.br*:
   - leitura (*Zone: Read*, *DNS: Read*) → secret do repositório `CLOUDFLARE_TOKEN_LEITURA`;
   - escrita (*Zone: Edit*, *DNS: Edit*) → secret do environment `producao` `CLOUDFLARE_TOKEN_ESCRITA`.
5. **Variável** do repositório: `CLOUDFLARE_ACCOUNT_ID`.
6. **Primeiro apply.** Rode o workflow `terraform` na `main` e aprove. O resumo do job mostra os dois servidores de nome da Cloudflare. Se a zona for recriada um dia, o Terraform precisa de um bloco `import` para adotá-la de novo (veja o histórico do PR #1).
7. **Registro.br.** Troque os servidores DNS do domínio pelos dois do passo anterior. Quando a troca propagar, a saída `status_da_zona` passa de `pending` para `active`.

Os registros só passam a responder pela Cloudflare depois do passo 7. Até lá, quem responde continua sendo o Registro.br.

Para cadastrar os segredos, use o `gh` no seu terminal: ele pede o valor sem mostrar na tela e nada fica no histórico.

```bash
R=gomex/dns-devopsdays
gh variable set CLOUDFLARE_ACCOUNT_ID -R $R --body <id-da-conta>
gh secret set R2_LEITURA_ACCESS_KEY_ID      -R $R
gh secret set R2_LEITURA_SECRET_ACCESS_KEY  -R $R
gh secret set CLOUDFLARE_TOKEN_LEITURA      -R $R
gh secret set R2_ESCRITA_ACCESS_KEY_ID      -R $R --env producao
gh secret set R2_ESCRITA_SECRET_ACCESS_KEY  -R $R --env producao
gh secret set CLOUDFLARE_TOKEN_ESCRITA      -R $R --env producao
```

## Conclusão

DNS é uma daquelas peças que ninguém lembra até parar de funcionar. Com ele em código, testado no PR e aplicado com aprovação, a comunidade inteira pode cuidar dele sem medo de derrubar nada.
