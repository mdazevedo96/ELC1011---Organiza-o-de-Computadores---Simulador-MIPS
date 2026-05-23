###############################################################################
# Trabalho: Simulador de Instruções MIPS
# Descrição: Implementação de um simulador MIPS em assembly. 
# Lê as instruções de 'ex-000-073.bin' e os dados de 'ex-000-073.dat'.
###############################################################################

.data
    

    # Nomes dos arquivos de entrada
    arquivo_bin: .asciiz "ex-000-073.bin"
    arquivo_dat: .asciiz "ex-000-073.dat"
    
    # Garante que todas as variáveis e vetores a seguir iniciem em endereços
    # múltiplos de 4 (Word boundary), corrigindo o erro de alinhamento.
    .align 2
   

    # Segmentos de Memória Simulados (4096 bytes cada = 1024 palavras)
    mem_text:   .space 4096   # Base simulada: 0x00400000
    mem_data:   .space 4096   # Base simulada: 0x10010000
    mem_stack:  .space 4096   # Base simulada: 0x7FFFEFFC (cresce para baixo)

    # Banco de Registradores de uso geral (32 registradores de 32 bits)
    reg:        .space 128

    # Registradores Internos
    PC:         .word 0x00400000
    IR:         .word 0
    fim_prog:   .word 0

    # Campos das instruções decodificadas
    f_opcode:   .word 0
    f_rs:       .word 0
    f_rt:       .word 0
    f_rd:       .word 0
    f_shamt:    .word 0
    f_funct:    .word 0
    f_imm:      .word 0
    f_addr:     .word 0
    
    # Mensagens auxiliares
    msg_erro_mem: .asciiz "\n[ERRO] Acesso invalido a memoria!\n"
    msg_erro_op:  .asciiz "\n[ERRO] Instrucao nao suportada!\n"

.text
.globl main

main:
    # -------------------------------------------------------------------------
    # 1. Inicializar Registradores (Ex: reg[29] / $sp = 0x7FFFEFFC)
    # -------------------------------------------------------------------------
    la      $t0, reg
    lui     $t1, 0x7FFF
    ori     $t1, $t1, 0xEFFC
    sw      $t1, 116($t0)       # reg[29] (Stack Pointer virtual) = 0x7FFFEFFC

    # -------------------------------------------------------------------------
    # 2. Ler os arquivos para a memória simulada
    # -------------------------------------------------------------------------
    # Carrega as instruções no segmento de texto simulado
    la      $a0, arquivo_bin
    la      $a1, mem_text
    jal     carregar_arquivo

    # Carrega os dados no segmento de dados simulado
    la      $a0, arquivo_dat
    la      $a1, mem_data
    jal     carregar_arquivo

    # -------------------------------------------------------------------------
    # 3. Ciclo de Busca, Decodificação e Execução (while !fim_programa)
    # -------------------------------------------------------------------------
loop_principal:
    lw      $t0, fim_prog
    bnez    $t0, encerrar_simulador # Se fim_programa != 0, sai do laço

    jal     busca_instrucao         # Busca IR = Mem[PC]
    jal     decodifica_instrucao    # Extrai os campos e faz PC = PC + 4
    jal     executa_instrucao       # Executa a operação ou aciona Syscall

    j       loop_principal

encerrar_simulador:
    li      $v0, 10
    syscall

# =============================================================================
# PROCEDIMENTOS DE SIMULAÇÃO
# =============================================================================

# -----------------------------------------------------------------------------
# carregar_arquivo: Lê até 4096 bytes de $a0 (nome arquivo) para $a1 (buffer)
# -----------------------------------------------------------------------------
carregar_arquivo:
    move    $t8, $a0
    move    $t9, $a1

    # Abrir arquivo (syscall 13)
    move    $a0, $t8
    li      $a1, 0          # Apenas leitura
    li      $a2, 0
    li      $v0, 13
    syscall
    move    $t8, $v0        # Salva o file descriptor

    # Ler do arquivo (syscall 14)
    move    $a0, $t8
    move    $a1, $t9
    li      $a2, 4096
    li      $v0, 14
    syscall

    # Fechar arquivo (syscall 16)
    move    $a0, $t8
    li      $v0, 16
    syscall
    jr      $ra

# -----------------------------------------------------------------------------
# busca_instrucao: Lê a instrução (32 bits) da memória simulada (Text)
# -----------------------------------------------------------------------------
busca_instrucao:
    lw      $a0, PC
    jal     traduz_endereco
    
    # Reconstruindo os bytes (LITTLE-ENDIAN)
    lbu     $t0, 0($v0)
    lbu     $t1, 1($v0)
    lbu     $t2, 2($v0)
    lbu     $t3, 3($v0)
    
    sll     $t1, $t1, 8
    sll     $t2, $t2, 16
    sll     $t3, $t3, 24
    
    or      $t0, $t0, $t1
    or      $t0, $t0, $t2
    or      $t0, $t0, $t3
    sw      $t0, IR
    jr      $ra

# -----------------------------------------------------------------------------
# decodifica_instrucao: Separa os campos da instrução e faz PC += 4
# -----------------------------------------------------------------------------
decodifica_instrucao:
    lw      $t0, IR

    # f_opcode = IR[31:26]
    srl     $t1, $t0, 26
    sw      $t1, f_opcode

    # f_rs = IR[25:21]
    srl     $t1, $t0, 21
    andi    $t1, $t1, 0x1F
    sw      $t1, f_rs

    # f_rt = IR[20:16]
    srl     $t1, $t0, 16
    andi    $t1, $t1, 0x1F
    sw      $t1, f_rt

    # f_rd = IR[15:11]
    srl     $t1, $t0, 11
    andi    $t1, $t1, 0x1F
    sw      $t1, f_rd

    # f_shamt = IR[10:6]
    srl     $t1, $t0, 6
    andi    $t1, $t1, 0x1F
    sw      $t1, f_shamt

    # f_funct = IR[5:0]
    andi    $t1, $t0, 0x3F
    sw      $t1, f_funct

    # f_imm = IR[15:0] com extensão de sinal
    sll     $t1, $t0, 16
    sra     $t1, $t1, 16
    sw      $t1, f_imm

    # f_addr = IR[25:0]
    li      $t2, 0x03FFFFFF
    and     $t1, $t0, $t2
    sw      $t1, f_addr

    # Incrementa o PC simulado (PC += 4)
    lw      $t0, PC
    addiu   $t0, $t0, 4
    sw      $t0, PC
    jr      $ra

# -----------------------------------------------------------------------------
# executa_instrucao: Determina a ação com base no opcode/funct
# -----------------------------------------------------------------------------
executa_instrucao:
    addiu   $sp, $sp, -4
    sw      $ra, 0($sp)
    
    lw      $t0, f_opcode
    beqz    $t0, exec_tipo_R    # Opcode 0 = Tipo R

    # Tipo I e J:
    li      $t1, 2
    beq     $t0, $t1, op_j
    li      $t1, 3
    beq     $t0, $t1, op_jal
    li      $t1, 4
    beq     $t0, $t1, op_beq
    li      $t1, 5
    beq     $t0, $t1, op_bne
    li      $t1, 9
    beq     $t0, $t1, op_addiu
    li      $t1, 13
    beq     $t0, $t1, op_ori
    li      $t1, 15
    beq     $t0, $t1, op_lui
    li      $t1, 35
    beq     $t0, $t1, op_lw
    li      $t1, 36
    beq     $t0, $t1, op_lbu
    li      $t1, 40
    beq     $t0, $t1, op_sb
    li      $t1, 43
    beq     $t0, $t1, op_sw

    # Se chegar aqui, erro (Instrução não implementada)
    j       erro_implementacao

exec_tipo_R:
    lw      $t0, f_funct
    li      $t1, 0
    beq     $t0, $t1, op_sll
    li      $t1, 8
    beq     $t0, $t1, op_jr
    li      $t1, 12
    beq     $t0, $t1, op_syscall
    li      $t1, 33
    beq     $t0, $t1, op_addu
    li      $t1, 35
    beq     $t0, $t1, op_subu
    j       erro_implementacao

# --- Implementação das Instruções ---

op_addiu:
    # reg[rt] = reg[rs] + imm
    lw      $a0, f_rs
    jal     ler_reg
    move    $t0, $v0
    lw      $t1, f_imm
    addu    $a1, $t0, $t1
    lw      $a0, f_rt
    jal     escrever_reg
    j       fim_exec

op_addu:
    # reg[rd] = reg[rs] + reg[rt]
    lw      $a0, f_rs
    jal     ler_reg
    move    $t0, $v0
    lw      $a0, f_rt
    jal     ler_reg
    addu    $a1, $t0, $v0
    lw      $a0, f_rd
    jal     escrever_reg
    j       fim_exec

op_subu:
    # reg[rd] = reg[rs] - reg[rt]
    lw      $a0, f_rs
    jal     ler_reg
    move    $t0, $v0
    lw      $a0, f_rt
    jal     ler_reg
    subu    $a1, $t0, $v0
    lw      $a0, f_rd
    jal     escrever_reg
    j       fim_exec

op_sll:
    # reg[rd] = reg[rt] << shamt
    lw      $a0, f_rt
    jal     ler_reg
    lw      $t0, f_shamt
    sllv    $a1, $v0, $t0
    lw      $a0, f_rd
    jal     escrever_reg
    j       fim_exec

op_lui:
    # reg[rt] = imm << 16
    lw      $t0, f_imm
    sll     $a1, $t0, 16
    lw      $a0, f_rt
    jal     escrever_reg
    j       fim_exec

op_ori:
    # reg[rt] = reg[rs] | (imm zero-extended)
    lw      $a0, f_rs
    jal     ler_reg
    lw      $t0, f_imm
    andi    $t0, $t0, 0xFFFF
    or      $a1, $v0, $t0
    lw      $a0, f_rt
    jal     escrever_reg
    j       fim_exec

op_beq:
    # if (reg[rs] == reg[rt]) PC = PC + (imm << 2)
    lw      $a0, f_rs
    jal     ler_reg
    move    $t0, $v0
    lw      $a0, f_rt
    jal     ler_reg
    bne     $t0, $v0, fim_exec
    lw      $t1, f_imm
    sll     $t1, $t1, 2
    lw      $t2, PC
    addu    $t2, $t2, $t1
    sw      $t2, PC
    j       fim_exec

op_bne:
    # if (reg[rs] != reg[rt]) PC = PC + (imm << 2)
    lw      $a0, f_rs
    jal     ler_reg
    move    $t0, $v0
    lw      $a0, f_rt
    jal     ler_reg
    beq     $t0, $v0, fim_exec
    lw      $t1, f_imm
    sll     $t1, $t1, 2
    lw      $t2, PC
    addu    $t2, $t2, $t1
    sw      $t2, PC
    j       fim_exec

op_j:
    # PC = (PC & 0xF0000000) | (addr << 2)
    lw      $t0, f_addr
    sll     $t0, $t0, 2
    lw      $t1, PC
    lui     $t2, 0xF000
    and     $t1, $t1, $t2
    or      $t1, $t1, $t0
    sw      $t1, PC
    j       fim_exec

op_jal:
    # reg[31] = PC; PC = jump_addr
    lw      $a1, PC
    li      $a0, 31
    jal     escrever_reg
    # Calcular salto
    lw      $t0, f_addr
    sll     $t0, $t0, 2
    lw      $t1, PC
    lui     $t2, 0xF000
    and     $t1, $t1, $t2
    or      $t1, $t1, $t0
    sw      $t1, PC
    j       fim_exec

op_jr:
    # PC = reg[rs]
    lw      $a0, f_rs
    jal     ler_reg
    sw      $v0, PC
    j       fim_exec

op_lw:
    # reg[rt] = Mem[reg[rs] + imm]
    lw      $a0, f_rs
    jal     ler_reg
    lw      $t0, f_imm
    addu    $a0, $v0, $t0
    jal     ler_mem_word
    move    $a1, $v0
    lw      $a0, f_rt
    jal     escrever_reg
    j       fim_exec

op_sw:
    # Mem[reg[rs] + imm] = reg[rt]
    lw      $a0, f_rt
    jal     ler_reg
    move    $t1, $v0        # Valor a ser escrito
    lw      $a0, f_rs
    jal     ler_reg
    lw      $t0, f_imm
    addu    $a0, $v0, $t0   # Endereço
    move    $a1, $t1
    jal     escreve_mem_word
    j       fim_exec

op_lbu:
    # reg[rt] = ZeroExt(Mem[reg[rs] + imm])
    lw      $a0, f_rs
    jal     ler_reg
    lw      $t0, f_imm
    addu    $a0, $v0, $t0
    jal     ler_mem_byte
    move    $a1, $v0
    lw      $a0, f_rt
    jal     escrever_reg
    j       fim_exec

op_sb:
    # Mem[reg[rs] + imm] = reg[rt] (byte inferior)
    lw      $a0, f_rt
    jal     ler_reg
    move    $t1, $v0
    lw      $a0, f_rs
    jal     ler_reg
    lw      $t0, f_imm
    addu    $a0, $v0, $t0
    move    $a1, $t1
    jal     escreve_mem_byte
    j       fim_exec

# --- Syscall Simulation ---
op_syscall:
    # $v0 está mapeado em reg[2]. Lemos $v0 para determinar serviço
    li      $a0, 2
    jal     ler_reg
    move    $t9, $v0        # $t9 = Syscall ID

    # Serviços que encerram (exit = 10, exit2 = 17)
    li      $t0, 10
    beq     $t9, $t0, syscall_exit
    li      $t0, 17
    beq     $t9, $t0, syscall_exit

    # Serviço 4: print_string ($a0 simulado está em reg[4])
    li      $t0, 4
    beq     $t9, $t0, syscall_print_str

    # Serviço 11: print_char ($a0 simulado está em reg[4])
    li      $t0, 11
    beq     $t9, $t0, syscall_print_char

    j       fim_exec

syscall_print_str:
    li      $a0, 4
    jal     ler_reg
    move    $t0, $v0        # $t0 = endereço simulado da string
loop_print_str:
    move    $a0, $t0
    jal     ler_mem_byte
    beqz    $v0, fim_exec   # Se '\0', encerra a impressão
    move    $a0, $v0
    li      $v0, 11
    syscall
    addiu   $t0, $t0, 1
    j       loop_print_str

syscall_print_char:
    li      $a0, 4
    jal     ler_reg
    move    $a0, $v0
    li      $v0, 11
    syscall
    j       fim_exec

syscall_exit:
    li      $t0, 1
    sw      $t0, fim_prog
    j       fim_exec

fim_exec:
    lw      $ra, 0($sp)
    addiu   $sp, $sp, 4
    jr      $ra

erro_implementacao:
    la      $a0, msg_erro_op
    li      $v0, 4
    syscall
    li      $t0, 1
    sw      $t0, fim_prog
    j       fim_exec

# =============================================================================
# MÓDULOS DE MEMÓRIA E REGISTRADORES (Tarefas 2 a 4)
# =============================================================================

# -----------------------------------------------------------------------------
# ler_reg / escrever_reg ($a0 = índice, $a1 = valor)
# -----------------------------------------------------------------------------
ler_reg:
    beqz    $a0, reg_zero
    la      $t0, reg
    sll     $t1, $a0, 2
    addu    $t0, $t0, $t1
    lw      $v0, 0($t0)
    jr      $ra
reg_zero:
    li      $v0, 0
    jr      $ra

escrever_reg:
    beqz    $a0, ignora_escr_zero
    la      $t0, reg
    sll     $t1, $a0, 2
    addu    $t0, $t0, $t1
    sw      $a1, 0($t0)
ignora_escr_zero:
    jr      $ra

# -----------------------------------------------------------------------------
# traduz_endereco: Recebe $a0 (end. simulado) e retorna $v0 (end. host real)
# -----------------------------------------------------------------------------
traduz_endereco:
    # Verifica TEXT [0x00400000 - 0x00401000]
    lui     $t0, 0x0040
    subu    $t1, $a0, $t0
    bltz    $t1, chk_data
    li      $t2, 4096
    bge     $t1, $t2, chk_data
    la      $v0, mem_text
    addu    $v0, $v0, $t1
    jr      $ra

chk_data:
    # Verifica DATA [0x10010000 - 0x10011000]
    lui     $t0, 0x1001
    subu    $t1, $a0, $t0
    bltz    $t1, chk_stack
    li      $t2, 4096
    bge     $t1, $t2, chk_stack
    la      $v0, mem_data
    addu    $v0, $v0, $t1
    jr      $ra

chk_stack:
    # Verifica STACK [0x7FFFEFFC para baixo (4096 bytes)]
    lui     $t0, 0x7FFF
    ori     $t0, $t0, 0xEFFC
    subu    $t1, $t0, $a0       # offset = Base - addr
    bltz    $t1, erro_mem
    li      $t2, 4096
    bge     $t1, $t2, erro_mem
    la      $v0, mem_stack
    addu    $v0, $v0, $t1
    jr      $ra

erro_mem:
    la      $a0, msg_erro_mem
    li      $v0, 4
    syscall
    li      $t0, 1
    sw      $t0, fim_prog
    jr      $ra

# -----------------------------------------------------------------------------
# ler_mem_word / escreve_mem_word ($a0 = end. sim, $a1 = val) Little-Endian
# -----------------------------------------------------------------------------
ler_mem_word:
    addiu   $sp, $sp, -4
    sw      $ra, 0($sp)
    jal     traduz_endereco
    lbu     $t0, 0($v0)
    lbu     $t1, 1($v0)
    lbu     $t2, 2($v0)
    lbu     $t3, 3($v0)
    sll     $t1, $t1, 8
    sll     $t2, $t2, 16
    sll     $t3, $t3, 24
    or      $t0, $t0, $t1
    or      $t0, $t0, $t2
    or      $v0, $t0, $t3
    lw      $ra, 0($sp)
    addiu   $sp, $sp, 4
    jr      $ra

escreve_mem_word:
    addiu   $sp, $sp, -8
    sw      $ra, 4($sp)
    sw      $a1, 0($sp)
    jal     traduz_endereco
    lw      $t0, 0($sp)
    sb      $t0, 0($v0)
    srl     $t1, $t0, 8
    sb      $t1, 1($v0)
    srl     $t1, $t0, 16
    sb      $t1, 2($v0)
    srl     $t1, $t0, 24
    sb      $t1, 3($v0)
    lw      $ra, 4($sp)
    addiu   $sp, $sp, 8
    jr      $ra

# -----------------------------------------------------------------------------
# ler_mem_byte / escreve_mem_byte ($a0 = end. sim, $a1 = byte val)
# -----------------------------------------------------------------------------
ler_mem_byte:
    addiu   $sp, $sp, -4
    sw      $ra, 0($sp)
    jal     traduz_endereco
    lbu     $v0, 0($v0)
    lw      $ra, 0($sp)
    addiu   $sp, $sp, 4
    jr      $ra

escreve_mem_byte:
    addiu   $sp, $sp, -8
    sw      $ra, 4($sp)
    sw      $a1, 0($sp)
    jal     traduz_endereco
    lw      $t0, 0($sp)
    sb      $t0, 0($v0)
    lw      $ra, 4($sp)
    addiu   $sp, $sp, 8
    jr      $ra