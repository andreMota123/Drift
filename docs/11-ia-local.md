# IA local no Drift

Levantamento de 2026-10-15. Objetivo: usar a IA que já roda neste PC dentro do Drift, sem nuvem, sem conta e sem custo por uso.

## O que existe neste PC

| Serviço | Endereço | O que tem |
|---|---|---|
| Ollama 0.40.4 | `127.0.0.1:11434` | qwen3:14b (texto, ferramentas), qwen3.8:27b (texto, visão, ferramentas, contexto de 262 mil), gemma4:12b (texto, visão, áudio, ferramentas), qwen3:14b-code, qwen2.5-coder:14b, bge-m3 (busca por significado) |
| ComfyUI 0.37 | `127.0.0.1:8188` | Qwen-Image 2512 (gerar imagem), Qwen-Image-Edit 2511 e Flux Kontext (editar imagem), SDXL. Sem modelos de vídeo nem de aumento de resolução |
| Open WebUI | porta 8080 do contêiner | Interface de chat do Ollama |

Placa: RTX 5070 Ti com 16 GB.

### Testes feitos

- **Comando de edição em português** ("corte no segundo 12 e apague até 15"), com duas ferramentas oferecidas: o qwen3:14b chamou as duas, na ordem e com os valores certos, em 8,6 s contando o carregamento. O gemma4:12b chamou só a primeira e levou 40 s.
- **Memória da placa**: o qwen3:14b ocupa 10,4 GB. Antes da correção abaixo, o Drift ocupava até 7,8 GB com dez vídeos 4K, o que não cabe junto nos 16 GB.

## Pré-requisito: memória da placa (feito)

Commit `b4d06396`. Os decodificadores compartilham um único contexto da placa, e no PC o Drift mantém só os seis decodificadores ociosos mais recentes, liberando os que ficam dois minutos parados.

Medido com dez vídeos 4K HEVC: 7,8 GB e subindo antes, 3,9 GB estáveis depois. Suítes do motor: 138 testes passando.

## O que dá para fazer

### Com o modelo de texto (Ollama)

1. **Assistente dentro do Drift.** Painel de conversa em português que edita o projeto pelas mesmas ferramentas do acesso de agente (`McpDispatcher::apply`, dentro do processo, sem servidor). Cada pedido vira um passo de desfazer. É o item 19 da lista da 9.5, que estava parado por falta de modelo; agora o modelo é local.
2. **Legendas melhores.** Corrigir pontuação, nomes e palavras que o Whisper errou, mantendo os tempos.
3. **Tradução de legenda e legenda bilíngue.** Novidade da 9.5 que o Drift não tem.
4. **Capítulos, título, descrição e hashtags** a partir da transcrição.
5. **Vídeo longo em cortes curtos.** O modelo lê a transcrição, escolhe os trechos mais fortes e o Drift monta cada corte numa timeline em aba, em 9:16.
6. **Remover palavras de preenchimento e repetições** ("é…", "tipo", frase recomeçada), com a mesma revisão do "remover pausas".

### Com os modelos de visão (gemma4, qwen3.8)

7. **Buscar mídia pelo conteúdo** ("a parte em que aparece a caixa vermelha"): descrição de quadros-chave guardada junto da mídia, com busca por significado pelo bge-m3.
8. **Escolher a capa** entre quadros candidatos.

### Com o ComfyUI

9. **Adesivo e fundo gerados por IA** (Qwen-Image), direto para o painel de mídia.
10. **Capa editada por IA** (Qwen-Image-Edit): o quadro escolhido com título e retoque.

### Modelos que rodam dentro do Drift (ONNX Runtime, que o Drift já usa)

11. **Aprimorar qualidade**: Real-ESRGAN general x4v3 (BSD, 4 MB).
12. **Legenda mais rápida**: Whisper tiny e base (MIT, 74 a 141 MB), além do small atual.
13. **Pincel inteligente de recorte**: SlimSAM (Apache, 37 MB).
14. **Narração em português**: Piper com vozes pt-BR. Ainda não testado.

## Cuidados

- **Placa compartilhada.** O Drift pede ao Ollama que descarregue o modelo ao terminar (`keep_alive`), para devolver a memória à pré-visualização e à exportação.
- **Sandbox do Flatpak.** O manifesto já tem `--share=network`, então o Drift alcança `127.0.0.1:11434` (Ollama) e `127.0.0.1:8188` (ComfyUI) sem mudança de permissão.
- **Sem dependência obrigatória.** Tudo isso aparece só quando o Ollama ou o ComfyUI respondem; sem eles o Drift funciona como hoje.
- **Assistente que edita.** O assistente nunca apaga mídia nem salva por cima sem confirmar, e tudo que ele fizer sai com um Ctrl+Z.

## Ordem sugerida

1. ~~Assistente dentro do Drift (1)~~: feito em 2026-10-15, ver `docs/12-assistente.md`.
2. Legendas: correção e tradução (2, 3).
3. Cortes curtos a partir de vídeo longo (5) e palavras de preenchimento (6).
4. Aprimorar qualidade e Whisper menor (11, 12).
5. Busca de mídia pelo conteúdo (7) e capa (8, 10).
6. Adesivo e fundo por IA (9), pincel (13) e narração (14).
