# Menu principal e checkpoints persistentes

A demo inicia em `scenes/ui/main_menu.tscn`.

## Para jogar

- **Novo jogo:** começa na chegada a Attis, no Dia 1, com carta e fusível. Se houver um checkpoint válido, pede confirmação antes de substituí-lo.
- **Continuar:** carrega o **início do último dia salvo**. O botão mostra disponibilidade e o texto abaixo informa o dia. Fica desabilitado quando não há save válido.
- **Sair:** fecha o jogo.
- **Esc durante a campanha:** abre uma pausa real, suspendendo jogador, animais, ajudante, radiação e demais processos de gameplay. Oferece Retomar, Menu principal, Controles e Sair do jogo. Esc novamente retoma. Se uma carta/caderno/puzzle estiver aberto, o primeiro Esc fecha essa interface. Sono, transição de porta e cutscene não podem ser interrompidos por esse menu.

Mouse, foco visível e navegação de teclado pelas setas/Tab e Enter permitem operar os botões. O menu informa que o salvamento acontece ao começar cada dia. Não há um botão de salvar a posição atual.

O menu usa uma cópia visual do cenário real de Attis, com a entrada das instalações e floresta lateral. A câmera oscila lentamente. Antes de adicionar a cópia à árvore, o sistema retira scripts, jogador, NPCs e itens físicos, desabilita navegação/colisões e oculta o evento final. O fundo não inicia a campanha, não modifica objetivos e não mantém o robô trabalhando.

## Quando o jogo salva

| Momento | Checkpoint |
|---|---|
| Iniciar Novo jogo | Chegada ao Dia 1, carta e fusível iniciais. |
| Dormir ao concluir o Dia 1 | Alojamento no início do Dia 2, tarefas renovadas e histórico do Dia 1. |
| Dormir ao concluir o Dia 2 | Alojamento no sonho/Dia 3, bilhete e blecaute. |
| Morrer | Restaura o checkpoint diário existente; não grava o estado da morte. |
| Voltar ao menu ou fechar o jogo | Mantém o último checkpoint diário; descarta o trabalho feito depois dele ao usar Continuar. |
| Encerrar a demo | Mantém o início do sonho, permitindo revê-lo com Continuar. |

O save inclui progresso do dia, histórico, plantas fertilizadas/amostradas, inventário com seleção e conteúdos independentes dos coletores, depósito, itens físicos registrados entre áreas e transformação do jogador no checkpoint. Vida/estamina voltam aos valores iniciais do despertar; animais e robô retomam a configuração do início do dia, sem serializar trajetos/combate intermediários.

Os checkpoints em memória continuam sendo usados na morte. Agora o mesmo estado diário também pode ser gravado em disco. F6 nas cenas de teste/níveis continua funcionando sem sobrescrever a partida real: a persistência só é habilitada ao entrar por Novo jogo/Continuar do menu. Em uma partida persistente, F9 de desenvolvimento também grava o despertar do dia avançado; use testes isolados para preservar seu checkpoint real.

## Arquivo e recuperação

`user://daily_checkpoint.tres`, na pasta de dados do usuário do Godot para Habitat Zero. Para encontrá-la, usar **Projeto → Abrir pasta de dados do usuário** no editor. O arquivo é um recurso local com versão de formato 1.

A escrita passa primeiro por `daily_checkpoint.tres.pending.tres`. Antes de substituir o principal, uma cópia válida anterior é preservada em `daily_checkpoint.tres.bak.tres`; então o temporário é renomeado para o principal. Se o principal estiver inválido, Continuar tenta o backup e indica a recuperação no texto do menu. Um principal inválido não substitui um backup válido. Falhas de gravação são informadas no HUD, preservando o checkpoint em memória e os arquivos anteriores quando possível.

O backup pode corresponder a um dia anterior. Não existe seleção de múltiplas partidas nem promessa de compatibilidade automática com futuras alterações no formato. Saves são locais, sem sincronização online.

## Arquivos e manutenção

- `scripts/save/daily_checkpoint.gd`: contêiner Resource com versão, data e estado diário.
- `scripts/save/save_system.gd`: validação, leitura sem reaproveitar cache, escrita e backup.
- `scripts/demo/demo_session.gd`: captura/restauração do checkpoint, Novo jogo, Continuar e retorno ao menu.
- `scripts/ui/main_menu.gd` e `scenes/ui/main_menu.tscn`: apresentação e ações do menu.
- `scripts/ui/game_menus.gd`: pausa real, retomada e saída da campanha.
- `scripts/ui/menu_style.gd`: cores, foco, hover e aparência comum dos botões.

Para mudar o enquadramento do fundo, editar **MenuCamera** (posição/FOV) e **CameraFocus** (ponto observado) em `main_menu.tscn`. No nó raiz, **Camera Sway Distance** e **Camera Sway Speed** controlam amplitude/velocidade do movimento. A câmera usa o foco a cada quadro; sua rotação manual é substituída pelo olhar dirigido a esse marcador. O fundo é carregado em execução, sem duplicar o mapa salvo. Não alterar Attis para ajustar apenas o menu.

Se o editor já estava aberto quando a cena principal foi trocada e F5 ainda iniciar na floresta, reabrir o projeto. Para conferir imediatamente, abrir `scenes/ui/main_menu.tscn` e usar F6.
