#*******************************************************************************
# 2026 - 1º Semestre - ELC1011 - Trabalho 1
# Simulador de Instruções MIPS
# Autores: [Nome(s) do(s) aluno(s)] - UFSM - CT - DELC
#*******************************************************************************
#        1         2         3         4         5         6         7         8
#2345678901234567890123456789012345678901234567890123456789012345678901234567890
#           M       O             #

        .data

# vetores representando os segmentos de memória simulados (Tarefa 1a)
# cada segmento tem 4096 bytes = 1024 palavras de 32 bits
mem_text:       .space  4096    # segmento de texto  – endereço base: 0x00400000
mem_data:       .space  4096    # segmento de dados  – endereço base: 0x10010000
mem_stack:      .space  4096    # segmento de pilha  – endereço base: 0x7FFFF000

# vetor representando o banco de registradores de uso geral (Tarefa 1b)
# 32 registradores de 32 bits = 128 bytes
reg:            .space  128

# variáveis PC e IR (Tarefa 1c)
PC:             .word   0x00400000      # Program Counter – endereço inicial: 0x00400000
IR:             .word   0               # Instruction Register

# variáveis dos campos das instruções (Tarefa 1d)
f_opcode:       .word   0               # opcode   – bits [31:26]
f_rs:           .word   0               # rs       – bits [25:21]
f_rt:           .word   0               # rt       – bits [20:16]
f_rd:           .word   0               # rd       – bits [15:11]
f_shamt:        .word   0               # shamt    – bits [10: 6]
f_funct:        .word   0               # funct    – bits [ 5: 0]
f_imm:          .word   0               # imediato sign-extended (16 → 32 bits)
f_addr:         .word   0               # endereço J-type – bits [25: 0]

# variável de controle do laço principal
sim_rodando:    .word   1               # 1 = executando, 0 = encerrado

# nomes dos arquivos de entrada
# ATENÇÃO: os arquivos devem estar no diretório de trabalho do MARS
# (Settings > Set Working Directory)
arq_bin:        .asciiz "trabalho_01-2026_1.bin"
arq_dat:        .asciiz "trabalho_01-2026_1.dat"

# mensagens do simulador
msg_inicio:     .asciiz "Simulador MIPS iniciado.\n"
msg_bin:        .asciiz "Carregando trabalho_01-2026_1.bin ...\n"
msg_dat:        .asciiz "Carregando trabalho_01-2026_1.dat ...\n"
msg_ok:         .asciiz "OK\n"
msg_fim:        .asciiz "\nSimulacao encerrada.\n"
msg_erro_arq:   .asciiz "\nErro: falha ao abrir arquivo.\nVerifique o diretorio de trabalho (Settings > Set Working Directory).\n"

# strings para o trace de execução (exibe PC e IR a cada instrução)
msg_trace_pc:   .asciiz "PC=0x"
msg_trace_ir:   .asciiz "  IR=0x"
msg_nl:         .asciiz "\n"

        .text
        .globl  main

################################################################################
# Procedimento: main
#
# Mapa de registradores
#       $t0     sim_rodando; valor temporário
################################################################################
main:
# {
#   imprime mensagem de início
            li      $v0, 4
            la      $a0, msg_inicio
            syscall

#   inicializa reg[29] ($sp simulado) = 0x7FFFEFFC  (29 * 4 = 116)
            lui     $t0, 0x7fff
            ori     $t0, $t0, 0xeffc    # $t0 <- 0x7FFFEFFC
            la      $t9, reg
            sw      $t0, 116($t9)  # reg[29] <- 0x7FFFEFFC

#   lê o arquivo com as instruções e carrega no segmento de texto  (Tarefa 5a)
            jal     ler_arquivo_bin

#   lê o arquivo com os dados e carrega no segmento de dados  (Tarefa 5b)
            jal     ler_arquivo_dat

#   while (!fim_programa) {
main_laco:
            lw      $t0, sim_rodando
            beq     $t0, $zero, main_fim    # se sim_rodando == 0: encerra

#       (a) busca a instrução apontada por PC e armazena no registrador IR
            lw      $a0, PC             # $a0 <- PC (endereço simulado da instrução)
            jal     verificar_endereco  # $v0 <- ponteiro real em mem_text
            lbu     $t0, 0($v0)         # reconstrói a palavra em little-endian:
            lbu     $t1, 1($v0)         #   byte 0 = bits  [7: 0]
            lbu     $t2, 2($v0)         #   byte 1 = bits [15: 8]
            lbu     $t3, 3($v0)         #   byte 2 = bits [23:16]
            sll     $t1, $t1, 8         #   byte 3 = bits [31:24]
            sll     $t2, $t2, 16
            sll     $t3, $t3, 24
            or      $t0, $t0, $t1
            or      $t0, $t0, $t2
            or      $t0, $t0, $t3
            sw      $t0, IR             # IR <- instrução buscada

#       imprime trace: "PC=0x<PC>  IR=0x<IR>"
            addiu   $sp, $sp, -4
            sw      $ra, 0($sp)
            li      $v0, 4
            la      $a0, msg_trace_pc   # imprime "PC=0x"
            syscall
            lw      $a0, PC             # $a0 <- PC (endereço da instrução corrente)
            li      $v0, 34             # syscall 34: print_hex
            syscall
            li      $v0, 4
            la      $a0, msg_trace_ir   # imprime "  IR=0x"
            syscall
            lw      $a0, IR             # $a0 <- IR (instrução em execução)
            li      $v0, 34
            syscall
            li      $v0, 4
            la      $a0, msg_nl         # imprime nova linha
            syscall
            lw      $ra, 0($sp)
            addiu   $sp, $sp, 4

#       (b) separa os campos da instrução em IR, incrementa PC (soma 4)
#           e decodifica a instrução
            lw      $t0, IR             # $t0 <- instrução

#         opcode = IR[31:26]
            srl     $t1, $t0, 26
            sw      $t1, f_opcode

#         rs = IR[25:21]
            srl     $t1, $t0, 21
            andi    $t1, $t1, 0x1F
            sw      $t1, f_rs

#         rt = IR[20:16]
            srl     $t1, $t0, 16
            andi    $t1, $t1, 0x1F
            sw      $t1, f_rt

#         rd = IR[15:11]
            srl     $t1, $t0, 11
            andi    $t1, $t1, 0x1F
            sw      $t1, f_rd

#         shamt = IR[10:6]
            srl     $t1, $t0, 6
            andi    $t1, $t1, 0x1F
            sw      $t1, f_shamt

#         funct = IR[5:0]
            andi    $t1, $t0, 0x3F
            sw      $t1, f_funct

#         imediato com extensão de sinal: sll 16 coloca bit 15 em bit 31;
#         sra 16 propaga o sinal para os bits [31:16]
            sll     $t1, $t0, 16
            sra     $t1, $t1, 16
            sw      $t1, f_imm

#         endereço J-type = IR[25:0]
            andi    $t1, $t0, 0x03FFFFFF
            sw      $t1, f_addr

#         PC = PC + 4
            lw      $t1, PC
            addiu   $t1, $t1, 4
            sw      $t1, PC

#       (c) executa a instrução usando os campos OPCODE e FUNCT
#           se a instrução é tipo R
            lw      $t0, f_opcode       # $t0 <- opcode

            beq     $t0, $zero, despacho_tipo_r     # opcode = 0: Tipo R

            li      $t1, 2
            beq     $t0, $t1, exec_j                # opcode  2: j
            li      $t1, 3
            beq     $t0, $t1, exec_jal              # opcode  3: jal
            li      $t1, 4
            beq     $t0, $t1, exec_beq              # opcode  4: beq
            li      $t1, 5
            beq     $t0, $t1, exec_bne              # opcode  5: bne
            li      $t1, 9
            beq     $t0, $t1, exec_addiu            # opcode  9: addiu
            li      $t1, 13
            beq     $t0, $t1, exec_ori              # opcode 13: ori
            li      $t1, 15
            beq     $t0, $t1, exec_lui              # opcode 15: lui
            li      $t1, 35
            beq     $t0, $t1, exec_lw               # opcode 35: lw
            li      $t1, 36
            beq     $t0, $t1, exec_lbu              # opcode 36: lbu
            li      $t1, 40
            beq     $t0, $t1, exec_sb               # opcode 40: sb
            li      $t1, 43
            beq     $t0, $t1, exec_sw               # opcode 43: sw

            j       main_laco           # opcode não reconhecido: ignora e continua

#   }

despacho_tipo_r:
#   despacho pelo campo funct para instruções Tipo R
            lw      $t0, f_funct        # $t0 <- funct

            li      $t1, 8
            beq     $t0, $t1, exec_jr               # funct  8: jr
            li      $t1, 12
            beq     $t0, $t1, exec_syscall          # funct 12: syscall
            li      $t1, 33
            beq     $t0, $t1, exec_addu             # funct 33: addu
            li      $t1, 35
            beq     $t0, $t1, exec_subu             # funct 35: subu

            j       main_laco           # funct não reconhecido: ignora e continua

main_fim:
#   imprime mensagem de encerramento e termina
            li      $v0, 4
            la      $a0, msg_fim
            syscall
            li      $v0, 10
            syscall
# }

#===============================================================================
# Procedimentos de execução das instruções
#===============================================================================

#-------------------------------------------------------------------------------
# jr rs   :   PC = reg[rs]
#
# Mapa de registradores
#       $t0     índice de rs em bytes; reg[rs]
#-------------------------------------------------------------------------------
exec_jr:
# {
#   PC = reg[rs]
            lw      $t0, f_rs           # $t0 <- índice de rs
            sll     $t0, $t0, 2         # $t0 <- offset = rs * 4
            la      $t9, reg
            add     $t9, $t9, $t0
            lw      $t0, 0($t9)  # $t0 <- reg[rs]
            sw      $t0, PC             # PC  <- reg[rs]
            j       main_laco
# }

#-------------------------------------------------------------------------------
# syscall   :   executa o serviço indicado por reg[2] ($v0 simulado)
#
# Serviços implementados:
#    4 = print_string  ($a0 simulado = endereço da string)
#   10 = exit          (encerra a simulação)
#   11 = print_char    ($a0 simulado = código ASCII)
#   17 = exit2         (encerra a simulação)
#
# Mapa de registradores
#       $t0     código do serviço (reg[2]); byte lido; endereço simulado
#       $t1     ponteiro real do byte corrente
#       $t2     byte lido
#-------------------------------------------------------------------------------
exec_syscall:
# {
            la      $t9, reg
            lw      $t0, 8($t9)  # $t0 <- reg[2] = código do serviço

#   if (serviço == 4) print_string
            li      $t1, 4
            bne     $t0, $t1, exec_syscall_11
#           imprime a string byte a byte a partir do endereço em reg[4]
#           $s0 é usado como ponteiro pois sobrevive a jal e a syscall
#           while (*ptr != '\0') { print_char(*ptr); ptr++; }
            addiu   $sp, $sp, -8
            sw      $ra, 4($sp)         # salva $ra
            sw      $s0, 0($sp)         # salva $s0 (será usado como ponteiro)
            la      $t9, reg
            lw      $s0, 16($t9)        # $s0 <- reg[4] = endereço simulado da string
exec_syscall_4_laco:
            move    $a0, $s0            # $a0 <- endereço atual do ponteiro
            jal     verificar_endereco  # $v0 <- ponteiro real
                                        # ($t0 e $t1 são destruídos aqui, mas $s0 sobrevive)
            beqz    $v0, exec_syscall_4_fim  # endereço inválido: para
            lbu     $t2, 0($v0)         # $t2 <- byte corrente
            beq     $t2, $zero, exec_syscall_4_fim  # '\0': fim da string
            move    $a0, $t2
            li      $v0, 11             # syscall 11: print_char (MARS)
            syscall                     # $s0 não é modificado pelo syscall
            addiu   $s0, $s0, 1         # ptr++  ($s0 sobreviveu ao jal e ao syscall)
            j       exec_syscall_4_laco
exec_syscall_4_fim:
            lw      $s0, 0($sp)         # restaura $s0
            lw      $ra, 4($sp)
            addiu   $sp, $sp, 8
            j       main_laco

#   if (serviço == 11) print_char
exec_syscall_11:
            li      $t1, 11
            bne     $t0, $t1, exec_syscall_exit
            la      $t9, reg
            lw      $a0, 16($t9)  # $a0 <- reg[4] = código ASCII
            li      $v0, 11
            syscall
            j       main_laco

#   if (serviço == 10 || serviço == 17) exit / exit2
exec_syscall_exit:
            li      $t1, 10
            beq     $t0, $t1, exec_syscall_encerra
            li      $t1, 17
            beq     $t0, $t1, exec_syscall_encerra
            j       main_laco           # serviço não implementado: ignora
exec_syscall_encerra:
#           fim_programa = verdadeiro
            sw      $zero, sim_rodando  # sim_rodando <- 0
            j       main_laco
# }

#-------------------------------------------------------------------------------
# addu rd, rs, rt   :   rd = rs + rt
#
# Mapa de registradores
#       $t0     índice do registrador em bytes; valor de reg[rs]
#       $t1     valor de reg[rt]; resultado
#       $t2     índice de rd em bytes
#-------------------------------------------------------------------------------
exec_addu:
# {
#   reg[rd] = reg[rs] + reg[rt]
            lw      $t0, f_rs
            sll     $t0, $t0, 2
            la      $t9, reg
            add     $t9, $t9, $t0
            lw      $t0, 0($t9)  # $t0 <- reg[rs]
            lw      $t2, f_rt
            sll     $t2, $t2, 2
            la      $t9, reg
            add     $t9, $t9, $t2
            lw      $t1, 0($t9)  # $t1 <- reg[rt]
            addu    $t1, $t0, $t1       # $t1 <- reg[rs] + reg[rt]
            lw      $t2, f_rd           # $t2 <- índice de rd
            beq     $t2, $zero, main_laco   # reg[0] não é alterado
            sll     $t2, $t2, 2
            la      $t9, reg
            add     $t9, $t9, $t2
            sw      $t1, 0($t9)  # reg[rd] <- resultado
            j       main_laco
# }

#-------------------------------------------------------------------------------
# subu rd, rs, rt   :   rd = rs - rt
#
# Mapa de registradores
#       $t0     índice do registrador em bytes; valor de reg[rs]
#       $t1     valor de reg[rt]; resultado
#       $t2     índice de rd em bytes
#-------------------------------------------------------------------------------
exec_subu:
# {
#   reg[rd] = reg[rs] - reg[rt]
            lw      $t0, f_rs
            sll     $t0, $t0, 2
            la      $t9, reg
            add     $t9, $t9, $t0
            lw      $t0, 0($t9)  # $t0 <- reg[rs]
            lw      $t2, f_rt
            sll     $t2, $t2, 2
            la      $t9, reg
            add     $t9, $t9, $t2
            lw      $t1, 0($t9)  # $t1 <- reg[rt]
            subu    $t1, $t0, $t1       # $t1 <- reg[rs] - reg[rt]
            lw      $t2, f_rd
            beq     $t2, $zero, main_laco
            sll     $t2, $t2, 2
            la      $t9, reg
            add     $t9, $t9, $t2
            sw      $t1, 0($t9)  # reg[rd] <- resultado
            j       main_laco
# }

#-------------------------------------------------------------------------------
# addiu rt, rs, imm   :   rt = rs + sign_ext(imm)
#
# Mapa de registradores
#       $t0     índice do registrador em bytes; valor de reg[rs]
#       $t1     resultado
#       $t2     índice de rt em bytes
#-------------------------------------------------------------------------------
exec_addiu:
# {
#   reg[rt] = reg[rs] + f_imm
            lw      $t0, f_rs
            sll     $t0, $t0, 2
            la      $t9, reg
            add     $t9, $t9, $t0
            lw      $t0, 0($t9)  # $t0 <- reg[rs]
            lw      $t1, f_imm          # $t1 <- imediato (sign-extended)
            addu    $t1, $t0, $t1       # $t1 <- reg[rs] + imm
            lw      $t2, f_rt
            beq     $t2, $zero, main_laco
            sll     $t2, $t2, 2
            la      $t9, reg
            add     $t9, $t9, $t2
            sw      $t1, 0($t9)  # reg[rt] <- resultado
            j       main_laco
# }

#-------------------------------------------------------------------------------
# ori rt, rs, imm   :   rt = rs | zero_ext(imm)
# zero-extended: bits [31:16] = 0 (operações lógicas não propagam sinal)
#
# Mapa de registradores
#       $t0     índice do registrador em bytes; valor de reg[rs]
#       $t1     imediato zero-extended; resultado
#       $t2     índice de rt em bytes
#-------------------------------------------------------------------------------
exec_ori:
# {
#   reg[rt] = reg[rs] | zero_ext(f_imm)
            lw      $t0, f_rs
            sll     $t0, $t0, 2
            la      $t9, reg
            add     $t9, $t9, $t0
            lw      $t0, 0($t9)  # $t0 <- reg[rs]
            lw      $t1, f_imm
            andi    $t1, $t1, 0xFFFF    # $t1 <- imediato zero-extended
            or      $t1, $t0, $t1       # $t1 <- reg[rs] | imm
            lw      $t2, f_rt
            beq     $t2, $zero, main_laco
            sll     $t2, $t2, 2
            la      $t9, reg
            add     $t9, $t9, $t2
            sw      $t1, 0($t9)  # reg[rt] <- resultado
            j       main_laco
# }

#-------------------------------------------------------------------------------
# lui rt, imm   :   rt = imm << 16
# carrega imm nos 16 bits superiores; os 16 bits inferiores ficam zero
#
# Mapa de registradores
#       $t0     imediato; resultado
#       $t1     índice de rt em bytes
#-------------------------------------------------------------------------------
exec_lui:
# {
#   reg[rt] = f_imm << 16
            lw      $t0, f_imm
            andi    $t0, $t0, 0xFFFF    # $t0 <- apenas os 16 bits do imediato
            sll     $t0, $t0, 16        # $t0 <- imm deslocado para [31:16]
            lw      $t1, f_rt
            beq     $t1, $zero, main_laco
            sll     $t1, $t1, 2
            la      $t9, reg
            add     $t9, $t9, $t1
            sw      $t0, 0($t9)  # reg[rt] <- resultado
            j       main_laco
# }

#-------------------------------------------------------------------------------
# lw rt, imm(rs)   :   rt = mem[ reg[rs] + sign_ext(imm) ]
#
# Mapa de registradores
#       $t0     índice de rs em bytes; reg[rs]; endereço simulado
#       $t1     f_imm; índice de rt em bytes
#       $t2     ponteiro real; palavra lida
#-------------------------------------------------------------------------------
exec_lw:
# {
#   endereço efetivo = reg[rs] + f_imm
#   reg[rt] = mem[endereço efetivo]  (leitura de 4 bytes little-endian)
            addiu   $sp, $sp, -4
            sw      $ra, 0($sp)

            lw      $t0, f_rs
            sll     $t0, $t0, 2
            la      $t9, reg
            add     $t9, $t9, $t0
            lw      $t0, 0($t9)  # $t0 <- reg[rs]
            lw      $t1, f_imm
            add     $a0, $t0, $t1       # $a0 <- endereço simulado
            jal     verificar_endereco  # $v0 <- ponteiro real

#         lê 4 bytes em little-endian: byte 0 = LSB
            lbu     $t0, 0($v0)         # bits  [7: 0]
            lbu     $t2, 1($v0)         # bits [15: 8]
            sll     $t2, $t2, 8
            or      $t0, $t0, $t2
            lbu     $t2, 2($v0)         # bits [23:16]
            sll     $t2, $t2, 16
            or      $t0, $t0, $t2
            lbu     $t2, 3($v0)         # bits [31:24]
            sll     $t2, $t2, 24
            or      $t0, $t0, $t2       # $t0 <- palavra lida

            lw      $t1, f_rt
            beq     $t1, $zero, exec_lw_fim
            sll     $t1, $t1, 2
            la      $t9, reg
            add     $t9, $t9, $t1
            sw      $t0, 0($t9)  # reg[rt] <- palavra lida
exec_lw_fim:
            lw      $ra, 0($sp)
            addiu   $sp, $sp, 4
            j       main_laco
# }

#-------------------------------------------------------------------------------
# lbu rt, imm(rs)   :   rt = zero_ext( mem_byte[ reg[rs] + sign_ext(imm) ] )
#
# Mapa de registradores
#       $t0     índice de rs em bytes; reg[rs]; endereço simulado; byte lido
#       $t1     f_imm; índice de rt em bytes
#-------------------------------------------------------------------------------
exec_lbu:
# {
#   endereço efetivo = reg[rs] + f_imm
#   reg[rt] = byte lido (zero-extended para 32 bits)
            addiu   $sp, $sp, -4
            sw      $ra, 0($sp)

            lw      $t0, f_rs
            sll     $t0, $t0, 2
            la      $t9, reg
            add     $t9, $t9, $t0
            lw      $t0, 0($t9)  # $t0 <- reg[rs]
            lw      $t1, f_imm
            add     $a0, $t0, $t1       # $a0 <- endereço simulado
            jal     verificar_endereco  # $v0 <- ponteiro real
            lbu     $t0, 0($v0)         # $t0 <- byte (zero-extended)

            lw      $t1, f_rt
            beq     $t1, $zero, exec_lbu_fim
            sll     $t1, $t1, 2
            la      $t9, reg
            add     $t9, $t9, $t1
            sw      $t0, 0($t9)  # reg[rt] <- byte
exec_lbu_fim:
            lw      $ra, 0($sp)
            addiu   $sp, $sp, 4
            j       main_laco
# }

#-------------------------------------------------------------------------------
# sw rt, imm(rs)   :   mem[ reg[rs] + sign_ext(imm) ] = reg[rt]
#
# Mapa de registradores
#       $t0     índice de rs em bytes; reg[rs]; endereço simulado
#       $t1     f_imm; reg[rt]; byte a escrever
#       $t2     índice de rt em bytes; ponteiro real
#-------------------------------------------------------------------------------
exec_sw:
# {
#   endereço efetivo = reg[rs] + f_imm
#   mem[endereço efetivo] = reg[rt]  (escrita de 4 bytes little-endian)
            addiu   $sp, $sp, -4
            sw      $ra, 0($sp)

            lw      $t0, f_rs
            sll     $t0, $t0, 2
            la      $t9, reg
            add     $t9, $t9, $t0
            lw      $t0, 0($t9)         # $t0 <- reg[rs]
            lw      $t1, f_imm
            add     $a0, $t0, $t1       # $a0 <- endereço simulado

            jal     verificar_endereco  # $v0 <- ponteiro real
                                        # (verificar_endereco usa $t0 e $t1)

#         carrega reg[rt] APÓS o jal (evita que $t1 seja destruído internamente)
            lw      $t2, f_rt
            sll     $t2, $t2, 2
            la      $t9, reg
            add     $t9, $t9, $t2
            lw      $t1, 0($t9)         # $t1 <- reg[rt] = valor a escrever

#         escreve 4 bytes em little-endian: byte 0 = LSB
            sb      $t1, 0($v0)         # bits  [7: 0]
            srl     $t2, $t1, 8
            sb      $t2, 1($v0)         # bits [15: 8]
            srl     $t2, $t1, 16
            sb      $t2, 2($v0)         # bits [23:16]
            srl     $t2, $t1, 24
            sb      $t2, 3($v0)         # bits [31:24]

            lw      $ra, 0($sp)
            addiu   $sp, $sp, 4
            j       main_laco
# }

#-------------------------------------------------------------------------------
# sb rt, imm(rs)   :   mem_byte[ reg[rs] + sign_ext(imm) ] = reg[rt][7:0]
#
# Mapa de registradores
#       $t0     índice de rs em bytes; reg[rs]; endereço simulado
#       $t1     f_imm; reg[rt]
#       $t2     índice de rt em bytes; ponteiro real
#-------------------------------------------------------------------------------
exec_sb:
# {
#   endereço efetivo = reg[rs] + f_imm
#   mem_byte[endereço efetivo] = reg[rt][7:0]
            addiu   $sp, $sp, -4
            sw      $ra, 0($sp)

            lw      $t0, f_rs
            sll     $t0, $t0, 2
            la      $t9, reg
            add     $t9, $t9, $t0
            lw      $t0, 0($t9)         # $t0 <- reg[rs]
            lw      $t1, f_imm
            add     $a0, $t0, $t1       # $a0 <- endereço simulado

            jal     verificar_endereco  # $v0 <- ponteiro real
                                        # (verificar_endereco usa $t0 e $t1)

#         carrega reg[rt] APÓS o jal (evita que $t1 seja destruído internamente)
            lw      $t2, f_rt
            sll     $t2, $t2, 2
            la      $t9, reg
            add     $t9, $t9, $t2
            lw      $t1, 0($t9)         # $t1 <- reg[rt]

            sb      $t1, 0($v0)         # escreve byte (bits [7:0])

            lw      $ra, 0($sp)
            addiu   $sp, $sp, 4
            j       main_laco
# }

#-------------------------------------------------------------------------------
# beq rs, rt, offset   :   if (reg[rs] == reg[rt])  PC = PC + offset * 4
# Nota: decode já incrementou PC (+4), então: novo PC = PC_atual + f_imm * 4
#
# Mapa de registradores
#       $t0     índice de rs em bytes; reg[rs]
#       $t1     índice de rt em bytes; reg[rt]; offset em bytes
#       $t2     novo valor de PC
#-------------------------------------------------------------------------------
exec_beq:
# {
#   if (reg[rs] == reg[rt])  PC = PC + f_imm * 4
            lw      $t0, f_rs
            sll     $t0, $t0, 2
            la      $t9, reg
            add     $t9, $t9, $t0
            lw      $t0, 0($t9)  # $t0 <- reg[rs]
            lw      $t1, f_rt
            sll     $t1, $t1, 2
            la      $t9, reg
            add     $t9, $t9, $t1
            lw      $t1, 0($t9)  # $t1 <- reg[rt]
            bne     $t0, $t1, main_laco # reg[rs] != reg[rt]: sem desvio
            lw      $t1, f_imm
            sll     $t1, $t1, 2         # $t1 <- offset em bytes = f_imm * 4
            lw      $t2, PC
            add     $t2, $t2, $t1
            sw      $t2, PC             # PC <- PC + offset
            j       main_laco
# }

#-------------------------------------------------------------------------------
# bne rs, rt, offset   :   if (reg[rs] != reg[rt])  PC = PC + offset * 4
#
# Mapa de registradores
#       $t0     índice de rs em bytes; reg[rs]
#       $t1     índice de rt em bytes; reg[rt]; offset em bytes
#       $t2     novo valor de PC
#-------------------------------------------------------------------------------
exec_bne:
# {
#   if (reg[rs] != reg[rt])  PC = PC + f_imm * 4
            lw      $t0, f_rs
            sll     $t0, $t0, 2
            la      $t9, reg
            add     $t9, $t9, $t0
            lw      $t0, 0($t9)  # $t0 <- reg[rs]
            lw      $t1, f_rt
            sll     $t1, $t1, 2
            la      $t9, reg
            add     $t9, $t9, $t1
            lw      $t1, 0($t9)  # $t1 <- reg[rt]
            beq     $t0, $t1, main_laco # reg[rs] == reg[rt]: sem desvio
            lw      $t1, f_imm
            sll     $t1, $t1, 2
            lw      $t2, PC
            add     $t2, $t2, $t1
            sw      $t2, PC
            j       main_laco
# }

#-------------------------------------------------------------------------------
# j target   :   PC = field_target << 2
# (segmento de texto em 0x00400000 → PC[31:28] = 0x0)
#
# Mapa de registradores
#       $t0     novo valor de PC
#-------------------------------------------------------------------------------
exec_j:
# {
#   PC = f_addr << 2
            lw      $t0, f_addr
            sll     $t0, $t0, 2         # $t0 <- endereço destino
            sw      $t0, PC
            j       main_laco
# }

#-------------------------------------------------------------------------------
# jal target   :   reg[31] = PC;  PC = field_target << 2
# reg[31] recebe o endereço de retorno (PC já foi incrementado pelo decode)
#
# Mapa de registradores
#       $t0     endereço de retorno; depois novo valor de PC
#-------------------------------------------------------------------------------
exec_jal:
# {
#   reg[31] = PC  (endereço de retorno = endereço da instrução jal + 4)
#   PC = f_addr << 2
            lw      $t0, PC             # $t0 <- endereço de retorno
            la      $t9, reg
            sw      $t0, 124($t9)  # reg[31] <- endereço de retorno  (31 * 4 = 124)
            lw      $t0, f_addr
            sll     $t0, $t0, 2         # $t0 <- endereço destino
            sw      $t0, PC
            j       main_laco
# }

#===============================================================================
# Tarefa 2: Procedimento para verificar se um endereço pertence a um segmento
# Tarefa 4: Procedimento para ler do segmento de memória simulado
#
# verificar_endereco verifica o segmento e retorna o ponteiro real no buffer.
# Usado tanto na leitura quanto na escrita (Tarefa 3 usa o ponteiro retornado).
#===============================================================================

################################################################################
# Procedimento: verificar_endereco
# Verifica se um endereço simulado pertence a um dos segmentos de memória
# e retorna o ponteiro real correspondente no buffer do MARS.
#
# Argumento:  $a0 = endereço simulado
# Retorno:    $v0 = ponteiro real no buffer host
#
# Mapa de registradores
#       $t0     base do segmento sendo testado
#       $t1     ponteiro real = ponteiro base do buffer + offset
################################################################################
verificar_endereco:
# {
#   verifica segmento de texto: [0x00400000 .. 0x00401000)
            li      $t0, 0x00400000     # $t0 <- base do segmento de texto
            blt     $a0, $t0, ve_dados  # endereço < base: não é texto
            li      $t0, 0x00401000     # $t0 <- limite do segmento de texto
            bge     $a0, $t0, ve_dados  # endereço >= limite: não é texto
            li      $t0, 0x00400000
            sub     $t1, $a0, $t0       # $t1 <- offset = endereço - TEXT_BASE
            la      $t0, mem_text
            add     $v0, $t0, $t1       # $v0 <- ponteiro real em mem_text
            jr      $ra

ve_dados:
#   verifica segmento de dados: [0x10010000 .. 0x10011000)
            li      $t0, 0x10010000     # $t0 <- base do segmento de dados
            blt     $a0, $t0, ve_pilha
            li      $t0, 0x10011000
            bge     $a0, $t0, ve_pilha
            li      $t0, 0x10010000
            sub     $t1, $a0, $t0
            la      $t0, mem_data
            add     $v0, $t0, $t1       # $v0 <- ponteiro real em mem_data
            jr      $ra

ve_pilha:
#   verifica segmento de pilha: topo em 0x7FFFEFFC, cresce para endereços menores
#   offset = STACK_TOP - addr  (0 no topo, cresce positivamente para baixo)
            lui     $t0, 0x7fff
            ori     $t0, $t0, 0xeffc    # $t0 <- STACK_TOP = 0x7FFFEFFC
            sub     $t1, $t0, $a0       # $t1 <- offset = STACK_TOP - addr
            bltz    $t1, ve_invalido    # addr > STACK_TOP: inválido
            li      $t0, 4096
            bge     $t1, $t0, ve_invalido   # offset >= 4096: fora do segmento
            la      $t0, mem_stack
            add     $v0, $t0, $t1       # $v0 <- ponteiro real em mem_stack
            jr      $ra

ve_invalido:
#   endereço fora de qualquer segmento: sinaliza falha e encerra a simulação
            li      $v0, 0              # $v0 <- 0 (ponteiro nulo = falha)
            sw      $zero, sim_rodando
            jr      $ra
# }

#===============================================================================
# Tarefa 5: Procedimentos para ler os bytes de um arquivo e armazenar em
# um dos segmentos de memória simulado
#===============================================================================

################################################################################
# Procedimento: ler_arquivo_bin
# Abre o arquivo .bin e lê seu conteúdo para o segmento de texto simulado.
#
# Mapa de registradores
#       $s0     descritor de arquivo (fd)
################################################################################
ler_arquivo_bin:
# {
            addiu   $sp, $sp, -4
            sw      $ra, 0($sp)

            li      $v0, 4              # syscall 4: print_string
            la      $a0, msg_bin
            syscall

#   abre o arquivo .bin para leitura (syscall 13: open)
            li      $v0, 13
            la      $a0, arq_bin
            li      $a1, 0              # flags = 0: somente leitura
            li      $a2, 0
            syscall
            move    $s0, $v0            # $s0 <- fd
            bltz    $s0, erro_arquivo   # fd < 0: falha ao abrir

#   lê até 4096 bytes do arquivo para mem_text (syscall 14: read)
            li      $v0, 14
            move    $a0, $s0            # $a0 <- fd
            la      $a1, mem_text       # $a1 <- buffer destino
            li      $a2, 4096           # $a2 <- máximo de bytes
            syscall

#   fecha o arquivo (syscall 16: close)
            li      $v0, 16
            move    $a0, $s0
            syscall

            li      $v0, 4
            la      $a0, msg_ok
            syscall

            lw      $ra, 0($sp)
            addiu   $sp, $sp, 4
            jr      $ra
# }

################################################################################
# Procedimento: ler_arquivo_dat
# Abre o arquivo .dat e lê seu conteúdo para o segmento de dados simulado.
#
# Mapa de registradores
#       $s0     descritor de arquivo (fd)
################################################################################
ler_arquivo_dat:
# {
            addiu   $sp, $sp, -4
            sw      $ra, 0($sp)

            li      $v0, 4
            la      $a0, msg_dat
            syscall

#   abre o arquivo .dat para leitura (syscall 13: open)
            li      $v0, 13
            la      $a0, arq_dat
            li      $a1, 0
            li      $a2, 0
            syscall
            move    $s0, $v0
            bltz    $s0, erro_arquivo

#   lê até 4096 bytes do arquivo para mem_data (syscall 14: read)
            li      $v0, 14
            move    $a0, $s0
            la      $a1, mem_data
            li      $a2, 4096
            syscall

#   fecha o arquivo (syscall 16: close)
            li      $v0, 16
            move    $a0, $s0
            syscall

            li      $v0, 4
            la      $a0, msg_ok
            syscall

            lw      $ra, 0($sp)
            addiu   $sp, $sp, 4
            jr      $ra

erro_arquivo:
#   falha ao abrir arquivo: imprime mensagem e encerra
            li      $v0, 4
            la      $a0, msg_erro_arq
            syscall
            li      $v0, 10
            syscall
# }
