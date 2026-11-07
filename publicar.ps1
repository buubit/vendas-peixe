# Publica uma nova versão do app:
#   1. suba "version:" no pubspec.yaml (ex.: 1.4.0+5 — o número depois do + precisa aumentar)
#   2. faça commit das mudanças
#   3. rode:  powershell -ExecutionPolicy Bypass -File publicar.ps1 "O que mudou nesta versão"
# O app no celular mostra "Nova versão disponível" e atualiza com um toque.
param([string]$notas = "Melhorias e correções.")
$ErrorActionPreference = 'Stop'
. C:\dev\env.ps1
Set-Location $PSScriptRoot

$versao = ((Select-String -Path pubspec.yaml -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value)
$tag = 'v' + ($versao -replace '\+', '-b')
& gh release view $tag *> $null
if ($LASTEXITCODE -eq 0) { throw "A versão $versao já foi publicada. Suba o número em pubspec.yaml." }

flutter test
if ($LASTEXITCODE -ne 0) { throw 'Testes falharam.' }
flutter build apk --release
if ($LASTEXITCODE -ne 0) { throw 'Falha no build.' }
Copy-Item build\app\outputs\flutter-apk\app-release.apk vendas-peixe.apk -Force

git push origin main
if ($LASTEXITCODE -ne 0) { throw 'Falha no git push.' }
gh release create $tag vendas-peixe.apk --title ("Versão " + ($versao -split '\+')[0]) --notes $notas
if ($LASTEXITCODE -ne 0) { throw 'Falha ao criar a release.' }
Write-Output "Publicado $tag"
