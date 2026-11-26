# Controle de console / gamepad

O mapeamento usa o padrão Xbox reconhecido pelo Godot, com suporte a conexão USB ou Bluetooth já pareada pelo sistema operacional. Teclado e mouse continuam disponíveis na mesma partida. As dicas de HUD/interação e do menu mudam conforme o último dispositivo utilizado, sem exigir seleção manual.

## Mapeamento

| Ação | Controle Xbox / genérico compatível | Teclado/mouse preservado |
|---|---|---|
| Mover | Analógico esquerdo (LS), com velocidade proporcional | WASD |
| Olhar | Analógico direito (RS) | Mouse |
| Correr | LT segurado **ou** clique L3 para alternar | Shift segurado |
| Agachar | B ou clique R3 para alternar | Ctrl segurado |
| Pular | A | Espaço |
| Interagir, recolher, abrir porta, entregar na bancada | X | E |
| Usar ferramenta/item, ler carta equipada | RT | M1 |
| Item anterior / próximo | LB / RB; também direcional ← / → | Scroll ou teclas 1–4 |
| Arremessar item selecionado | Direcional ↓ | Q |
| Lanterna | Y | Alt esquerdo |
| Caderno | View/Back ou direcional ↑ durante gameplay | Tab |
| Pausa | Menu/Start | Esc |
| Confirmar em interfaces | A | Enter/Espaço/click |
| Voltar/fechar interface | B; View também fecha o caderno | Esc/Tab conforme interface |
| Navegar por botões | Direcional ou analógico esquerdo | Setas/Tab/mouse |
| Rolar cartas, tarefas e depósito | Analógico direito vertical | Scroll |

**LS/RS** são os analógicos; **L3/R3** são os cliques deles. **View/Back** é o botão pequeno à esquerda; **Menu/Start**, à direita. Os rótulos A/B/X/Y descrevem posições Xbox; controles de outras marcas podem usar símbolos diferentes para as mesmas posições.

A corrida alternada termina ao parar, agachar, esgotar a estamina ou abrir/fechar uma interface. B/R3 não precisam ficar pressionados para manter o agachamento; pressionar novamente levanta, respeitando a verificação de teto. Ctrl continua funcionando por pressão contínua. Usar o teclado novamente desativa os estados alternados do controle.

Com uma interface aberta, o direcional ↑ serve para navegar, sem fechar o caderno. Use View ou B para fechá-lo. Menu/Start primeiro fecha a interface ativa; fora dela, abre a pausa. B na pausa retoma. A tela final também recebe foco de botão, permitindo jogar novamente ou voltar ao menu sem mouse.

## Conectar e testar

1. Parear o controle nas configurações Bluetooth do sistema, ou conectar por USB.
2. Iniciar o jogo pelo menu. Mexer o analógico ou pressionar um botão deve trocar a legenda para controle.
3. Conferir LS/RS, A para confirmar e B para voltar. No jogo, experimentar X numa porta, RT no coletor e LB/RB para selecionar itens.
4. Confirmar se gatilhos e eixos respondem conforme a tabela. O mapeamento aceita qualquer índice de dispositivo, sem fixar o controle ao jogador 0.

Se o controle ativo desconectar durante gameplay, o jogo abre a pausa, preservando uma pausa já aberta. Interfaces são fechadas antes dessa pausa; sono/transições/cutscene não são interrompidos. Ao reconectar, pressionar um botão e retomar. Teclado/mouse continuam servindo como alternativa.

A conexão Bluetooth é responsabilidade do sistema operacional. Um dispositivo que não esteja reconhecido/mapeado corretamente pelo Godot pode precisar de configuração específica do seu modelo; não é possível garantir os índices de todos os controles genéricos. Esta rodada foi validada com **eventos de gamepad simulados**, não por manipulação física de um controle Bluetooth.

## Sensibilidade e zona morta

Abrir `scenes/entities/player/player.tscn`, selecionar a raiz **Player** e localizar a categoria **Controle / gamepad**:

| Propriedade | Padrão | Ajuste |
|---|---|---|
| Gamepad Look Speed | X=160, Y=120 graus/s | Aumentar para olhar mais rápido; X horizontal, Y vertical. |
| Gamepad Look Curve | 1,4 | Maior deixa pequenos movimentos mais precisos, preservando a velocidade máxima. |
| Gamepad Invert Y | Desligado | Liga a inversão vertical. |

Salvar antes de executar novamente. Um override na instância do jogador tem prioridade sobre o prefab.

Em **Projeto → Configurações do projeto → Mapa de entradas**, as ações `move_*` têm zona morta **0,18**; `look_*`, **0,20**; `sprint`/`use_item`, **0,25**. Se houver drift, aumentar um pouco a zona morta correspondente. Cada ação preserva seus eventos de teclado/mouse e acrescenta o evento do controle. Novas ações incluem `next_item`, `previous_item`, `toggle_crouch`, `sprint_toggle`, `notebook` e `pause_game`.

As entradas de menu `ui_*` preservam o comportamento nativo do Godot e garantem A/B, direcional e LS em execução. Não há tela de remapeamento, vibração ou mudanças nos arquivos de save nesta rodada.

## Integração

- `scripts/input/controller_support.gd`: identifica o último dispositivo, troca dicas, garante navegação de menus, rola textos e trata desconexão.
- `scripts/entities/player/player_controller.gd`: câmera por RS, curva de resposta, deslocamento proporcional e estados alternados.
- `scripts/entities/items/inventory_system.gd`: LB/RB e uso único por acionamento do RT, evitando repetição por oscilação do gatilho.
- `scripts/demo/demo_interface.gd`: ações de caderno/voltar, primeiro botão focado e textos adaptados.
- `scripts/ui/game_menus.gd`, `scripts/ui/main_menu.gd` e `scripts/demo/dream_flow.gd`: pausa, legenda e foco de seleção, inclusive no encerramento.

O olhar e as ações manuais continuam bloqueados em diálogos e na cutscene. Ao sair de uma interface, comandos de confirmação não devem virar pulo ou uso indevido de ferramenta. Mudanças de foco verificam se o botão continua na árvore antes de focá-lo.


## Limite observado

X está mapeado à interação. Na simulação automatizada, a verificação de recolher o fusível arremessado com X falhou. O pareamento e a coleta com um controle físico não foram aferidos nessa revisão.
