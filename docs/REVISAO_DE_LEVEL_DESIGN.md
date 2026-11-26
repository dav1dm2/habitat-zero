# Percurso e ferramentas do editor

## Avançar dias durante o desenvolvimento

Ao executar a campanha pelo editor:

| Tecla | Resultado |
|---|---|
| **F9** | Marca as metas atuais como cumpridas e avança pelo sono/despertar. Do Dia 1 vai ao Dia 2; outro acionamento, depois do despertar, leva ao sonho/Dia 3. |
| **F10** | Suspende ou reativa o gatilho automático do ritual. Usar já no sonho, antes de se aproximar do semicírculo, para caminhar e observar livremente. |

Esses controles são temporários e só ficam ativos no executável de desenvolvimento do editor. Um aviso no HUD identifica o dia e o estado de inspeção. Não alteram os requisitos do sono normal nem ficam disponíveis na exportação. F9 preserva inventário/ferramentas, usa as instalações para o despertar e não cria um Dia 4. Durante transições e cutscene, os atalhos não interrompem a sequência. F10 não desfaz uma cutscene já iniciada. Reiniciar a campanha limpa o modo de inspeção.

Alternativa: abrir `tests/preview_dream.tscn` e executar **F6** para começar diretamente no alojamento do sonho. F5 abre o menu principal.

## Ver e editar o Dia 3 sem executar o jogo

1. Parar a execução com **F8** e abrir `scenes/levels/attis_forest.tscn`.
2. Selecionar o nó raiz da cena. No Inspector, localizar **Prévia de level design — somente editor**.
3. Clicar em **Prévia do desfecho com luz de edição**. O campo `Editor Day Preview` também permite escolher Dia 1, Dia 2, Dia 3 / edição clara ou Dia 3 / noite.
4. Expandir `DreamEvent`, selecionar um NPC ou conjunto e pressionar **F** no viewport 3D para enquadrá-lo. A edição clara remove a névoa e ilumina o cenário; a opção noite permite comparar a atmosfera do sonho.
5. Mover os nós dos NPCs e marcadores na cena original e salvar. **Restaurar prévia normal** volta à apresentação cotidiana.

| Nó dentro de `DreamEvent` | O que editar |
|---|---|
| `DeadSkunks/DeadSkunk00…08` | Nove corpos de gambá (opossum), com identificadores de edição legados, distribuídos da porta pela trilha. Mover o nó do NPC para alterar sua posição real. |
| `DeerCircle/RitualDeer00…06` | Sete posições iniciais dos cervos no semicírculo. |
| `RitualCenter` | Destino central da caminhada do jogador. O gatilho acompanha esse marcador. |
| `RitualCenter/RitualTrigger` | Centro da região que inicia a cutscene; seu `CollisionShape3D` contém uma esfera de raio inicial de 10 m, usada pelo roteiro. |
| `TriggerApproach` | Referência visual de aproximação; não determina o disparo da cutscene. |

Os `EventSprite` agora estão gravados na cena, permitindo ver a apresentação dos NPCs no editor. Para posicionar os animais, mover seus nós pais; a prévia atualiza tamanho e deslocamento visual dos sprites. Não simula a IA. O gatilho é consultado por distância pelo roteiro, sem colisão física com o jogador.

O Dia 3 **não é outro mapa**. `DreamFlow` reaproveita Attis, aplica noite/névoa, desativa a fauna cotidiana e ativa `DreamEvent`. As instalações recebem o blecaute e a carta pelo estado global do sonho. A cutscene conduz fisicamente o jogador ao centro e depois aproxima os cervos. A prévia altera somente a apresentação no editor: mesmo salvando a cena com ela ligada, a execução restaura a iluminação original antes de aplicar o dia real. Não há uma cópia independente do mapa para manter sincronizada.

Após alterar relevo ou obstáculos que afetem o trajeto, usar **Atualizar caminhos dos NPCs** no nó raiz e testar novamente a caminhada do jogador e dos cervos. Mudanças de posição devem continuar sobre terreno transitável.
