# Assistente dentro do Drift

Feito em 2026-10-15, ramo `capcut-style`, commits `6ddcc700` e `26b97f73`.

## O que é

Uma aba **Assistente** no painel da esquerda, logo depois de Mídia. Você escreve o que quer em português ("corte no segundo 12 e apague até o 15", "coloque o título 'Natal 2026' no começo por 3 segundos", "abaixe a música para 40% e faça ela sumir no final") e o assistente edita o projeto aberto.

Tudo roda neste computador, pelo Ollama em `127.0.0.1:11434`. Nada sai da máquina e não há conta nem custo por uso. Sem o Ollama aberto, a aba avisa e o resto do Drift funciona normalmente.

## Como funciona

- **Modelo:** qwen3:14b por padrão. A lista no topo da aba mostra os modelos de conversa instalados no Ollama, e a escolha fica gravada (`assistant/model`).
- **Ações:** as mesmas que o Drift oferece a agentes externos (acesso de agente, MCP). O assistente chama `search`, `toolbox`, `inspect` e `apply` dentro do próprio processo, pelo `McpServer::handleRpc`, sem servidor nem senha.
- **O que o modelo recebe:**
  - o resumo do projeto aberto;
  - as regras do acesso de agente;
  - uma "cola" gerada na hora com as 34 ações mais usadas e o nome exato de cada argumento;
  - avisos sobre o ímã da faixa principal quando ele está ligado.
- **Um passo de cada vez:** o modelo aplica uma ação, lê o resultado e só então segue. No máximo 14 passos por pedido.
- **Temperatura 0:** o mesmo pedido no mesmo projeto dá o mesmo resultado.

## Segurança

- **Cada lote de ações aparece na conversa** com ✓ ou ✗.
- **Aviso independente do modelo:** se uma ação falhou ou foi parar em outro lugar (por exemplo, um título empurrado para depois porque o lugar estava ocupado), a própria aba avisa no fim, mesmo que o modelo diga que deu certo.
- **Desfazer este pedido:** volta o projeto ao estado de antes do pedido, num clique.
- **Confirmação:** ações que mexem em arquivos, configurações ou downloads (salvar, exportar, abrir projeto, remover mídia, baixar do Market, mudar atalhos e outras) param e perguntam Permitir ou Recusar.
- **Memória da placa:** a lixeira no topo da aba limpa a conversa e manda o Ollama descarregar o modelo, devolvendo cerca de 10 GB da placa de vídeo à pré-visualização e à exportação. Sem isso, o Ollama descarrega sozinho depois de 10 minutos parado.

## Mudança no acesso de agente

`add_text` passou a aceitar `duration` e `new_track`, e a responder `requested` e `placed`, como o `place_clip`. Com `new_track:true`, um título pedido para um momento ocupado vai para uma faixa de texto nova exatamente nesse momento. Sem a opção, o comportamento antigo continua (empurrar para o próximo espaço livre), porque agentes externos e testes dependem dele.

## Testes

- Suítes automáticas: agente 112 (com o novo `addTextNewTrackKeepsRequestedTime`), editor 144, motor 138, todas passando.
- **Pedidos reais, primeira rodada** (protótipo ligado ao mesmo motor): corte, título, velocidade, volume com fade e transição, todos certos, de 2 a 10 segundos cada.
- **Pedido composto, depois dos ajustes:** "divida no segundo 2, apague o pedaço antes e coloque o título 'Natal 2026' no começo por 3 segundos". Dentro do Drift, três repetições com o mesmo resultado certo: corte de 0 a 2 s em todas as faixas e título de 3 s no começo. Levou cerca de 15 a 25 segundos.

## Limites conhecidos

- **"Apague o pedaço"** vira um corte em todas as faixas (vídeo, música e textos), que é o jeito do CapCut de manter tudo sincronizado. Para cortar só o vídeo, diga isso no pedido.
- **Pedidos com muitas partes** podem esgotar os 14 passos. A aba sugere pedir uma coisa de cada vez.
- **Não enxerga o vídeo:** o qwen3:14b é só texto. Pedidos como "corte onde aparece a caixa" precisam de um modelo de visão (qwen3.8 ou gemma4), que é a etapa de busca por conteúdo do plano em `docs/11-ia-local.md`.
- **Arrastar e clicar nos botões** da aba ainda não foi testado com mouse: os testes enviaram os pedidos por um gatilho temporário no código.
