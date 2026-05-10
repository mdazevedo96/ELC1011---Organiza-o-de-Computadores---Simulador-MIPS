################################################################################
# SIMULADOR MIPS - ELC1011 Organização de Computadores
# Aluno: Marcelo da Silva de Azevedo
# Matrícula: 2023520131
################################################################################

#1. Crie as vari´aveis para a simula¸c˜ao do processador MIPS.
#(a) Mem´oria. Ser˜ao simulados 3 segmentos de mem´oria com um tamanho inicial de 4096
#bytes. Cada segmento ser´a simulado como um vetor de inteiros (32 bits).
#i. Segmento de texto.
#ii. Segmento de dados.
#iii. Segmento da pilha.
.data
mem_text:     .space 4096         # Segmento .bin
mem_data:     .space 4096         # Segmento .dat
mem_stack:    .space 4096         # Segmento da Pilha
#iv. Arquivos .bin e .dat
arquivo_bin:  .asciiz "arquivo.bin"
arquivo_dat:  .asciiz "arquivo.dat"

#(b) Banco de Registradores de uso geral. Ser˜ao simulados 32 registradores de uso geral
#como um vetor de inteiros (32 bits)
#(c) Registradores de uso interno: PC e IR. Estes dois registradores s˜ao simulados como
#vari´aveis inteiras de 32 bits.
#(d) Campos das instru¸c˜oes. Cada campo pode ser simulado como uma vari´avel do tipo
#inteiro (32 bits).
reg:          .word 0:32          # Banco de 32 registradores
PC:           .word 0x00400000    # Contador de Programa inicial
IR:           .word 0             # Registrador de Instrução corrente
################################################################################

#2. Escreva um procedimento para verificar se um endere¸co pertence a um dos segmentos de
#mem´oria simulado

