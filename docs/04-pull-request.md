# Pull request no projeto oficial

## Onde está

- Fork: https://github.com/andreMota123/Drift
- Branch enviado: `link-clips` (sobre a 0.5.1)
- Pull request: https://github.com/CutWire-Studios/Drift/pull/200, aberto pelo Andre em 12/09/2026, título "Link clips", sem descrição.

## Situação em 13/09/2026

| Item | Estado |
|---|---|
| Conflitos com o `main` | **sim** no branch enviado. Já resolvido localmente no branch `link-clips-v2`, que ainda não foi enviado. |
| CI | ainda não rodou |
| Descrição do PR | vazia |
| Commits | 2, ambos com o rodapé `Co-Authored-By` da IA e prefixos fora do padrão do projeto |

## Regras do projeto que afetam o PR

Do arquivo `CONTRIBUTING.md`:

1. **Uma mudança lógica por PR.** A correção de tradução deve sair deste PR. O manifesto já foi corrigido no main pelos mantenedores; as 27 frases traduzidas podem virar um PR próprio, junto com as demais frases que faltam.
2. **Conventional Commits.** Prefixos aceitos: `feat:`, `fix:`, `perf:`, `docs:`, `chore:`, `ci:`. Exemplo do próprio projeto: `feat: add timeline close-gap and per-clip split actions (#73)`.
3. **Frases novas exigem os catálogos atualizados** em `i18n/*.ts`. O CI recompara com o `lupdate` e falha se houver diferença.
4. **Não mexer no CHANGELOG.md.** Os mantenedores escrevem na hora do lançamento.
5. **Uso de IA.** Código gerado ou assistido por IA é aceito, desde que o autor tenha revisado e consiga explicar cada linha. É proibido automatizar commits ou PRs com IA, escrever a mensagem de commit com IA, e abrir issues ou comentários com IA. O rodapé `Co-Authored-By` de uma ferramenta de IA é visto como sinal de descumprimento e deve ser removido.

## O que já foi preparado

O branch `link-clips-v2` no repositório local contém a função Link reaplicada limpa sobre o `main` atual, com:

- todos os arquivos da função (ver `01-funcao-link.md`);
- as quatro frases novas inseridas nos 10 catálogos de tradução, na ordem que o `lupdate` gera;
- sem a correção de manifesto (já está no main) e sem as 27 traduções antigas (vão para outro PR).

As alterações estão gravadas num único commit provisório no branch `link-clips-v2`, enviado ao fork como cópia de segurança (https://github.com/andreMota123/Drift/tree/link-clips-v2). Ele junta as funções Link e Juntar e tem a mensagem escrita pela IA, com o rodapé de coautoria. **Antes de ir para o PR precisa ser refeito**: pela regra 1, um PR por função; pela regra 5, mensagem escrita pelo Andre, sem o rodapé.

## O que falta, em ordem

1. ~~Compilar sobre o main e rodar os testes.~~ Feito em 13/09: compila, suítes `Core` e `EditorState` passam, o teste de renderização passa com GPU.
2. O Andre revisar o diff (`git show HEAD` no branch `link-clips-v2`) e escrever duas mensagens de commit no padrão `feat: ...`, em inglês, com as próprias palavras: uma para Link, outra para Juntar.
3. Separar o commit provisório em dois, com essas mensagens e sem rodapé de IA. Enviar o commit de Link por cima do `link-clips` no fork (`git push --force-with-lease fork <commit>:link-clips`), o que atualiza o PR #200. Abrir um segundo PR só com Juntar.
4. O Andre escrever a descrição de cada PR no GitHub, com as próprias palavras.
5. Acompanhar o CI e os comentários dos mantenedores.

## Dados úteis para a descrição

Fatos que o Andre pode usar ao escrever, sem copiar:

- A ação Link vincula dois ou mais clipes selecionados que não têm vínculo, como um vídeo e um áudio gravado à parte, ou o áudio original depois de um Unlink.
- É um vínculo solto: seleciona, move, corta e apaga junto, mas não copia duração, cortes, velocidade nem fades, para não estragar clipes de tamanhos diferentes.
- Atalho Ctrl+Shift+L, botão na barra da timeline, item no menu de mais ações e no menu do clipe, comando `link_clips` para o agente.
- Teste unitário incluso; catálogos de tradução atualizados.
