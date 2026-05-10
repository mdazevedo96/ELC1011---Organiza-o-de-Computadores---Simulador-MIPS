################################################################################
# SIMULADOR MIPS - ELC1011 Organização de Computadores
# Versão Final Corrigida e Otimizada
################################################################################

.data
# --- 1. Variáveis de Simulação (Tarefa 1) ---
reg:          .word 0:32          # Banco de 32 registradores
PC:           .word 0x00400000    # Contador de Programa inicial
IR:           .word 0             # Registrador de Instrução corrente

# Memória simulada (4096 bytes cada = 1024 palavras)
mem_text:     .space 4096         # Segmento .bin
mem_data:     .space 4096         # Segmento .dat
mem_stack:    .space 4096         # Segmento da Pilha

# Nomes dos arquivos (Devem estar na mesma pasta do .asm)
arquivo_bin:  .asciiz "arquivo.bin"
arquivo_dat:  .asciiz "arquivo.dat"

# Mensagem de erro
msg_erro:     .asciiz "\n[Erro] Instrução não implementada. PC: "

.text
.globl main
main:
    # --- Boot do Simulador ---
    # Inicializa o Stack Pointer ($sp = reg[29]) no topo da pilha simulada
    li   $t1, 0x7FFFEFFC
    sw   $t1, 116($zero)      # 116 = 29 * 4

    # --- Tarefa 5: Carregamento dos Arquivos (CORRIGIDO) ---
    la   $a0, arquivo_bin
    la   $a1, mem_text
    jal  carregar_ficheiro    # Chamada correta da função
    
    la   $a0, arquivo_dat
    la   $a1, mem_data
    jal  carregar_ficheiro    # Chamada correta da função

# --- Tarefa 6: Ciclo de Instrução ---
ciclo_principal:
    ## 6a. FETCH (Busca) ##
    lw   $t0, PC
    subu $t1, $t0, 0x00400000    # Offset para mem_text
    la   $t2, mem_text
    addu $t2, $t2, $t1
    lw   $t3, 0($t2)             # Busca instrução
    sw   $t3, IR

    ## 6b. DECODE (Decodificação) e Incremento PC ##
    addiu $t0, $t0, 4
    sw    $t0, PC
    
    srl  $s0, $t3, 26            # Opcode
    srl  $s1, $t3, 21            # rs
    andi $s1, $s1, 0x1F
    srl  $s2, $t3, 16            # rt
    andi $s2, $s2, 0x1F
    srl  $s3, $t3, 11            # rd
    andi $s3, $s3, 0x1F
    andi $s4, $t3, 0xFFFF        # imediato
    andi $s5, $t3, 0x3F          # funct

    ## 6c. EXECUTE (Execução) ##
    beq  $s0, 0,  exec_tipo_R    
    beq  $s0, 8,  exec_addi      
    #beq  $s0, 13, exec_ori       
    beq  $s0, 35, exec_lw        
    #beq  $s0, 43, exec_sw        
    #beq  $s0, 4,  exec_beq       
    beq  $s0, 36, exec_lbu       # Suporte para manipulação de string
    beq  $s0, 40, exec_sb        # Suporte para manipulação de string
    j    instrucao_desconhecida

# --- Implementação das Instruções ---

exec_tipo_R:
    beq  $s5, 32, op_add
    beq  $s5, 34, op_sub
    beq  $s5, 12, op_syscall
    j    instrucao_desconhecida

op_add:
    jal  ler_rs_rt
    addu $t8, $v0, $v1
    jal  escrever_no_rd
    j    ciclo_principal

op_sub:
    jal  ler_rs_rt
    subu $t8, $v0, $v1
    jal  escrever_no_rd
    j    ciclo_principal

exec_addi:
    jal  ler_rs_rt
    sll  $t6, $s4, 16
    sra  $t6, $t6, 16            # Extensão de sinal
    addu $t8, $v0, $t6
    jal  escrever_no_rt
    j    ciclo_principal

exec_lw:
    jal  ler_rs_rt
    sll  $t6, $s4, 16
    sra  $t6, $t6, 16
    addu $t6, $v0, $t6           # Endereço Virtual
    subu $t6, $t6, 0x10010000    # Mapeamento mem_data
    la   $t7, mem_data
    addu $t7, $t7, $t6
    lw   $t8, 0($t7)             # Carrega palavra
    jal  escrever_no_rt
    j    ciclo_principal

exec_lbu:
    jal  ler_rs_rt
    sll  $t6, $s4, 16
    sra  $t6, $t6, 16
    addu $t6, $v0, $t6
    subu $t6, $t6, 0x10010000
    la   $t7, mem_data
    addu $t7, $t7, $t6
    lbu  $t8, 0($t7)             # Carrega apenas 1 byte
    jal  escrever_no_rt
    j    ciclo_principal

exec_sb:
    jal  ler_rs_rt               # $v0 = rs (base), $v1 = rt (dado)
    sll  $t6, $s4, 16
    sra  $t6, $t6, 16
    addu $t6, $v0, $t6           # Endereço de destino
    subu $t6, $t6, 0x10010000
    la   $t7, mem_data
    addu $t7, $t7, $t6
    sb   $v1, 0($t7)             # Salva apenas 1 byte
    j    ciclo_principal

op_syscall:
    lw   $t4, reg+8              # $v0 simulado
    lw   $t5, reg+16             # $a0 simulado
    beq  $t4, 4,  sys_print_string
    beq  $t4, 11, sys_print_char
    beq  $t4, 10, fim_simulacao
    beq  $t4, 17, fim_simulacao
    j    ciclo_principal

sys_print_string:
    subu $t6, $t5, 0x10010000
    la   $t7, mem_data
    addu $a0, $t7, $t6
    li   $v0, 4
    syscall
    j    ciclo_principal

sys_print_char:
    move $a0, $t5
    li   $v0, 11
    syscall
    j    ciclo_principal

# --- Funções de Suporte ---

carregar_ficheiro:
    move $t9, $a1
    li   $v0, 13
    li   $a1, 0
    syscall
    move $a0, $v0
    li   $v0, 14
    move $a1, $t9
    li   $a2, 4096
    syscall
    li   $v0, 16
    syscall
    jr   $ra

ler_rs_rt:
    sll  $t4, $s1, 2
    lw   $v0, reg($t4)
    sll  $t4, $s2, 2
    lw   $v1, reg($t4)
    jr   $ra

escrever_no_rd:
    beqz $s3, ignore
    sll  $t4, $s3, 2
    sw   $t8, reg($t4)
ignore: jr   $ra

escrever_no_rt:
    beqz $s2, ignore
    sll  $t4, $s2, 2
    sw   $t8, reg($t4)
    jr   $ra

instrucao_desconhecida:
    la   $a0, msg_erro
    li   $v0, 4
    syscall
    lw   $a0, PC
    li   $v0, 34
    syscall

fim_simulacao:
    li   $v0, 10
    syscall