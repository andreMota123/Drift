# Estado do trabalho e como enviar ao projeto oficial

Situação em 13 de setembro de 2026.

## O que está pronto

| Função | Atalho | Estado |
|---|---|---|
| Vincular clipes (Link) | Ctrl+Shift+L | compilada, testada, instalada |
| Juntar em um só vídeo (Combine) | Ctrl+Shift+J | compilada, testada, instalada |
| Clipe composto (Compound) | Alt+G, Ctrl+Shift+G | compilada, testada, instalada |
| Tradução completa no pacote | — | corrigida; o `main` já trazia a mesma correção |

A versão instalada na máquina, nos ramos `master` e `stable`, tem as três funções.

## Ramificações no seu GitHub

Fork: https://github.com/andreMota123/Drift

| Ramificação | Conteúdo | Base |
|---|---|---|
| `link-clips` | Link + correção de tradução | versão 0.5.1 (desatualizada) |
| `link-clips-v2` | Link + Juntar | `main` atual |
| `compound-clips` | Link + Juntar + Clipe composto | `main` atual |

A ramificação `compound-clips` é a boa: contém tudo, sobre o `main` atual, compilada e testada.

## O pull request no projeto oficial

Pull request aberto: https://github.com/CutWire-Studios/Drift/pull/200

Ele aponta para `link-clips`, que é a versão antiga e está com conflito. Antes de mexer nele, três coisas precisam ser resolvidas, todas por causa das regras do projeto no arquivo `CONTRIBUTING.md`.

### 1. Uma função por pull request

A regra é "uma mudança lógica por pull request". Como agora são três funções, o certo são três pull requests, ou um só com a função Link e os outros depois. A ramificação `compound-clips` traz as três juntas num histórico de dois commits, então precisa ser dividida.

### 2. As mensagens de commit têm que ser suas

O projeto aceita código feito com ajuda de inteligência artificial, mas proíbe mensagens de commit escritas por IA e pede que o rodapé `Co-Authored-By` de ferramentas de IA seja removido. Os dois commits atuais têm mensagem escrita pela IA e esse rodapé, e por isso não podem ir para o pull request como estão.

O que fazer: revisar o código e escrever uma frase para cada função, em inglês, no padrão `feat: descrição curta`. Exemplo do próprio projeto:

```
feat: add timeline close-gap and per-clip split actions (#73)
```

### 3. A descrição do pull request também tem que ser sua

Mesma regra. O que colocar está resumido no fim do documento `04-pull-request.md`.

## Passo a passo do envio

Depois de escrever as três frases, os comandos são estes. Rode um bloco de cada vez, na pasta `Drift-link`.

Reescrever os dois commits com as suas mensagens:

```bash
cd "Projeto Drift/Drift-link" && git checkout compound-clips && git rebase -i main
```

No editor que abrir, troque `pick` por `reword` nas duas linhas, salve, e escreva as suas mensagens quando o editor pedir. Apague o rodapé `Co-Authored-By`.

Enviar a versão corrigida ao fork:

```bash
cd "Projeto Drift/Drift-link" && git push --force-with-lease fork compound-clips
```

Abrir o pull request no projeto oficial:

- https://github.com/andreMota123/Drift/pull/new/compound-clips

Se preferir seguir a regra de uma função por pull request, avise que eu separo os commits por função antes desse passo.

## Por que a IA não abriu o pull request

O `CONTRIBUTING.md` do Drift proíbe automatizar commits, pull requests, issues e comentários com IA: a submissão tem que ser conduzida por uma pessoa. Por isso o código foi enviado ao seu fork, que é seu, mas o pull request no repositório oficial fica para você abrir. São dois cliques depois que as mensagens estiverem escritas.
