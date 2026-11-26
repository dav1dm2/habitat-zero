# Dano e recuperação

| Fonte | Valor | Referência |
|---|---:|---|
| Gambá, kiwi e casuário | 13,2 por acerto | `scripts/entities/npcs/animal_controller.gd` |
| Radiação na campanha | 1,78 por segundo | `RadiationZone` em `attis_interior.tscn` |
| Radiação padrão | 2,24 por segundo | `scripts/world/radiation_zone.gd` |
| Animal da sala de testes | 15,84 por pulso | `scripts/world/test_animal.gd` |

A zona da sala de máquinas causa dano durante o blecaute inicial, inclusive com o painel aberto. Restaurar a energia desativa o dano. No sonho, a zona também fica inativa.

1. Parar o jogo. Abrir `scenes/levels/attis_interior.tscn`, selecionar **RadiationZone** e alterar **Damage Per Second**, por exemplo de 1,78 para 1,9. Salvar e executar novamente.
2. Para os animais, abrir `scenes/entities/npcs/skunk.tscn`, `kiwi.tscn` ou `casuario.tscn`, selecionar o nó raiz e ajustar **Damage**, por exemplo de 13,2 para 14. Salvar e testar. Isso define o valor para as instâncias que herdam essa cena.
3. Para modificar apenas um indivíduo, selecionar esse NPC na cena de Attis/Habitat 1 e alterar **Damage** nessa instância. Esse override tem prioridade sobre o padrão da espécie/script.
4. Conferir no painel **Local** do editor. Alterações feitas na árvore **Remoto** durante a execução servem só àquela sessão e não ficam salvas.


Vida máxima de 100 pontos. A regeneração ocorre a 5 pontos/s após 20 segundos sem dano. A corrida do jogador é de 6,25 m/s e a caminhada de 4 m/s.
