# Legendas com IA local

Feito em 2026-10-15, ramo `capcut-style`, commit `ac67ebc2`.

## Onde fica

No editor de legendas (selecione um clipe de legenda), logo abaixo de Importar e Exportar:

- **Corrigir com IA**: corrige o que o Whisper ouviu errado.
- **Traduzir**: abre a lista de idiomas e cria a legenda bilíngue.

Enquanto trabalha, os botões dão lugar a uma barra de progresso com Cancelar. Tudo roda neste PC, pelo Ollama.

## Corrigir com IA

- As legendas vão para o modelo em lotes de 25, cada lote com as 3 linhas anteriores já corrigidas como contexto.
- **O modelo corrige:** ortografia e acentos, palavras mal ouvidas, maiúscula no começo das frases, nomes de pessoas, lugares, marcas e cursos, vírgulas e pontuação final.
- **O modelo não pode:** reescrever, traduzir, resumir, juntar ou dividir linhas.
- **Os tempos nunca mudam:** o modelo só vê e devolve o texto, uma linha por legenda. O Ollama é obrigado a responder no formato exato (saída estruturada com o número certo de linhas); um lote que voltar com outra contagem é descartado.
- **Proteção contra reescrita:** uma linha que mudou demais (menos de 55% de semelhança) fica como estava.
- **Revisão antes de aplicar:** a janela "Revisar correções das legendas" mostra cada linha alterada, riscada a antiga e embaixo a nova, com uma caixa de marcar. Só as marcadas são aplicadas, num único passo de desfazer.

## Traduzir

- Idiomas: português (Brasil), inglês, espanhol, francês, italiano, alemão, japonês e chinês simplificado.
- Cria uma cópia do clipe de legenda com o texto traduzido e os mesmos tempos, numa faixa nova logo acima da original, posicionada um pouco mais alta na tela para as duas linhas aparecerem juntas, como a legenda bilíngue do CapCut.
- Para ficar só com a tradução, apague ou oculte a faixa original.

## Modelo

As legendas usam o **gemma4:12b** (preferência `captions/model`). Se ele não estiver instalado, usam o modelo do assistente; se o assistente estiver no Claude, usam o qwen3:14b, porque as legendas ficam sempre neste PC.

Comparação feita com legendas reais em português cheias de erros ("ola pessoal… fita de ceda… pedassos… a maianna santos… curso sublime"):

| Modelo | Correção | Tempo |
|---|---|---|
| gemma4:12b | Acertou "seda", acentos, maiúsculas, "Maianna Santos", "Curso Sublime" e a pontuação | 11 s, incluindo carregar o modelo |
| qwen3:14b | Trocou "seda" por "cetim"; num ajuste das instruções, inventou acento em "Maíanna" | 1 s já carregado |
| qwen3.8:27b | Bom, mas também trocou "seda" por "cetim"; não cabe inteiro na placa | 32 s |

Na tradução para o inglês, o gemma4 também saiu melhor: manteve "Maianna Santos" e "Sublime" com maiúscula; o qwen3 deixou em minúscula.

## Testes

- Dentro do Drift, com um arquivo SRT de teste cheio de erros: corrigir, revisar, aplicar e traduzir para o inglês. As duas faixas ficaram certas e aparecem juntas na tela.
- Teste automático `subtitleTranslationAddsLaneAbove`, para a faixa traduzida. Suítes: editor 145, agente 113.
- Os botões e as caixas de marcar ainda não foram usados com mouse: nos testes, os comandos foram disparados por um gatilho temporário no código.

## Limites

- O modelo pode errar uma correção, como o "cetim" do qwen3. A revisão existe para isso: desmarque o que não quiser.
- A tradução não passa por revisão; um Ctrl+Z ou apagar a faixa nova desfaz.
- A legenda traduzida herda o estilo da original. Para diferenciar (fonte menor, outra cor), edite a faixa nova como qualquer legenda.
