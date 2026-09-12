# Interface em português

## Sintoma

O Drift do Flathub abria em inglês mesmo com o idioma configurado como Português (Brasil). A configuração estava gravada em `~/.var/app/org.cutwire.Drift/config/CutWire Drift/CutWire Drift.conf` como `language=pt_BR`.

## Causa

O arquivo de tradução `i18n/drift_pt_BR.ts` tinha 2043 frases, quase todas traduzidas. Mas o catálogo compilado dentro do pacote (`drift_pt_BR.qm`) tinha só 593.

Na compilação, a opção `DRIFT_AUTO_UPDATE_TRANSLATIONS` fica ligada por padrão fora do CI. Ela roda o `lupdate` do Qt antes de compilar os catálogos. Dentro do SDK do Flatpak, esse `lupdate` só enxerga os arquivos C++ listados para o alvo de tradução, e não os arquivos QML da interface. Como o projeto passa `-no-obsolete`, toda frase que o `lupdate` não encontra é apagada do catálogo. Resultado: todas as frases da interface somem, e só as mensagens de C++ ficam traduzidas.

Confirmação no log da compilação:

```
Updating '../i18n/drift_pt_BR.ts'...
    Found 593 source text(s) (2 new and 591 already existing)
```

## Correção

Passar `-DDRIFT_AUTO_UPDATE_TRANSLATIONS=OFF` nas opções de configuração do manifesto do Flatpak, nos dois arquivos (`org.cutwire.Drift.yml` e `org.cutwire.Drift.flathub.yml`). Com isso o pacote compila os catálogos como estão no repositório.

Depois da correção, o catálogo compilado passou a ter 2031 frases, e a interface abriu em português.

O `main` do projeto oficial já contém essa mesma correção, feita pelos mantenedores depois da 0.5.1. Por isso ela ficou fora do pull request.

## Frases que faltavam

Foram traduzidas as 27 entradas de `drift_pt_BR.ts` que estavam vazias na 0.5.1, sobre pastas de mídia, importação por arrastar, prévia rápida e resposta tátil. No `main` atual, o número de frases sem tradução em pt_BR subiu para cerca de mil, por causa das funções novas. É um trabalho separado, que pode virar outro pull request.

## Frases novas da função Link

| Contexto | Inglês | Português |
|---|---|---|
| AppController | Link clips | Vincular clipes |
| AppController | Clips linked | Clipes vinculados |
| TimelineToolbar | Link selected clips | Vincular clipes selecionados |
| TimelineClipItem | Link | Vincular |

O projeto exige que toda frase nova apareça em todos os catálogos (`i18n/*.ts`), na mesma ordem em que o `lupdate` a colocaria, que é a ordem de aparição no código. O teste `Translations` do CI recompara os catálogos com uma rodada nova do `lupdate` e falha se houver diferença. As entradas foram inseridas manualmente nos 10 catálogos seguindo essa ordem, logo depois das frases de Unlink correspondentes.
