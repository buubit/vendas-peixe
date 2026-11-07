# VDfish — contexto do projeto

App Android (Flutter) de vendas de pescados, usado por **um único usuário** (representante comercial dos produtos da JJE Pescados) num celular Android. Offline, com banco SQLite no próprio aparelho. Interface e conversa sempre em **português do Brasil**. O usuário não é programador: responda de forma direta, com passos simples.

## Regras de negócio (confirmadas pelo usuário — não mudar sem pedir)
- **Comissão de 5% sobre todas as vendas.** O percentual fica gravado em cada pedido (`pedidos.comissao`). Todo balanço mostra **valor total e comissão**.
- **Todo WhatsApp** (pedido, extrato, cobrança, resumo) vai para **um número só, o da base JJE: 11 91175-5030** (configurável em Mais). Nunca vai para o cliente.
- **Fechamento quinzenal:** vendas de 1 a 15 são pagas no dia 30 (ou no último dia do mês); vendas de 16 ao fim do mês são pagas no dia 15 do mês seguinte (configurável).
- **Produtos:** 95 itens das tabelas JJE de nov/2026, todos por kg e sem preço padrão (`lib/catalogo.dart`, inseridos via migração).
- **Preço por cliente:** a ficha do cliente mostra só os produtos com preço dele, salvos na hora ao adicionar. No pedido dá para lançar qualquer produto.
- **Preço promocional:** produto com preço na tabela do cliente vem travado. A caixinha "Preço promocional / fora da tabela" muda o preço só naquele pedido e marca o item (`itens.promo`, `itens.preco_tabela`) com o aviso **PREÇO PROMOCIONAL / FORA DA TABELA** no balanço e nas mensagens.
- Os quadrados verdes da tela de pedido se chamam **"Produtos recentes"** (os últimos comprados pelo cliente aparecem primeiro).

## Cuidados técnicos
- **Nunca perder dados do celular:** toda mudança de banco deve ser uma migração em `onUpgrade` (`lib/db.dart`). O banco está hoje na versão 3.
- **ID do pacote `br.vendaspeixe.vendas_peixe` não pode mudar.** O nome exibido é "VDfish".
- **Chave de assinatura:** os APKs são assinados com o `debug.keystore` original (fica em `%USERPROFILE%\.android\debug.keystore` no PC que publica). Sem essa mesma chave o Android recusa a atualização. Ela **nunca** vai para o GitHub (o repositório é público).

## Publicar uma atualização
O app consulta `releases/latest` de `buubit/vendas-peixe` ao abrir (`lib/atualizacao.dart`) e oferece "Atualizar".
1. Suba `version:` no `pubspec.yaml` (o número depois do `+` tem que aumentar).
2. Faça commit.
3. Rode `powershell -ExecutionPolicy Bypass -File publicar.ps1 "o que mudou"`. O script testa, compila, faz push e cria a GitHub Release com `vendas-peixe.apk`. Precisa do `gh` logado na conta `buubit`.

O CI (`.github/workflows/testes.yml`) só roda analyze e os testes.

Histórico das versões e passo a passo para continuar em outro PC: `HISTORICO.md`.

## Ambiente no PC original
As ferramentas portáteis ficam em `C:\dev` (Flutter 3.47.9, JDK 21, Android SDK, MinGit, gh). Antes de qualquer comando, carregue `. C:\dev\env.ps1`. Num PC novo, instale os mesmos componentes (o Flutter precisa do JDK 21, do Android SDK com platform 36/build-tools 36 e das licenças aceitas) e copie o `debug.keystore`.
