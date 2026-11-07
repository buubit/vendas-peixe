# VDfish — histórico do projeto

Resumo de tudo o que foi conversado e feito até agora, para continuar o app em qualquer PC (ou numa sessão nova do Claude) sem precisar explicar de novo. As regras de negócio oficiais ficam no `CLAUDE.md`; aqui fica a história e o passo a passo.

## O que é
App Android (Flutter) para um representante comercial lançar as vendas de pescados da JJE Pescados. Funciona offline, com os dados guardados no próprio celular (SQLite).

## Linha do tempo

| Versão | O que mudou |
|---|---|
| 1.0 | App básico: cadastro de peixes, clientes e lançamento de vendas. |
| 1.1 | 95 produtos carregados das duas planilhas JJE de nov/2026 (Salmão, Peixes, Frutos do Mar, Carnes etc.). WhatsApp sempre para a base (11 91175-5030). Fechamento quinzenal. Comissão de 5% em todos os balanços. |
| 1.2 | Corrigido: produto não salvava ao ser adicionado no cliente. Novo: preço promocional com caixinha e aviso "PREÇO PROMOCIONAL / FORA DA TABELA" em todas as telas e mensagens. |
| 1.3 | App passa a procurar versões novas no GitHub ao abrir; botão "Atualizar". |
| 1.4 (1.4.0+5) | Nome do app virou **VDfish**. Quadrados verdes viraram "Produtos recentes", com os últimos usados primeiro. Versão atual no celular. |

Testes: 14, todos passando. O GitHub roda os testes sozinho a cada envio (`.github/workflows/testes.yml`).

## Como continuar mexendo no app

### Opção 1 — pelo Claude na nuvem (claude.ai/code)
Abra uma sessão com o repositório `buubit/vendas-peixe` e peça a mudança. O Claude lê o `CLAUDE.md` e este arquivo, altera o código, roda os testes e envia para o GitHub.
**Ele não consegue publicar a versão nova no celular**, porque a chave de assinatura não fica no GitHub. Para isso, use o PC (opção 2, passo "Publicar").

### Opção 2 — no PC
1. **Instale as ferramentas** (uma vez só): Flutter 3.47.9, JDK 21, Android SDK (platform 36 e build-tools 36, licenças aceitas), Git e GitHub CLI (`gh`). No PC original tudo fica em `C:\dev`, carregado com `. C:\dev\env.ps1`.
2. **Copie a chave**: pegue o `debug.keystore` da pasta `Downloads\VDfish_levar` e coloque em `%USERPROFILE%\.android\debug.keystore` (crie a pasta `.android` se não existir).
3. **Entre no GitHub**: `gh auth login` com a conta **buubit**.
4. **Baixe o código**: `git clone https://github.com/buubit/vendas-peixe` (ou `git pull` se já tiver).
5. **Publicar** uma versão nova:
   - aumente `version:` no `pubspec.yaml` (o número depois do `+` sempre sobe, ex.: `1.4.0+5` → `1.5.0+6`);
   - faça commit;
   - rode `powershell -ExecutionPolicy Bypass -File publicar.ps1 "o que mudou"`.
   O script testa, compila, envia e cria a versão no GitHub. No celular, abra o VDfish e toque em **Atualizar**.

## Cuidados importantes
- **A chave `debug.keystore` nunca vai para o GitHub** (o repositório é público). Guarde uma cópia em lugar seguro: se ela se perder, o celular não aceita mais atualização e seria preciso desinstalar o app (perdendo os dados, a não ser que faça backup antes).
- **Não mude o ID do pacote** `br.vendaspeixe.vendas_peixe`.
- **Mudanças no banco de dados** sempre como migração em `lib/db.dart` (hoje na versão 3), para não apagar os dados do celular.
- Faça **backup** pelo app (Mais → Fazer backup) antes de atualizações grandes.

## Pendências
- Levar o `debug.keystore` (pasta `Downloads\VDfish_levar`) para o PC do usuário e guardar uma cópia extra em lugar seguro.
