################################################################################
# SIMULADOR MIPS - ELC1011 Organização de Computadores
# Código em Assembly Puro (Sem Pseudo-instruções)
################################################################################

.data
# =========================================================
# TAREFA 1: Variáveis para a simulação do processador
# =========================================================
# (b) Banco de Registadores
BR:          .word 0:32          
# (c) Registadores Internos
PC:          .word 0x00400000    
IR:          .word 0             
# (d) Campos das Instruções
opcode:      .word 0
rs:          .word 0
rt:          .word 0
rd:          .word 0
shamt:       .word 0
funct:       .word 0
imm:         .word 0
target:      .word 0
# (a) Memória (3 segmentos de 4096 bytes)
mem_text:    .space 4096         
mem_data:    .space 4096         
mem_stack:   .space 4096         

arquivo_bin: .asciiz "trabalho_01-2026_1.bin"
arquivo_dat: .asciiz "trabalho_01-2026_1.dat"
msg_erro:    .asciiz "\n[Erro do Sistema] Instrucao ou Endereco Invalido.\n"

.text
.globl main
main:
    # --- Inicialização da Pilha do Programa Simulado ($sp = BR[29]) ---
    lui   $t0, 0x7FFF
    ori   $t0, $t0, 0xEFFC       # Topo da pilha simulada (0x7FFFEFFC)
    la    $t1, BR
    sw    $t0, 116($t1)          # Salva no offset 116 (29 * 4 bytes)

    # --- Chamadas da Tarefa 5 (Carregar Ficheiros) ---
    la    $a0, arquivo_bin
    la    $a1, mem_text
    jal   carregar_arquivo

    la    $a0, arquivo_dat
    la    $a1, mem_data
    jal   carregar_arquivo

    j     ciclo_principal

# ==============================================================================
# TAREFA 5: Procedimento para ler bytes de um ficheiro
# ==============================================================================
carregar_arquivo:
    addiu $sp, $sp, -16
    sw    $ra, 12($sp)
    sw    $s0, 8($sp)
    sw    $a1, 4($sp)            

    # Open
    ori   $v0, $zero, 13         
    add   $a1, $zero, $zero      
    add   $a2, $zero, $zero      
    syscall
    add   $s0, $zero, $v0        

    slt   $t0, $s0, $zero
    bne   $t0, $zero, erro_sistema

    # Read
    ori   $v0, $zero, 14         
    add   $a0, $zero, $s0
    lw    $a1, 4($sp)            
    ori   $a2, $zero, 4096       
    syscall

    # Close
    ori   $v0, $zero, 16         
    add   $a0, $zero, $s0
    syscall

    lw    $s0, 8($sp)
    lw    $ra, 12($sp)
    addiu $sp, $sp, 16
    jr    $ra

# ==============================================================================
# TAREFA 2: Verificar endereço (A nossa MMU - Unidade de Gestão de Memória)
# Argumentos: $a0 = Endereço Virtual
# Retorno: $v0 = Endereço Físico Real no MARS (0 se for inválido)
# ==============================================================================
verificar_endereco:
    # Segmento de Texto (0x00400000)
    lui   $t0, 0x0040
    subu  $t1, $a0, $t0
    sltiu $t2, $t1, 4096
    beq   $t2, $zero, verifica_dados
    la    $v0, mem_text
    addu  $v0, $v0, $t1
    jr    $ra

verifica_dados:
    # Segmento de Dados (0x10010000)
    lui   $t0, 0x1001
    subu  $t1, $a0, $t0
    sltiu $t2, $t1, 4096
    beq   $t2, $zero, verifica_pilha
    la    $v0, mem_data
    addu  $v0, $v0, $t1
    jr    $ra

verifica_pilha:
    # Segmento de Pilha (0x7FFFE000 até 0x7FFFEFFF)
    lui   $t0, 0x7FFF
    ori   $t0, $t0, 0xE000
    subu  $t1, $a0, $t0
    sltiu $t2, $t1, 4096
    beq   $t2, $zero, endereco_invalido
    la    $v0, mem_stack
    addu  $v0, $v0, $t1
    jr    $ra

endereco_invalido:
    add   $v0, $zero, $zero      
    jr    $ra

# ==============================================================================
# TAREFAS 3 e 4: Escrever e Ler da Memória a nível de Palavra (Word)
# ==============================================================================
escrever_memoria:
    addiu $sp, $sp, -8
    sw    $ra, 4($sp)
    sw    $a1, 0($sp)
    jal   verificar_endereco
    beq   $v0, $zero, erro_sistema
    lw    $a1, 0($sp)
    sw    $a1, 0($v0)            
    lw    $ra, 4($sp)
    addiu $sp, $sp, 8
    jr    $ra

ler_memoria:
    addiu $sp, $sp, -4
    sw    $ra, 0($sp)
    jal   verificar_endereco
    beq   $v0, $zero, erro_sistema
    lw    $v0, 0($v0)            
    lw    $ra, 0($sp)
    addiu $sp, $sp, 4
    jr    $ra

# ==============================================================================
# TAREFA 6: CICLO PRINCIPAL (FETCH - DECODE - EXECUTE)
# ==============================================================================
ciclo_principal:
    # --- FETCH ---
    lw    $a0, PC                
    jal   ler_memoria            
    sw    $v0, IR                
    beq   $v0, $zero, fim_simulacao 

    # --- DECODE ---
    lw    $t0, PC
    addiu $t0, $t0, 4
    sw    $t0, PC
    
    lw    $t3, IR                
    
    srl   $t4, $t3, 26            
    sw    $t4, opcode
    srl   $t4, $t3, 21            
    andi  $t4, $t4, 0x1F          
    sw    $t4, rs
    srl   $t4, $t3, 16            
    andi  $t4, $t4, 0x1F          
    sw    $t4, rt
    srl   $t4, $t3, 11            
    andi  $t4, $t4, 0x1F          
    sw    $t4, rd
    srl   $t4, $t3, 6             
    andi  $t4, $t4, 0x1F          
    sw    $t4, shamt
    andi  $t4, $t3, 0x3F          
    sw    $t4, funct
    andi  $t4, $t3, 0xFFFF        
    sw    $t4, imm
    andi  $t4, $t3, 0x3FFFFFF     
    sw    $t4, target

    # --- EXECUTE ---
    lw    $t5, opcode
    
    beq   $t5, $zero, exec_tipo_R
    
    ori   $t6, $zero, 2
    beq   $t5, $t6, exec_j
    
    ori   $t6, $zero, 3
    beq   $t5, $t6, exec_jal
    
    ori   $t6, $zero, 4
    beq   $t5, $t6, exec_beq
    
    ori   $t6, $zero, 5
    beq   $t5, $t6, exec_bne
    
    ori   $t6, $zero, 8
    beq   $t5, $t6, exec_addi
    
    ori   $t6, $zero, 9
    beq   $t5, $t6, exec_addiu
    
    ori   $t6, $zero, 13
    beq   $t5, $t6, exec_ori
    
    ori   $t6, $zero, 15
    beq   $t5, $t6, exec_lui
    
    ori   $t6, $zero, 35
    beq   $t5, $t6, exec_lw
    
    ori   $t6, $zero, 36
    beq   $t5, $t6, exec_lbu
    
    ori   $t6, $zero, 40
    beq   $t5, $t6, exec_sb
    
    ori   $t6, $zero, 43
    beq   $t5, $t6, exec_sw
    
    j     erro_sistema

exec_tipo_R:
    lw    $t6, funct
    
    beq   $t6, $zero, op_sll
    
    ori   $t7, $zero, 8
    beq   $t6, $t7, op_jr
    
    ori   $t7, $zero, 12
    beq   $t6, $t7, op_syscall
    
    ori   $t7, $zero, 32
    beq   $t6, $t7, op_add
    
    ori   $t7, $zero, 33
    beq   $t6, $t7, op_addu
    
    ori   $t7, $zero, 34
    beq   $t6, $t7, op_sub
    
    j     erro_sistema

# ==============================================================================
# --- ULA & CONTROLO - BLOCOS DE EXECUÇÃO ---
# ==============================================================================

# --- Aritmética e Lógica ---
op_add:
op_addu:
    la    $t0, BR
    lw    $t1, rs
    sll   $t1, $t1, 2
    addu  $t1, $t0, $t1
    lw    $t2, 0($t1)            
    lw    $t3, rt
    sll   $t3, $t3, 2
    addu  $t3, $t0, $t3
    lw    $t4, 0($t3)            
    addu  $t5, $t2, $t4          
    lw    $t6, rd
    beq   $t6, $zero, ciclo_principal 
    sll   $t6, $t6, 2
    addu  $t6, $t0, $t6
    sw    $t5, 0($t6)            
    j     ciclo_principal

op_sub:
    la    $t0, BR
    lw    $t1, rs
    sll   $t1, $t1, 2
    addu  $t1, $t0, $t1
    lw    $t2, 0($t1)
    lw    $t3, rt
    sll   $t3, $t3, 2
    addu  $t3, $t0, $t3
    lw    $t4, 0($t3)
    subu  $t5, $t2, $t4          
    lw    $t6, rd
    beq   $t6, $zero, ciclo_principal
    sll   $t6, $t6, 2
    addu  $t6, $t0, $t6
    sw    $t5, 0($t6)
    j     ciclo_principal

exec_addi:
exec_addiu:
    la    $t0, BR
    lw    $t1, rs
    sll   $t1, $t1, 2
    addu  $t1, $t0, $t1
    lw    $t2, 0($t1)            
    lw    $t3, imm
    sll   $t3, $t3, 16
    sra   $t3, $t3, 16           
    addu  $t5, $t2, $t3          
    lw    $t6, rt
    beq   $t6, $zero, ciclo_principal
    sll   $t6, $t6, 2
    addu  $t6, $t0, $t6
    sw    $t5, 0($t6)            
    j     ciclo_principal

exec_ori:
    la    $t0, BR
    lw    $t1, rs
    sll   $t1, $t1, 2
    addu  $t1, $t0, $t1
    lw    $t2, 0($t1)            
    lw    $t3, imm               
    or    $t5, $t2, $t3          
    lw    $t6, rt
    beq   $t6, $zero, ciclo_principal
    sll   $t6, $t6, 2
    addu  $t6, $t0, $t6
    sw    $t5, 0($t6)            
    j     ciclo_principal

exec_lui:
    lw    $t1, imm
    sll   $t1, $t1, 16           
    la    $t0, BR
    lw    $t6, rt
    beq   $t6, $zero, ciclo_principal
    sll   $t6, $t6, 2
    addu  $t6, $t0, $t6
    sw    $t1, 0($t6)            
    j     ciclo_principal

op_sll:
    la    $t0, BR
    lw    $t1, rt
    sll   $t1, $t1, 2
    addu  $t1, $t0, $t1
    lw    $t2, 0($t1)            
    lw    $t3, shamt
    sllv  $t5, $t2, $t3          
    lw    $t6, rd
    beq   $t6, $zero, ciclo_principal
    sll   $t6, $t6, 2
    addu  $t6, $t0, $t6
    sw    $t5, 0($t6)            
    j     ciclo_principal

# --- Saltos e Desvios ---
exec_j:
    lw    $t1, target
    sll   $t1, $t1, 2
    lw    $t2, PC
    lui   $t3, 0xF000
    and   $t2, $t2, $t3
    or    $t1, $t1, $t2
    sw    $t1, PC                
    j     ciclo_principal

exec_jal:
    la    $t0, BR
    ori   $t1, $zero, 31         # $ra
    sll   $t1, $t1, 2
    addu  $t1, $t0, $t1
    lw    $t2, PC                # PC já está incrementado (PC+4)
    sw    $t2, 0($t1)            
    lw    $t1, target
    sll   $t1, $t1, 2
    lw    $t2, PC
    lui   $t3, 0xF000
    and   $t2, $t2, $t3
    or    $t1, $t1, $t2
    sw    $t1, PC                
    j     ciclo_principal

op_jr:
    la    $t0, BR
    lw    $t1, rs
    sll   $t1, $t1, 2
    addu  $t1, $t0, $t1
    lw    $t2, 0($t1)            
    sw    $t2, PC
    j     ciclo_principal

exec_beq:
    la    $t0, BR
    lw    $t1, rs
    sll   $t1, $t1, 2
    addu  $t1, $t0, $t1
    lw    $t2, 0($t1)
    lw    $t3, rt
    sll   $t3, $t3, 2
    addu  $t3, $t0, $t3
    lw    $t4, 0($t3)
    bne   $t2, $t4, ciclo_principal
    lw    $t5, imm
    sll   $t5, $t5, 16
    sra   $t5, $t5, 16
    sll   $t5, $t5, 2            
    lw    $t6, PC
    addu  $t6, $t6, $t5          
    sw    $t6, PC
    j     ciclo_principal

exec_bne:
    la    $t0, BR
    lw    $t1, rs
    sll   $t1, $t1, 2
    addu  $t1, $t0, $t1
    lw    $t2, 0($t1)
    lw    $t3, rt
    sll   $t3, $t3, 2
    addu  $t3, $t0, $t3
    lw    $t4, 0($t3)
    beq   $t2, $t4, ciclo_principal
    lw    $t5, imm
    sll   $t5, $t5, 16
    sra   $t5, $t5, 16
    sll   $t5, $t5, 2            
    lw    $t6, PC
    addu  $t6, $t6, $t5          
    sw    $t6, PC
    j     ciclo_principal

# --- Memória ---
exec_lw:
    la    $t0, BR
    lw    $t1, rs
    sll   $t1, $t1, 2
    addu  $t1, $t0, $t1
    lw    $t2, 0($t1)            
    lw    $t3, imm
    sll   $t3, $t3, 16
    sra   $t3, $t3, 16           
    addu  $a0, $t2, $t3          
    jal   ler_memoria            
    la    $t0, BR
    lw    $t6, rt
    beq   $t6, $zero, ciclo_principal
    sll   $t6, $t6, 2
    addu  $t6, $t0, $t6
    sw    $v0, 0($t6)            
    j     ciclo_principal

exec_sw:
    la    $t0, BR
    lw    $t1, rs
    sll   $t1, $t1, 2
    addu  $t1, $t0, $t1
    lw    $t2, 0($t1)            
    lw    $t3, imm
    sll   $t3, $t3, 16
    sra   $t3, $t3, 16           
    lw    $t4, rt
    sll   $t4, $t4, 2
    addu  $t4, $t0, $t4
    lw    $a1, 0($t4)            
    addu  $a0, $t2, $t3          
    jal   escrever_memoria       
    j     ciclo_principal

exec_lbu:
    la    $t0, BR
    lw    $t1, rs
    sll   $t1, $t1, 2
    addu  $t1, $t0, $t1
    lw    $t2, 0($t1)            
    lw    $t3, imm
    sll   $t3, $t3, 16
    sra   $t3, $t3, 16           
    addu  $a0, $t2, $t3          # Endereço Virtual
    jal   verificar_endereco
    beq   $v0, $zero, erro_sistema
    lbu   $t5, 0($v0)            # Lê diretamente do endereço físico!
    la    $t0, BR
    lw    $t6, rt
    beq   $t6, $zero, ciclo_principal
    sll   $t6, $t6, 2
    addu  $t6, $t0, $t6
    sw    $t5, 0($t6)            
    j     ciclo_principal

exec_sb:
    la    $t0, BR
    lw    $t1, rs
    sll   $t1, $t1, 2
    addu  $t1, $t0, $t1
    lw    $t2, 0($t1)            
    lw    $t3, imm
    sll   $t3, $t3, 16
    sra   $t3, $t3, 16           
    lw    $t4, rt
    sll   $t4, $t4, 2
    addu  $t4, $t0, $t4
    lw    $t5, 0($t4)            
    addu  $a0, $t2, $t3          # Endereço Virtual
    jal   verificar_endereco
    beq   $v0, $zero, erro_sistema
    sb    $t5, 0($v0)            # Escreve byte diretamente no endereço físico!
    j     ciclo_principal

# --- Syscalls do Programa Simulado ---
op_syscall:
    la    $t0, BR
    lw    $t2, 8($t0)            # Lê $v0 virtual (BR[2])
    lw    $t3, 16($t0)           # Lê $a0 virtual (BR[4])

    ori   $t4, $zero, 10
    beq   $t2, $t4, fim_simulacao
    
    ori   $t4, $zero, 1
    beq   $t2, $t4, sys_print_int
    
    ori   $t4, $zero, 4
    beq   $t2, $t4, sys_print_string
    
    ori   $t4, $zero, 11
    beq   $t2, $t4, sys_print_char
    
    j     ciclo_principal        # Ignora syscalls desconhecidos

sys_print_int:
    add   $a0, $zero, $t3
    ori   $v0, $zero, 1
    syscall
    j     ciclo_principal

sys_print_char:
    add   $a0, $zero, $t3
    ori   $v0, $zero, 11
    syscall
    j     ciclo_principal

sys_print_string:
    # A string está no vetor mem_data. Usamos a MMU para traduzir o endereço.
    add   $a0, $zero, $t3
    jal   verificar_endereco
    beq   $v0, $zero, erro_sistema
    add   $a0, $zero, $v0        # $a0 físico real no MARS
    ori   $v0, $zero, 4
    syscall
    j     ciclo_principal

# --- ENCERRAMENTO ---
erro_sistema:
    la    $a0, msg_erro
    ori   $v0, $zero, 4
    syscall

fim_simulacao:
    ori   $v0, $zero, 10
    syscall