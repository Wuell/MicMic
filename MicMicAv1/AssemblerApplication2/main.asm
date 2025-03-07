.include "m328Pdef.inc"  ; Inclui definições para o microcontrolador ATmega328P

; Definição de constantes
.equ F_CPU = 16000000       ; Frequência do clock (16MHz)
.equ BAUD = 4800            ; Taxa de transmissão serial
.equ ubrr = 207             ; Valor do UBRR para configurar a taxa de transmissão

.equ DEBUG_LED = PB5   ; Define o pino PB5 como LED de depuração
.equ BIN_PIN = PD2     ; Define o pino PD2 como entrada para botão

; Definição de registradores para uso geral
.def uart_status = r17
.def temp = r18
.def name_data = r19
.def received_data = r20
.def data_segment = r21
.def char_count = r22

.cseg
    .org 0x0000
    rjmp start         ; Vetor de reset -> Salta para o início do programa

	.org 0x0002
	rjmp button_isr    ; Vetor de interrupção para INT0 (botão no PD2)

	.org 0x0024
	rjmp uart_rx_isr   ; Vetor de interrupção para recepção da UART

; =============================
;  Inicialização do Sistema
; =============================
start:
	cli                      ; Desabilita interrupções globais durante a configuração
	ldi temp, high(ubrr)     
	sts UBRR0H, temp         ; Configura taxa de transmissão UART
	ldi temp, low(ubrr)
	sts UBRR0L, temp

	ldi temp, (1<<TXEN0) | (1<<RXEN0) | (1<<RXCIE0)
	sts UCSR0B, temp         ; Habilita transmissão, recepção e interrupção de recepção da UART
	ldi temp, (3 << UCSZ00)
	sts UCSR0C, temp         ; Configura o formato do frame UART (8 bits, sem paridade, 1 stop bit)

	sbi DDRB, DEBUG_LED   ; Configura PB5 como saída (LED de depuração)

    ; Configuração do botão no PD2
    cbi DDRD, BIN_PIN       ; Configura PD2 como entrada				  
    sbi PORTD, BIN_PIN      ; Habilita pull-up interno no botão

	ldi temp, 0xFF
	out DDRC, temp          ; Configura PORTC como saída (para display de 7 segmentos)
	out PORTC, temp         ; Inicializa PORTC em alto (evita ruídos)

	; Configurar Interrupção Externa no INT0 (PD2)
	ldi temp, (1<<INT0)     ; Habilita a interrupção externa INT0
    out EIMSK, temp         ; Escreve no registrador de máscara de interrupção externa

    ldi temp, (1 << ISC11) | (1 << ISC01)    ; Interrupção na borda de descida (falling edge)
    sts EICRA, temp         ; Configura EICRA para ativar a interrupção no INT0

	sei                      ; Habilita interrupções globais

main:
    rjmp main   ; Loop infinito

; =============================
;  Rotina de Transmissão UART
; =============================
uart_transmit:
	lds uart_status, UCSR0A  ; Carrega o registrador de status da UART
	sbrs uart_status, 5      ; Verifica se o buffer de transmissão está pronto
	rjmp uart_transmit       ; Se não estiver pronto, espera
	sts UDR0, name_data      ; Transmite o caractere armazenado em name_data
	ret

; =============================
;  Rotina de Recepção UART
; =============================
uart_receive:
	lds uart_status, UCSR0A  ; Carrega o status da UART
	sbrs uart_status, RXC0   ; Verifica se há um dado recebido
	rjmp uart_receive        ; Se não, espera
	lds received_data, UDR0  ; Lê o dado recebido
	ret

; =============================
;  Interrupção do Botão (PD2)
; =============================
button_isr:
	sbi PORTB, DEBUG_LED  ; Acende o LED de depuração
	push ZL
	push ZH

	ldi ZL, low(nome * 2)
	ldi ZH, high(nome * 2)
	call uart_print       ; Chama a rotina para imprimir a string armazenada em "nome"

	pop ZL
	pop ZH
	cbi PORTB, DEBUG_LED  ; Apaga LED
	reti	

; =============================
;  Rotina para Envio de Strings via UART
; =============================
uart_print:
	lpm name_data, Z+    ; Lê um caractere da memória do programa
	cpi name_data, 0     ; Verifica se é o final da string
	breq uart_done       ; Se for, encerra a transmissão
	call uart_transmit   ; Envia o caractere atual pela UART
	rjmp uart_print      ; Continua enviando até chegar ao final

uart_done:
	ret

; =============================
;  Interrupção de Recepção UART
; =============================
uart_rx_isr:
	sbi PORTB, DEBUG_LED  ; Acende LED de debug para indicar recepção de dado
	push temp
    call uart_receive     ; Recebe o dado da UART
    call update_display   ; Atualiza o display com o dado recebido
    pop temp
    reti  ; Retorna da interrupção

; =============================
;  Atualização do Display de 7 Segmentos
; =============================
update_display:
    ; Compara o caractere recebido com os valores ASCII dos números de 0 a 9
    cpi received_data, 0x30
    ldi data_segment, 0x3f  ; '0'
    breq exibi
    cpi received_data, 0x31
    ldi data_segment, 0x06  ; '1'
    breq exibi
    cpi received_data, 0x32
    ldi data_segment, 0x5b  ; '2'
    breq exibi
    cpi received_data, 0x33
    ldi data_segment, 0x4f  ; '3'
    breq exibi
    cpi received_data, 0x34
    ldi data_segment, 0x66  ; '4'
    breq exibi
    cpi received_data, 0x35
    ldi data_segment, 0x6d  ; '5'
    breq exibi
    cpi received_data, 0x36
    ldi data_segment, 0x7d  ; '6'
    breq exibi
    cpi received_data, 0x37
    ldi data_segment, 0x07  ; '7'
    breq exibi
    cpi received_data, 0x38
    ldi data_segment, 0x7f  ; '8'
    breq exibi
    cpi received_data, 0x39
    ldi data_segment, 0x6f  ; '9'
    breq exibi

    ; Comparação para letras minúsculas 'a' a 'f'
    cpi received_data, 0x41
    ldi data_segment, 0x77  ; 'a'
    breq exibi
    cpi received_data, 0x42
    ldi data_segment, 0x7c  ; 'b'
    breq exibi
    cpi received_data, 0x43
    ldi data_segment, 0x39  ; 'c'
    breq exibi
    cpi received_data, 0x44
    ldi data_segment, 0x5e  ; 'd'
    breq exibi
    cpi received_data, 0x45
    ldi data_segment, 0x79  ; 'e'
    breq exibi
    cpi received_data, 0x46
    ldi data_segment, 0x71  ; 'f'
    breq exibi

    ; Se não for um caractere válido, exibir '-'
	ldi data_segment, 0x40
	breq exibi

exibi:
    out PORTC, data_segment  ; Atualiza o display de 7 segmentos
    ret

; =============================
;  Definição da String "nome"
; =============================
.cseg
.align 2
nome: .db "Wellerson", 0x0A, 0x0A, 0x00  ; Nome a ser exibido via UART
