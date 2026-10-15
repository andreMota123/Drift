# Cortes curtos a partir de um vídeo longo

Feito em 2026-10-15, ramo `capcut-style`, commit `85f1d228`. É o "vídeo longo em curtos" do CapCut, com a IA local.

## Como usar

1. O vídeo precisa ter legendas. Se ainda não tiver, gere na aba Legendas: a IA escolhe os momentos pelo que é falado.
2. **Menu › Cortes curtos deste vídeo…**
3. Escolha quantos (3, 5 ou 8) e a duração (30, 45, 60 ou 90 segundos) e clique em **Encontrar momentos**.
4. Cada sugestão aparece com:
   - título;
   - início e fim, e duração;
   - a primeira frase;
   - o motivo da escolha;
   - um botão ▶ que leva o cursor até ali para você assistir;
   - uma caixa de marcar.
5. **Criar N cortes**. Cada corte marcado vira um projeto vertical na pasta `<nome do projeto> - cortes`, ao lado do projeto (ou em Vídeos/Drift, se o projeto nunca foi salvo). Ao terminar aparece **Abrir a pasta dos cortes**.

O projeto aberto não é alterado em nenhum momento.

## Como funciona

### Escolher os momentos

- A IA lê as legendas da faixa original. Se houver tradução, ela fica de fora, porque está numa faixa acima.
- Em vídeos muito longos (mais de 400 linhas), as linhas são juntadas em blocos de pelo menos 8 segundos, para caber no modelo.
- O modelo (o mesmo do assistente, qwen3:14b) recebe as linhas numeradas com o tempo de cada uma e devolve, num formato fixo, a primeira e a última linha de cada momento, um título e um motivo.
- **Critérios pedidos ao modelo:** começo que prende sem precisar de contexto, uma ideia completa, final onde um pensamento termina. Ficam de fora cumprimentos, avisos e chamadas para o curso.
- **Ajustes do próprio programa:** se o momento ficar mais curto que 60% ou mais longo que 150% da duração pedida, o fim é empurrado ou puxado uma linha por vez. Momentos sobrepostos são descartados.

### Fazer cada corte

O Drift abre uma cópia de si mesmo sem janela (`--headless`) sobre uma cópia do projeto em JSON e, pelas ações do acesso de agente:

1. corta tudo o que fica antes e depois do momento (`cut_time_range`, que mantém imagem, som e legendas em sincronia);
2. muda a tela para 1080×1920 mantendo a taxa de quadros;
3. ajusta cada elemento:
   - vídeo ou imagem de tela cheia: preenche a tela vertical, recortando as laterais pelo centro;
   - títulos e legendas: largura total, mesma altura relativa na tela;
   - outros elementos (fotos, formas, adesivos): reduzidos na mesma proporção;
4. salva o projeto e confere que gravou.

## Testes

Vídeo de teste de 8 min 40 s com uma transcrição de 160 frases de uma aula de caixa de Natal:

- **Sugestões** (5 s com o qwen3): "Minha primeira venda de caixa de Natal" (1:31–2:07), "Como definir o preço certo" (2:22–2:50) e "Como fotografar para o Instagram" (3:01–3:43).
- **Os três cortes** viraram três projetos na pasta.
- **O primeiro, conferido na tela:** 36 s, 9:16, vídeo recortado no centro começando exatamente em 1:31 do original, com as 8 legendas do trecho na posição certa.
- **Suítes automáticas:** editor 145 e agente 113, passando.
- Os botões e as caixas de marcar do diálogo ainda não foram usados com mouse (os testes dispararam por um gatilho temporário).

Comparação de modelos na escolha dos momentos:

| Modelo | Resultado | Tempo |
|---|---|---|
| qwen3:14b | Bons começos; num momento terminou numa frase de outro assunto | 5 s |
| gemma4:12b | Bons finais, mas um começo era uma frase de transição; motivos em inglês | 12 s |

## Limites

- **Recorte só pelo centro.** Se a pessoa não estiver no meio do quadro, ajuste a posição no corte, ou use o reenquadramento por rosto (acesso de agente, `auto_reframe`), que ainda não está ligado aqui.
- **Os cortes não são exportados automaticamente:** abra cada projeto e exporte, o que permite ajustar antes.
- **Depende das legendas:** trechos sem fala, como música ou demonstração silenciosa, não são vistos pela IA.
- **Palavras de preenchimento** ("é…", "tipo", frases repetidas) ainda não são removidas; é o próximo item do plano.
