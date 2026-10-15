# Remover enchimento e repetições

Feito em 2026-10-15, ramo `capcut-style`, commit `4a6efd25`.

## Como usar

1. O vídeo precisa ter legendas (aba Legendas → gerar).
2. **Menu › Remover enchimento e repetições…** → **Encontrar**.
3. A janela lista cada trecho com:
   - o tempo e o tipo;
   - a frase com a parte que sai riscada em vermelho;
   - um ▶ que toca a partir de 1,5 s antes;
   - uma caixa de marcar.
4. **Cortar N trechos**. Tudo o que ficar marcado sai do vídeo, do som e das legendas ao mesmo tempo, num único desfazer.

Os quatro tipos:

| Tipo | O que é | Quem acha | Vem marcado? |
|---|---|---|---|
| Tomada repetida | Frase dita de novo logo depois quase igual: saem as anteriores, fica a última | Regra do Drift | Sim |
| Falso começo | Frase que é o começo de outra mais longa logo em seguida ("Depois é só postar a sua…") | Regra do Drift | Sim |
| Enchimento | "é", "ãh", "hum", "tipo", "né", "pô", "assim", "então" quando não acrescentam nada | IA local (gemma4) | Sim |
| Comentário | Fala para a equipe ou para si ("Isso.", "Pode ir?", "Ok.", "Ai, vem cá!") | IA local | Não |

Um trecho que não encontrou pausa numa das pontas vem desmarcado e com o aviso "ouça antes: sem pausa numa das pontas".

## Como funciona

1. **Frases inteiras.** As legendas cortam as frases no meio, então o Drift as junta num texto só e separa por frase. Na junção, "..." vira "…" e é recolocado o espaço que o transcritor às vezes come depois do ponto ("natal.Dessa"). Para cada letra, o Drift guarda de qual legenda ela veio e em que posição.
2. **Tomadas repetidas e falsos começos por regra, não pela IA.** Os modelos testados (gemma4 e qwen3) marcaram praticamente todas as frases como repetição, sem guardar a última. A regra compara as palavras:
   - **tomada repetida:** 70% ou mais das palavras em comum com uma das 8 frases seguintes;
   - **falso começo:** as primeiras palavras iguais às de uma frase mais longa logo depois.
3. **Enchimento e comentários pela IA local**, em lotes de 50 frases, com resposta em formato fixo. Uma frase já marcada como repetida não é mandada de novo para a IA.
4. **Tempo de cada trecho.** O transcritor não dá o tempo de cada palavra, então a palavra recebe a fatia proporcional do tempo da sua legenda. As duas pontas vão para a **pausa de verdade mais próxima**: um ponto bem abaixo do nível de fala ao redor, até 0,2 s de distância para palavras e 0,5 s para frases inteiras. Sem pausa por perto, fica o ponto mais baixo a até 0,12 s, e o trecho é marcado "ouça antes".
5. **Cortar.** Primeiro o texto das legendas perde as palavras (com a vírgula e o espaço em volta acertados), depois cada trecho é cortado de todas as faixas, do último para o primeiro. No fim, os pedaços de legenda que os cortes deixaram são juntados de volta num clipe só, e uma legenda partida ao meio volta a ser uma.

## Teste com uma gravação real

C6298.MP4 da pasta Deluxe: 1 min 48 s de gravação bruta, com várias tomadas repetidas. O arquivo não foi alterado.

**O que foi encontrado:**
- 9 tomadas repetidas, todas corretas, e em todas ficou a última versão:
  - "Vamos testar um pouco da sua criatividade?" e "Eu vou lançar um mega desafio." (ditas duas vezes);
  - as duas versões de "Vocês vão criar uma caixinha de natal…";
  - "Depois é só publicar…";
  - as várias de "Depois é só postar…";
  - "Usar a hashtag…";
  - "Os critérios são…".
- 1 falso começo e 2 enchimentos ("né", "pô").
- 5 comentários: "Isso.", "Pode ir?", "Ok.", "Ai, vem cá!", "Oh, ai, vem cá, ok.".
- Nenhuma frase dita uma vez só foi marcada.

**Precisão dos cortes:** 31 das 34 pontas caíram em silêncio, medido no áudio original. As 3 restantes estão onde a fala é corrida, sem pausa entre as tomadas; o Drift não encontrou pausa nessas pontas, então esses trechos vieram desmarcados.

**Resultado do corte dos marcados:** de 1:48 para 1:22, com as legendas num único clipe, seguindo a fala final, sem texto repetido nem pontuação solta.

**Testes automáticos:**
- `fillerSpansAreFoundAndRemoved`: palavras inteiras, limpeza de vírgulas e da maiúscula, e as tomadas repetidas reais acima;
- `cutCaptionsJoinBackIntoOneClip`.
- Suítes: editor 147, agente 113.

## Limites

- **Tempo das palavras estimado.** Para palavras curtas ("né", "é") o corte pode cair um pouco ao lado da palavra. As pontas ficam no silêncio, então nada é cortado pela metade, mas o "né" pode continuar lá. Ouça antes; Ctrl+Z desfaz.
- **Tomadas muito diferentes** (menos de 70% das palavras em comum, como "Depois até o dia 7 você posta.") não são reconhecidas como repetição.
- **Cortes em sequência** precisam de legendas: trechos sem fala não entram.
- **Os botões e as caixas de marcar** ainda não foram usados com mouse: nos testes, os comandos foram disparados por um gatilho temporário.

## Achado de passagem

O empacotamento das legendas do Whisper às vezes cola frases sem espaço ("natal.Dessa", "outubrocom"). A remoção de enchimento corrige isso internamente para achar as frases, mas o texto das legendas continua assim. Vale corrigir no `packSubtitleCues`.
