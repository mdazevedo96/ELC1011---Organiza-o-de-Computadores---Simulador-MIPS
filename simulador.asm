#*******************************************************************************
# 2026 - 1º Semestre - ELC1011 - Trabalho 1
# Simulador de Instruções MIPS
#*******************************************************************************
#        1         2         3         4         5         6         7         8
#2345678901234567890123456789012345678901234567890123456789012345678901234567890

# Instruções Tipo R (opcode=0):
#   funct  0 = sll      funct  2 = srl      funct  8 = jr
#   funct 12 = syscall  funct 32 = add      funct 33 = addu
#   funct 34 = sub      funct 35 = subu     funct 36 = and
#   funct 37 = or
#
# Instruções Tipo I:
#   opcode  4 = beq     opcode  5 = bne     opcode  8 = addi
#   opcode  9 = addiu   opcode 12 = andi    opcode 13 = ori
#   opcode 15 = lui     opcode 35 = lw      opcode 36 = lbu
#   opcode 40 = sb      opcode 43 = sw
#
# Instruções Tipo J:
#   opcode  2 = j       opcode  3 = jal
#
# Serviços syscall simulados:
#    4 = print_string  ($a0 = endereço da string em mem_data)
#   10 = exit          (encerra a simulação)
#   11 = print_char    ($a0 = código ASCII do caractere)
#   17 = exit2         ($a0 = código de retorno)

        .data

#-------------------------------------------------------------------------------
# Tarefa 1(a): Segmentos de memória simulados (4096 bytes = 1024 palavras cada)
#-------------------------------------------------------------------------------
        .align 2
mem_text:       .space 4096         # Segmento de texto  – base simulada: 0x00400000
mem_data:       .space 4096         # Segmento de dados  – base simulada: 0x10010000
mem_stack:      .space 4096         # Segmento de pilha  – base simulada: 0x7FFFF000

#-------------------------------------------------------------------------------
# Tarefa 1(b): Banco de registradores de uso geral (32 × 4 bytes = 128 bytes)
#-------------------------------------------------------------------------------
reg_bank:       .space 128

#-------------------------------------------------------------------------------
# Tarefa 1(c): Registradores de uso interno (PC e IR)
#-------------------------------------------------------------------------------
var_PC:         .word  0x00400000   # Program Counter – endereço inicial do programa
var_IR:         .word  0            # Instruction Register – instrução em execução

#-------------------------------------------------------------------------------
# Tarefa 1(d): Campos de decodificação das instruções (Formatos R, I, J)
#-------------------------------------------------------------------------------
field_op:       .word  0            # Opcode        (bits 31–26)
field_rs:       .word  0            # Registrador RS (bits 25–21)
field_rt:       .word  0            # Registrador RT (bits 20–16)
field_rd:       .word  0            # Registrador RD (bits 15–11)
field_shamt:    .word  0            # Shift Amount   (bits 10– 6)
field_funct:    .word  0            # Function Code  (bits  5– 0)
field_imm_ze:   .word  0            # Imediato zero-extended  (andi, ori)
field_imm_se:   .word  0            # Imediato sign-extended  (addi, lw, sw, beq, bne)
field_target:   .word  0            # Endereço J-type         (bits 25– 0)

# Variável de estado do interpretador (1 = executando, 0 = encerrado)
sim_running:    .word  1

#-------------------------------------------------------------------------------
# Arquivos de entrada
#-------------------------------------------------------------------------------
nome_file_bin: .asciiz "ex-000-073.bin"
nome_file_dat: .asciiz "ex-000-073.dat"

# Mensagens do simulador
msg_banner:     .asciiz "==================================================\n  SIMULADOR MIPS EDUCACIONAL - INICIADO\n==================================================\n"
msg_exit_clean: .asciiz "\n>> Simulação concluída com sucesso (Syscall Exit).\n"
msg_err_opcode: .asciiz "\n[EXCEÇÃO] Instrução não implementada no PC: 0x"
msg_err_addr:   .asciiz "\n[EXCEÇÃO] Endereço de memória inválido simulado.\n"
msg_err_file:   .asciiz "\n[ERRO CRÍTICO] Falha ao abrir o arquivo binário.\n"

        .text
        .globl  main

################################################################################
# Procedimento: main
################################################################################
main:
            li      $v0, 4
            la      $a0, msg_banner
            syscall

#   inicializa $sp simulado (reg_bank[29] = 0x7FFFFFC0)
            li      $t0, 0x7FFFFFC0
            sw      $t0, reg_bank+116   # 29 * 4 = 116

#   Tarefa 5: carrega os arquivos binários nos segmentos de memória
            jal     carregar_arquivos

#   Tarefa 6: ciclo principal de execução
main_loop:
            lw      $t0, sim_running
            beqz    $t0, finalizar_simulador    # sim_running == 0: encerra

#       -----------------------------------------------------------------------
#       Passo (a): BUSCA – lê a instrução apontada por var_PC e salva em var_IR
#       -----------------------------------------------------------------------
            lw      $a0, var_PC         # $a0 <- endereço simulado da instrução
            jal     ler_memoria         # $v0 <- instrução de 32 bits (little-endian)
            sw      $v0, var_IR         # var_IR <- instrução buscada

#       -----------------------------------------------------------------------
#       Passo (b): DECODIFICAÇÃO – separa os campos de var_IR e incrementa PC
#       -----------------------------------------------------------------------
            lw      $t0, var_IR         # $t0 <- instrução corrente

#         opcode = IR[31:26]
            srl     $t1, $t0, 26
            sw      $t1, field_op

#         rs = IR[25:21]
            srl     $t1, $t0, 21
            andi    $t1, $t1, 0x1F
            sw      $t1, field_rs

#         rt = IR[20:16]
            srl     $t1, $t0, 16
            andi    $t1, $t1, 0x1F
            sw      $t1, field_rt

#         rd = IR[15:11]
            srl     $t1, $t0, 11
            andi    $t1, $t1, 0x1F
            sw      $t1, field_rd

#         shamt = IR[10:6]
            srl     $t1, $t0, 6
            andi    $t1, $t1, 0x1F
            sw      $t1, field_shamt

#         funct = IR[5:0]
            andi    $t1, $t0, 0x3F
            sw      $t1, field_funct

#         immediate zero-extended = IR[15:0]  (para andi, ori)
            andi    $t1, $t0, 0xFFFF
            sw      $t1, field_imm_ze

#         immediate sign-extended = sign_ext(IR[15:0])  (para addi, lw, sw, beq, bne)
            sll     $t1, $t0, 16
            sra     $t1, $t1, 16
            sw      $t1, field_imm_se

#         target = IR[25:0]  (para j, jal)
            andi    $t1, $t0, 0x03FFFFFF
            sw      $t1, field_target

#         var_PC = var_PC + 4
            lw      $t2, var_PC
            addiu   $t2, $t2, 4
            sw      $t2, var_PC

#       -----------------------------------------------------------------------
#       Passo (c): EXECUÇÃO – despacha pelo opcode
#       -----------------------------------------------------------------------
            lw      $t0, field_op

            beq     $t0, $zero, rotear_tipo_r   # opcode  0: Tipo R

            li      $t1, 2
            beq     $t0, $t1, exec_j            # opcode  2: j
            li      $t1, 3
            beq     $t0, $t1, exec_jal          # opcode  3: jal
            li      $t1, 4
            beq     $t0, $t1, exec_beq          # opcode  4: beq
            li      $t1, 5
            beq     $t0, $t1, exec_bne          # opcode  5: bne
            li      $t1, 8
            beq     $t0, $t1, exec_addi         # opcode  8: addi
            li      $t1, 9
            beq     $t0, $t1, exec_addi         # opcode  9: addiu  (mesmo handler)
            li      $t1, 12
            beq     $t0, $t1, exec_andi         # opcode 12: andi
            li      $t1, 13
            beq     $t0, $t1, exec_ori          # opcode 13: ori
            li      $t1, 15
            beq     $t0, $t1, exec_lui          # opcode 15: lui
            li      $t1, 35
            beq     $t0, $t1, exec_lw           # opcode 35: lw
            li      $t1, 36
            beq     $t0, $t1, exec_lbu          # opcode 36: lbu
            li      $t1, 40
            beq     $t0, $t1, exec_sb           # opcode 40: sb
            li      $t1, 43
            beq     $t0, $t1, exec_sw           # opcode 43: sw

            j       rotina_nao_implementada     # opcode não reconhecido

#-------------------------------------------------------------------------------
# Roteamento de instruções Tipo R (opcode == 0) – despacho pelo funct
#-------------------------------------------------------------------------------
rotear_tipo_r:
            lw      $t0, field_funct

            li      $t1, 0
            beq     $t0, $t1, exec_sll          # funct  0: sll
            li      $t1, 2
            beq     $t0, $t1, exec_srl          # funct  2: srl
            li      $t1, 8
            beq     $t0, $t1, exec_jr           # funct  8: jr
            li      $t1, 12
            beq     $t0, $t1, exec_syscall      # funct 12: syscall
            li      $t1, 32
            beq     $t0, $t1, exec_add          # funct 32: add
            li      $t1, 33
            beq     $t0, $t1, exec_add          # funct 33: addu  (mesmo handler)
            li      $t1, 34
            beq     $t0, $t1, exec_sub          # funct 34: sub
            li      $t1, 35
            beq     $t0, $t1, exec_sub          # funct 35: subu  (mesmo handler)
            li      $t1, 36
            beq     $t0, $t1, exec_and          # funct 36: and
            li      $t1, 37
            beq     $t0, $t1, exec_or           # funct 37: or

            j       rotina_nao_implementada     # funct não reconhecido

#===============================================================================
# BLOCOS DE EXECUÇÃO INDIVIDUAL
#===============================================================================

exec_sll:
            lw      $t0, field_rt
            sll     $t0, $t0, 2             # $t0 <- offset em bytes = rt * 4
            lw      $s1, reg_bank($t0)      # $s1 <- reg_bank[rt]
            lw      $t1, field_shamt        # $t1 <- shamt
            sllv    $s2, $s1, $t1           # $s2 <- reg_bank[rt] << shamt
            jal     escrever_contexto_rd    # reg_bank[rd] <- $s2
            j       main_loop

exec_srl:
            lw      $t0, field_rt
            sll     $t0, $t0, 2
            lw      $s1, reg_bank($t0)      # $s1 <- reg_bank[rt]
            lw      $t1, field_shamt
            srlv    $s2, $s1, $t1           # $s2 <- reg_bank[rt] >> shamt (lógico)
            jal     escrever_contexto_rd
            j       main_loop

exec_jr:
            lw      $t0, field_rs
            sll     $t0, $t0, 2
            lw      $t1, reg_bank($t0)      # $t1 <- reg_bank[rs]
            sw      $t1, var_PC             # var_PC <- reg_bank[rs]
            j       main_loop

exec_syscall:
            lw      $t0, reg_bank+8         # $t0 <- reg_bank[2] = código do serviço

            li      $t1, 4
            beq     $t0, $t1, svc_print_str     # serviço  4: print_string
            li      $t1, 10
            beq     $t0, $t1, svc_exit          # serviço 10: exit
            li      $t1, 11
            beq     $t0, $t1, svc_print_char    # serviço 11: print_char
            li      $t1, 17
            beq     $t0, $t1, svc_exit          # serviço 17: exit2
            j       rotina_nao_implementada

svc_print_str:
            addiu   $sp, $sp, -4
            sw      $ra, 0($sp)
            lw      $a0, reg_bank+16        # $a0 <- reg_bank[4] = endereço simulado
svc_str_laco:
            jal     ler_byte_memoria        # $v0 <- byte em mem[reg_bank[4]]
            beqz    $v0, svc_str_fim        # '\0': fim da string
            move    $a0, $v0
            li      $v0, 11                 # syscall 11: print_char
            syscall
            lw      $t0, reg_bank+16
            addiu   $t0, $t0, 1
            sw      $t0, reg_bank+16        # reg_bank[4] <- endereço atualizado
            move    $a0, $t0               
            j       svc_str_laco
svc_str_fim:
            lw      $ra, 0($sp)
            addiu   $sp, $sp, 4
            j       main_loop

svc_print_char:
            lw      $a0, reg_bank+16        # $a0 <- reg_bank[4] = código ASCII
            li      $v0, 11                 # syscall 11: print_char
            syscall
            j       main_loop

svc_exit:
            sw      $zero, sim_running
            j       main_loop

exec_add:
            jal     carregar_contexto_rs_rt # $s0 <- reg_bank[rs]; $s1 <- reg_bank[rt]
            add     $s2, $s0, $s1
            jal     escrever_contexto_rd    # reg_bank[rd] <- $s2
            j       main_loop

exec_sub:
            jal     carregar_contexto_rs_rt
            sub     $s2, $s0, $s1
            jal     escrever_contexto_rd
            j       main_loop

exec_and:
            jal     carregar_contexto_rs_rt
            and     $s2, $s0, $s1
            jal     escrever_contexto_rd
            j       main_loop

exec_or:
            jal     carregar_contexto_rs_rt
            or      $s2, $s0, $s1
            jal     escrever_contexto_rd
            j       main_loop

exec_addi:
            lw      $t0, field_rs
            sll     $t0, $t0, 2
            lw      $s0, reg_bank($t0)      # $s0 <- reg_bank[rs]
            lw      $s1, field_imm_se       # $s1 <- imediato sign-extended
            add     $s2, $s0, $s1           # $s2 <- reg_bank[rs] + imm
            jal     escrever_contexto_rt    # reg_bank[rt] <- $s2
            j       main_loop

exec_andi:
            lw      $t0, field_rs
            sll     $t0, $t0, 2
            lw      $s0, reg_bank($t0)      # $s0 <- reg_bank[rs]
            lw      $s1, field_imm_ze       # $s1 <- imediato zero-extended
            and     $s2, $s0, $s1
            jal     escrever_contexto_rt
            j       main_loop

exec_ori:
            lw      $t0, field_rs
            sll     $t0, $t0, 2
            lw      $s0, reg_bank($t0)
            lw      $s1, field_imm_ze
            or      $s2, $s0, $s1
            jal     escrever_contexto_rt
            j       main_loop

exec_lui:
            lw      $s1, field_imm_ze       # $s1 <- imediato (16 bits)
            sll     $s2, $s1, 16            # $s2 <- imm deslocado para [31:16]
            jal     escrever_contexto_rt    # reg_bank[rt] <- $s2
            j       main_loop

exec_lw:
            addiu   $sp, $sp, -4
            sw      $ra, 0($sp)
            lw      $t0, field_rs
            sll     $t0, $t0, 2
            lw      $s0, reg_bank($t0)      # $s0 <- reg_bank[rs]
            lw      $s1, field_imm_se       # $s1 <- imediato sign-extended
            add     $a0, $s0, $s1           # $a0 <- endereço simulado
            jal     ler_memoria             # $v0 <- palavra lida
            move    $s2, $v0                # $s2 <- palavra lida
            jal     escrever_contexto_rt    # reg_bank[rt] <- palavra lida
            lw      $ra, 0($sp)
            addiu   $sp, $sp, 4
            j       main_loop

exec_lbu:
            addiu   $sp, $sp, -4
            sw      $ra, 0($sp)
            lw      $t0, field_rs
            sll     $t0, $t0, 2
            lw      $s0, reg_bank($t0)
            lw      $s1, field_imm_se
            add     $a0, $s0, $s1           # $a0 <- endereço simulado
            jal     ler_byte_memoria        # $v0 <- byte (zero-extended)
            move    $s2, $v0
            jal     escrever_contexto_rt    # reg_bank[rt] <- byte
            lw      $ra, 0($sp)
            addiu   $sp, $sp, 4
            j       main_loop

exec_sw:
            addiu   $sp, $sp, -4
            sw      $ra, 0($sp)
            lw      $t0, field_rs
            sll     $t0, $t0, 2
            lw      $s0, reg_bank($t0)      # $s0 <- reg_bank[rs]
            lw      $s1, field_imm_se
            add     $a0, $s0, $s1           # $a0 <- endereço simulado
            lw      $t1, field_rt
            sll     $t1, $t1, 2
            lw      $a1, reg_bank($t1)      # $a1 <- reg_bank[rt] = valor a escrever
            jal     escrever_memoria        # escreve na memória simulada
            lw      $ra, 0($sp)
            addiu   $sp, $sp, 4
            j       main_loop

exec_sb:
            addiu   $sp, $sp, -4
            sw      $ra, 0($sp)
            lw      $t0, field_rs
            sll     $t0, $t0, 2
            lw      $s0, reg_bank($t0)
            lw      $s1, field_imm_se
            add     $a0, $s0, $s1           # $a0 <- endereço simulado
            lw      $t1, field_rt
            sll     $t1, $t1, 2
            lw      $a1, reg_bank($t1)      # $a1 <- reg_bank[rt]
            jal     escrever_byte_memoria   # escreve byte (bits [7:0])
            lw      $ra, 0($sp)
            addiu   $sp, $sp, 4
            j       main_loop

exec_beq:
            jal     carregar_contexto_rs_rt # $s0 <- reg_bank[rs]; $s1 <- reg_bank[rt]
            bne     $s0, $s1, main_loop     # rs != rt: sem desvio
            lw      $t0, field_imm_se
            sll     $t0, $t0, 2             # offset em bytes = imm * 4
            lw      $t1, var_PC
            add     $t1, $t1, $t0
            sw      $t1, var_PC             # var_PC <- var_PC + offset
            j       main_loop

exec_bne:
            jal     carregar_contexto_rs_rt
            beq     $s0, $s1, main_loop     # rs == rt: sem desvio
            lw      $t0, field_imm_se
            sll     $t0, $t0, 2
            lw      $t1, var_PC
            add     $t1, $t1, $t0
            sw      $t1, var_PC
            j       main_loop

exec_j:
            lw      $t0, field_target
            sll     $t0, $t0, 2             # $t0 <- endereço destino
            sw      $t0, var_PC
            j       main_loop

exec_jal:
            lw      $t0, var_PC             # $t0 <- endereço de retorno
            sw      $t0, reg_bank+124       # reg_bank[31] = 31 * 4 = 124
            lw      $t0, field_target
            sll     $t0, $t0, 2
            sw      $t0, var_PC
            j       main_loop

#-------------------------------------------------------------------------------
# rotina_nao_implementada: exibe o PC e encerra a simulação
#-------------------------------------------------------------------------------
rotina_nao_implementada:
            li      $v0, 4
            la      $a0, msg_err_opcode
            syscall
            lw      $a0, var_PC
            addiu   $a0, $a0, -4            # PC da instrução que falhou
            li      $v0, 34                 # syscall 34: print_hex
            syscall
            sw      $zero, sim_running      # sim_running <- 0
            j       main_loop

#-------------------------------------------------------------------------------
# finalizar_simulador: imprime mensagem de encerramento e sai
#-------------------------------------------------------------------------------
finalizar_simulador:
            li      $v0, 4
            la      $a0, msg_exit_clean
            syscall
            li      $v0, 10
            syscall

#===============================================================================
# Módulo de gerenciamento de memória virtual e sub-rotinas do sistema
#===============================================================================

################################################################################
# carregar_arquivos: Abre, lê e fecha os arquivos .bin e .dat
################################################################################
carregar_arquivos:
            addiu   $sp, $sp, -4
            sw      $ra, 0($sp)

            # Abrir arquivo de texto (.bin)
            li      $v0, 13
            la      $a0, nome_file_bin
            li      $a1, 0                  # Apenas leitura
            li      $a2, 0
            syscall
            bltz    $v0, erro_arquivo       # Se fd < 0, erro
            move    $t0, $v0                # $t0 = File Descriptor

            # Ler arquivo de texto para mem_text
            li      $v0, 14
            move    $a0, $t0
            la      $a1, mem_text
            li      $a2, 4096               # Max bytes
            syscall

            # Fechar arquivo de texto
            li      $v0, 16
            move    $a0, $t0
            syscall

            # Abrir arquivo de dados (.dat)
            li      $v0, 13
            la      $a0, nome_file_dat
            li      $a1, 0
            li      $a2, 0
            syscall
            bltz    $v0, fim_carregar_arquivos # Permite executar se não houver arquivo .dat
            move    $t0, $v0

            # Ler arquivo de dados para mem_data
            li      $v0, 14
            move    $a0, $t0
            la      $a1, mem_data
            li      $a2, 4096
            syscall

            # Fechar arquivo de dados
            li      $v0, 16
            move    $a0, $t0
            syscall

fim_carregar_arquivos:
            lw      $ra, 0($sp)
            addiu   $sp, $sp, 4
            jr      $ra

erro_arquivo:
            li      $v0, 4
            la      $a0, msg_err_file
            syscall
            li      $v0, 10
            syscall

################################################################################
# Sub-rotinas de manipulação do Banco de Registradores
################################################################################
carregar_contexto_rs_rt:
            lw      $t0, field_rs
            sll     $t0, $t0, 2
            lw      $s0, reg_bank($t0)      # $s0 = reg_bank[rs]
            lw      $t0, field_rt
            sll     $t0, $t0, 2
            lw      $s1, reg_bank($t0)      # $s1 = reg_bank[rt]
            jr      $ra

escrever_contexto_rd:
            lw      $t0, field_rd
            beqz    $t0, protege_zero_rd    # Se rd == 0, ignora escrita
            sll     $t0, $t0, 2
            sw      $s2, reg_bank($t0)      # reg_bank[rd] = $s2
protege_zero_rd:
            jr      $ra

escrever_contexto_rt:
            lw      $t0, field_rt
            beqz    $t0, protege_zero_rt    # Se rt == 0, ignora escrita
            sll     $t0, $t0, 2
            sw      $s2, reg_bank($t0)      # reg_bank[rt] = $s2
protege_zero_rt:
            jr      $ra

################################################################################
# Procedimentos de leitura/escrita de memória simulada
################################################################################
ler_memoria:
            li      $t0, 0x00400000
            blt     $a0, $t0, lm_checar_dados
            li      $t0, 0x00401000
            bge     $a0, $t0, lm_checar_dados
            li      $t0, 0x00400000
            sub     $t1, $a0, $t0           # $t1 <- offset = addr - TEXT_BASE
            la      $t0, mem_text
            add     $t1, $t0, $t1           # $t1 <- ponteiro real
            j       lm_ler_palavra

lm_checar_dados:
            li      $t0, 0x10010000
            blt     $a0, $t0, lm_checar_pilha
            li      $t0, 0x10011000
            bge     $a0, $t0, lm_checar_pilha
            li      $t0, 0x10010000
            sub     $t1, $a0, $t0
            la      $t0, mem_data
            add     $t1, $t0, $t1           # $t1 <- ponteiro real
            j       lm_ler_palavra

lm_checar_pilha:
            li      $t0, 0x7FFFF000
            blt     $a0, $t0, excecao_endereco_invalido
            sub     $t1, $a0, $t0
            la      $t0, mem_stack
            add     $t1, $t0, $t1           # $t1 <- ponteiro real

lm_ler_palavra:
            lbu     $t0, 0($t1)             # $t0 <- byte 0 (bits  [7: 0])
            lbu     $t2, 1($t1)             # $t2 <- byte 1 (bits [15: 8])
            sll     $t2, $t2, 8
            or      $t0, $t0, $t2
            lbu     $t2, 2($t1)             # $t2 <- byte 2 (bits [23:16])
            sll     $t2, $t2, 16
            or      $t0, $t0, $t2
            lbu     $t2, 3($t1)             # $t2 <- byte 3 (bits [31:24])
            sll     $t2, $t2, 24
            or      $v0, $t0, $t2           # $v0 <- palavra reconstituída
            jr      $ra


ler_byte_memoria:
            li      $t0, 0x00400000
            blt     $a0, $t0, lbm_checar_dados
            li      $t0, 0x00401000
            bge     $a0, $t0, lbm_checar_dados
            li      $t0, 0x00400000
            sub     $t1, $a0, $t0
            la      $t0, mem_text
            add     $t1, $t0, $t1
            lbu     $v0, 0($t1)             # $v0 <- byte (zero-extended)
            jr      $ra

lbm_checar_dados:
            li      $t0, 0x10010000
            blt     $a0, $t0, lbm_checar_pilha
            li      $t0, 0x10011000
            bge     $a0, $t0, lbm_checar_pilha
            li      $t0, 0x10010000
            sub     $t1, $a0, $t0
            la      $t0, mem_data
            add     $t1, $t0, $t1
            lbu     $v0, 0($t1)
            jr      $ra

lbm_checar_pilha:
            li      $t0, 0x7FFFF000
            blt     $a0, $t0, excecao_endereco_invalido
            sub     $t1, $a0, $t0
            la      $t0, mem_stack
            add     $t1, $t0, $t1
            lbu     $v0, 0($t1)
            jr      $ra


escrever_memoria:
            li      $t0, 0x10010000
            blt     $a0, $t0, em_checar_pilha
            li      $t0, 0x10011000
            bge     $a0, $t0, em_checar_pilha
            li      $t0, 0x10010000
            sub     $t1, $a0, $t0
            la      $t0, mem_data
            add     $t1, $t0, $t1           # $t1 <- ponteiro real
            j       em_escrever_palavra

em_checar_pilha:
            li      $t0, 0x7FFFF000
            blt     $a0, $t0, excecao_endereco_invalido
            sub     $t1, $a0, $t0
            la      $t0, mem_stack
            add     $t1, $t0, $t1

em_escrever_palavra:
            sb      $a1, 0($t1)             # byte 0: bits  [7: 0]
            srl     $t0, $a1, 8
            sb      $t0, 1($t1)             # byte 1: bits [15: 8]
            srl     $t0, $a1, 16
            sb      $t0, 2($t1)             # byte 2: bits [23:16]
            srl     $t0, $a1, 24
            sb      $t0, 3($t1)             # byte 3: bits [31:24]
            jr      $ra


escrever_byte_memoria:
            li      $t0, 0x10010000
            blt     $a0, $t0, ebm_checar_pilha
            li      $t0, 0x10011000
            bge     $a0, $t0, ebm_checar_pilha
            li      $t0, 0x10010000
            sub     $t1, $a0, $t0
            la      $t0, mem_data
            add     $t1, $t0, $t1
            sb      $a1, 0($t1)
            jr      $ra

ebm_checar_pilha:
            li      $t0, 0x7FFFF000
            blt     $a0, $t0, excecao_endereco_invalido
            sub     $t1, $a0, $t0
            la      $t0, mem_stack
            add     $t1, $t0, $t1
            sb      $a1, 0($t1)
            jr      $ra


excecao_endereco_invalido:
            li      $v0, 4
            la      $a0, msg_err_addr
            syscall
            sw      $zero, sim_running      # Força a parada do simulador
            jr      $ra
