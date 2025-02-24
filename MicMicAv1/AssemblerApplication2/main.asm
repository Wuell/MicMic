.include "m328Pdef.inc"

.equ F_CPU = 16000000       ; Frequência do clock (16MHz)
.equ BAUD = 4800            ; Taxa de transmissão
.equ ubrr = 207

.equ DEBUG_LED = PB5   ; LED no pino PB5
.equ BIN_PIN = PD2

.def uart_status = r17
.def temp = r18
.def name_data = r19

.cseg
    .org 0x0000
    rjmp start         ; Reset vector -> Salta para o início do programa

	.org 0x0002
	rjmp button_isr
     ; Vetor de interrupção para INT0 (botão no PD2)

start:
	cli
	ldi temp, high(ubrr) 
	sts UBRR0H, temp
	ldi temp, low(ubrr)
	sts UBRR0L, temp

	ldi temp, (1<<TXEN0)
	sts UCSR0B, temp
	ldi temp, (1<<UCSZ01)|(1<<UCSZ00)
	sts UCSR0C, temp

	sbi DDRB, DEBUG_LED   ; Configura PB5 como saída

    ; Configurar botão no PD2
    cbi DDRD, BIN_PIN       ; Configura PD2 como entrada				  
    sbi PORTD, BIN_PIN		; Habilita pull-up interno

	; Configurar Interrupção Externa no INT0 (PD2)
	ldi temp, (1<<INT0)     ; Habilita a interrupção externa INT0
    out EIMSK, temp         ; Escreve em EIMSK (External Interrupt Mask Register)

    ldi temp, (1 << ISC11) | (1 << ISC01)    ; Interrupção na borda de descida (falling edge)
    sts EICRA, temp         ; Configura EICRA (External Interrupt Control Register A)

	sei

main:
    rjmp main

button_isr:
	sbi PORTB, DEBUG_LED
	push ZL
	push ZH


	ldi ZL, low(nome * 2)
	ldi ZH, high(nome * 2)
	call uart_print

	pop ZL
	pop ZH
	cbi PORTB, DEBUG_LED  ; Apaga LED
	reti	

uart_transmit:
	lds uart_status, UCSR0A  ; Carrega o registrador de status da UART
	sbrs uart_status, 5      ; Verifica se o bit 5 (UDRE0) está setado, se estiver pula a proxima linha de comando
	rjmp uart_transmit  ; Se não estiver pronto, espera
	sts UDR0, name_data
	ret

uart_print:
	lpm name_data, Z+
	cpi name_data, 0
	breq uart_done
	call uart_transmit
	rjmp uart_print

uart_done:
	ret

.cseg
.align 2
nome: .db 0x57, 0x65, 0x6C, 0x6C, 0x65, 0x72, 0x73, 0x6F, 0x6E, 0x0A, 0x00, 0x00