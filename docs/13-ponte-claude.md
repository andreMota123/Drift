# Escolher entre a IA local e o Claude

Feito em 2026-10-15. Há dois caminhos, e os dois podem conviver.

## 1. O Claude edita o Drift a partir da conversa

O Drift ficou registrado como ferramenta (MCP) no Claude Code, para todas as pastas:

```bash
claude mcp add --scope user drift -- flatpak run org.cutwire.Drift --mcp-stdio
```

O acesso de agente do Drift passou a ligar sozinho a cada abertura:

```bash
flatpak override --user --env=DRIFT_MCP_AUTOSTART=1 org.cutwire.Drift
```

Ele só aceita conexões deste PC e usa uma senha nova a cada abertura. Conferido com o Drift aberto: `claude mcp list` mostra `drift … ✔ Connected`.

**Como usar:** com o Drift aberto, peça ao Claude numa conversa nova do Claude Code, por exemplo: "no Drift, corte os 2 primeiros segundos e ponha o título 'Natal 2026'". Ele edita o projeto aberto, e o Ctrl+Z do Drift desfaz.

**Para desligar:**

```bash
claude mcp remove --scope user drift
```

```bash
flatpak override --user --unset-env=DRIFT_MCP_AUTOSTART org.cutwire.Drift
```

## 2. "Claude" na lista de modelos da aba Assistente

Na lista do topo da aba Assistente, além dos modelos do Ollama, aparece **Claude**. Escolhendo-o, o pedido vai para o Claude pela sua conta, sem chave de API. As ações aparecem na conversa como as do modelo local, com o mesmo aviso de falha e o mesmo "Desfazer este pedido".

### Como funciona

1. **O Drift** liga o próprio acesso de agente, se estiver desligado.
2. **O Drift envia o pedido à ponte** (`~/.local/bin/drift-claude-ponte`), um pequeno serviço deste PC em `127.0.0.1:11500`. O endereço e a senha do acesso de agente vão junto.
3. **A ponte roda o Claude Code** em modo não interativo (`claude -p`):
   - só com as ferramentas do Drift: sem terminal, sem arquivos, sem internet;
   - devolve os eventos ao Drift linha a linha;
   - guarda a conversa, para os pedidos seguintes continuarem o mesmo assunto.
4. **Durante o pedido, o acesso de agente recusa operações sensíveis**: salvar, exportar, abrir ou criar projeto, remover mídia, baixar do Market, mudar atalhos, tema e pacotes. Não há como perguntar a você no meio de um pedido do Claude, então ele é avisado para deixar isso com você.
5. **Segurança da ponte:** ela só aceita pedidos com o segredo de `~/.var/app/org.cutwire.Drift/config/drift-claude-ponte.token`, que ela mesma cria na primeira vez (permissão 600).

### O que falta você fazer (uma vez)

O modo automático do Claude Code não me deixa ativar a ponte como serviço permanente, porque ela abre um agente sozinha. Isso fica a seu critério.

1. **Entre no Claude Code de linha de comando**, que ainda não está logado. Abre o navegador:

```bash
claude auth login
```

2. **Ative a ponte** como serviço do usuário:

```bash
printf '[Unit]\nDescription=Ponte Drift - Claude Code\n\n[Service]\nExecStart=%%h/.local/bin/drift-claude-ponte\nRestart=on-failure\nEnvironment=PATH=%%h/.local/bin:/usr/local/bin:/usr/bin:/bin\n\n[Install]\nWantedBy=default.target\n' > ~/.config/systemd/user/drift-claude-ponte.service && systemctl --user daemon-reload && systemctl --user enable --now drift-claude-ponte
```

Depois disso, ao escolher "Claude" na aba, o ponto fica verde e aparece "Claude pronto, pela sua conta do Claude". Se algo faltar, a própria aba diz o quê (ponte desligada, Claude Code sem login).

**Para desligar a ponte:**

```bash
systemctl --user disable --now drift-claude-ponte
```

### Diferenças entre os dois

| | IA local (Ollama) | Claude |
|---|---|---|
| Onde roda | Neste PC | Nos servidores da Anthropic, pela sua conta |
| Custo | Nenhum | Conta do seu plano do Claude |
| Velocidade | 2 a 25 s por pedido | Depende da conexão; tende a ser mais lento para começar |
| Pedidos complicados | Se perde com mais facilidade | Mais confiável |
| Salvar e exportar | Pede confirmação na aba | Bloqueado; faça você |
| Memória da placa | Ocupa ~10 GB enquanto carregado | Nenhuma |

## Testes

- Suíte do agente: 113 testes, incluindo `blockedOpsAreRefused` (bloqueio de operações sensíveis).
- Aba com "Claude" escolhido e a ponte ausente: mostra o aviso certo.
- **Ainda não testado de ponta a ponta:** depende do login do Claude Code e da ponte ligada. Quando os dois estiverem prontos, o primeiro pedido pelo "Claude" na aba é o teste.
