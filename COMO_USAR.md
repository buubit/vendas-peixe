# VDfish

## Instalar no celular (Android)
1. Baixe o arquivo `vendas-peixe.apk` no celular.
2. Toque nele para abrir. Se o Android avisar "fontes desconhecidas", toque em **Configurações**, permita para esse app (Chrome, Arquivos ou WhatsApp) e volte.
3. Toque em **Instalar**.
   - Se o Play Protect avisar, toque em **Mais detalhes → Instalar mesmo assim** (o app não está na Play Store, por isso o aviso).

## Primeiro uso
1. **Cadastros → Peixes**: cadastre os peixes (nome e se vende por kg, unidade ou caixa).
2. **Cadastros → Clientes**: cadastre os clientes com WhatsApp e o preço de cada peixe para ele.

## Dia a dia
- **Pedido**: toque no cliente → toque no peixe → digite a quantidade → **SALVAR PEDIDO**.
  - O preço do cliente já vem preenchido. Se ele ainda não tiver preço para aquele peixe, o app pede e salva.
- **Fechamento**: veja cada quinzena por cliente, envie o extrato pelo WhatsApp e marque como recebido.
- **A receber**: tudo que está em aberto. Vencidos em vermelho, com botão para cobrar no WhatsApp.

## Regra de pagamento
- Vendas do dia 1 ao 15 → pagamento dia 30 (fevereiro: último dia).
- Vendas do dia 16 ao fim do mês → pagamento dia 15 do mês seguinte.
- Dá para mudar em **Mais → Datas de pagamento**.

## Backup
Os dados ficam só no celular. Use **Mais → Fazer backup** toda semana e salve no Google Drive.
Para recuperar num celular novo: instale o app e use **Mais → Restaurar backup**.

## Para o desenvolvedor
Ferramentas em `C:\dev` (Flutter, JDK, Android SDK). Para compilar:
```
. C:\dev\env.ps1
cd C:\claude\vendas_peixe
flutter build apk --release
```
