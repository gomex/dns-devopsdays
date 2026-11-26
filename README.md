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

1. **Bucket do state.** No R2 da conta da Cloudflare, crie o bucket `dns-devopsdays-terraform`.
2. **Tokens do R2** (*R2 > Manage API tokens*), restritos a esse bucket:
   - leitura (*Object Read*) → secrets do repositório `R2_LEITURA_ACCESS_KEY_ID` e `R2_LEITURA_SECRET_ACCESS_KEY`;
   - escrita (*Object Read & Write*) → secrets do environment `producao` `R2_ESCRITA_ACCESS_KEY_ID` e `R2_ESCRITA_SECRET_ACCESS_KEY`.
3. **Tokens da Cloudflare** (*My Profile > API Tokens*):
   - leitura (*Zone: Read*, *DNS: Read*) → secret do repositório `CLOUDFLARE_TOKEN_LEITURA`;
   - escrita (*Zone: Edit*, *DNS: Edit*, na conta toda, porque o Terraform cria a zona) → secret do environment `producao` `CLOUDFLARE_TOKEN_ESCRITA`.
4. **Variável** do repositório `CLOUDFLARE_ACCOUNT_ID` com o ID da conta.
5. **Primeiro apply.** Rode o workflow `terraform` na `main` e aprove. O resumo do job mostra os dois servidores de nome da Cloudflare.
6. **Registro.br.** Troque os servidores DNS do domínio pelos dois do passo anterior. Quando a troca propagar, a saída `status_da_zona` passa de `pending` para `active`.

Os registros novos só passam a responder depois do passo 6. Até lá, quem responde continua sendo o Registro.br.

## Conclusão

DNS é uma daquelas peças que ninguém lembra até parar de funcionar. Com ele em código, testado no PR e aplicado com aprovação, a comunidade inteira pode cuidar dele sem medo de derrubar nada.
