; Bytte hur knapparna är kopplade.

; Makrodefinitioner:
.EQU LED1 = PORTB0 ; Lysdiod 1 ansluten till pin 8 (PORTB0).
.EQU LED2 = PORTB1 ; Lysdiod 2 ansluten till pin 9 (PORTB1).

.EQU BUTTON1 = PORTB4 ; Button 1 ansluten till pin 11 (PORTB3)
.EQU BUTTON2 = PORTB5 ; Button 2 ansluten till pin 12 (PORTB4)
.EQU BUTTON3 = PORTB3 ; Button 3 ansluten till pin 11 (PORTB5)

.EQU TIMER0_MAX_COUNT = 18  ; 18 timeravbrott för 300 ms fördröjning.
.EQU TIMER1_MAX_COUNT = 6 ; 6 timeravbrott för 100 ms fördröjning.
.EQU TIMER2_MAX_COUNT = 12 ; 12 timeravbrott för 200 ms fördröjning.

.EQU RESET_vect        = 0x00 ; Reset-vektor, utgör programmets startpunkt.
.EQU PCINT0_vect	   = 0x06 ; Avbrottsvektor för PCI-avbrott på I/O-port B.
.EQU TIMER2_OVF_vect   = 0x12 ; Avbrottsvektor för Timer 2 i Normal Mode.
.EQU TIMER1_COMPA_vect = 0x16 ; Avbrottsvektor för Timer 1 i CTC Mode.
.EQU TIMER0_OVF_vect   = 0x20 ; Avbrottsvektor för Timer 0 i Normal Mode.

.DEF LED1_REG    = R16 ; CPU-register som lagrar (1 << LED1).
.DEF LED2_REG    = R17 ; CPU-register som lagrar (1 << LED2).
.DEF COUNTER_REG = R24 ; CPU-register för uppräkning och jämförelse av räknarvariablerna.

;/********************************************************************************
;* .DSEG (Data Segment): Dataminnet
;********************************************************************************/
.DSEG
.ORG SRAM_START ; Deklaration av statiska variabler i början av dataminnet.
   timer0_counter: .byte 1 ; static uint8_t timer0_counter = 0;
   timer1_counter: .byte 1 ; static uint8_t timer1_counter = 0;
   timer2_counter: .byte 1 ; static uint8_t timer2_counter = 0;

;/********************************************************************************
;* .CSEG (Code Segment): Programminnet - Här lagras programkod och konstanter.
;********************************************************************************/
.CSEG 

;/********************************************************************************
;* RESET_vect: Programmet startpunkt, som även hoppas till vid systemåterställning.
;*             Programhopp sker till subrutinen main för att starta programmet.
;********************************************************************************/
.ORG RESET_vect
   RJMP main

;/********************************************************************************
;* PCINT0_vect: Avbrottsvektor för PCI-avbrott på I/O-port B, som äger rum vid
;*              nedtryckning eller uppsläppning av någon av tryckknapparna.
;*              Hopp sker till motsvarande avbrottsrutin ISR_PCINT0 för att
;*              hantera avbrottet.
;********************************************************************************/
.ORG PCINT0_vect
   RJMP ISR_PCINT0

;/********************************************************************************
;* TIMER2_OVF_vect: Avbrottsvektor för Timer 2 i Normal Mode, som hoppas till
;*                  var 16.384:e ms. Programhopp sker till motsvarande
;*                  avbrottsrutin ISR_TIMER2_OVF för att hantera avbrottet.
;********************************************************************************/
.ORG TIMER2_OVF_vect
   RJMP ISR_TIMER2_OVF

;/********************************************************************************
;* TIMER1_COMPA_vect: Avbrottsvektor för Timer 1 i CTC Mode, som hoppas till
;*                    var 16.384:e ms. Programhopp sker till motsvarande
;*                    avbrottsrutin ISR_TIMER1_COMPA för att hantera avbrottet.
;********************************************************************************/
.ORG TIMER1_COMPA_vect
   RJMP ISR_TIMER1_COMPA

;/********************************************************************************
;* TIMER0_OVF_vect: Avbrottsvektor för Timer 0 i Normal Mode, som hoppas till
;*                  var 16.384:e ms. Programhopp sker till motsvarande
;*                  avbrottsrutin ISR_TIMER0_OVF för att hantera avbrottet.
;********************************************************************************/
.ORG TIMER0_OVF_vect
   RJMP ISR_TIMER0_OVF

;/********************************************************************************
;* ISR_PCINT0: Avbrottsrutin för hantering av PCI-avbrott på I/O-port B, som
;*             äger rum vid nedtryckning eller uppsläppning av någon av 
;*             tryckknapparna. Om nedtryckning av en tryckknapp orsakade 
;*             avbrottet togglas motsvarande lysdiod, annars görs ingenting.
;********************************************************************************/
ISR_PCINT0:
   CLR R24
   STS PCICR, R24  ; Stänger av PCI-avbrott i 300 ms.
   STS TIMSK0, R16 ; Sätter på Timer 0, som räknar upp dessa 300 ms.
	IN R24, PINB
	ANDI R24, (1 << BUTTON1)
	BREQ ISR_PCINT0_2
	RCALL timer1_toggle ; Togglar Timer 1 vid nedtryckning i stället för LED1.
	RETI
ISR_PCINT0_2:
    IN R24, PINB
	ANDI R24, (1 << BUTTON2)
	BREQ ISR_PCINT0_3
	RCALL timer2_toggle ; Togglar Timer 2 vid nedtryckning i stället för LED2.
	RETI 
ISR_PCINT0_3: ; Om BUTTON3 är nedtryckt genomförs systemåterställning.
   IN R24, PINB
   ANDI R24, (1 << BUTTON3)
   BREQ ISR_PCINT0_end
   RCALL system_reset
ISR_PCINT0_end:
    RETI   

;/********************************************************************************
;* ISR_TIMER0_OVF: Avbrottsrutin för Timer 0 i Normal Mode, som äger rum var 
;*                 16.384:e ms vid overflow (uppräkning till 256, då räknaren 
;*                 blir överfull). Ungefär var 100:e ms (var 6:e avbrott) 
;*                 togglas lysdiod LED1.
;********************************************************************************/
ISR_TIMER0_OVF:
   LDS R24, timer0_counter   
   INC R24                   
   CPI R24, TIMER0_MAX_COUNT 
   BRLO ISR_TIMER0_OVF_end           
   STS PCICR, R16 ; PCICR = (1 << PCIE0) => Återställer PCI-avbrott.
   CLR R24   
   STS TIMSK0, R24 ; TIMSK0 = 0 => Inaktiverar Timer 0.            
ISR_TIMER0_OVF_end:
   STS timer0_counter, R24
   RETI                              
   
;/********************************************************************************
;* ISR_TIMER1_COMPA: Avbrottsrutin för Timer 1 i CTC Mode, som äger rum var 
;*                   16.384:e ms vid vid uppräkning till 256. Ungefär var 
;*                   100:e ms (var 6:e avbrott) togglas lysdiod LED1.
;********************************************************************************/
ISR_TIMER1_COMPA:
   LDS COUNTER_REG, timer1_counter   
   INC COUNTER_REG                   
   CPI COUNTER_REG, TIMER1_MAX_COUNT 
   BRLO ISR_TIMER1_COMPA_end         
   OUT PINB, LED1_REG                
   LDI COUNTER_REG, 0x00             
ISR_TIMER1_COMPA_end :
   STS timer1_counter, COUNTER_REG   
   RETI                              

;/********************************************************************************
;* ISR_TIMER2_OVF: Avbrottsrutin för Timer 2 i Normal Mode, som äger rum var 
;*                 16.384:e ms vid overflow (uppräkning till 256, då räknaren 
;*                 blir överfull). Ungefär var 200:e ms (var 12:e avbrott) 
;*                 togglas lysdiod LED2.
;********************************************************************************/
ISR_TIMER2_OVF:
   LDS COUNTER_REG, timer2_counter   
   INC COUNTER_REG                   
   CPI COUNTER_REG, TIMER2_MAX_COUNT 
   BRLO ISR_TIMER2_OVF_end           
   OUT PINB, LED2_REG                
   LDI COUNTER_REG, 0x00             
ISR_TIMER2_OVF_end:
   STS timer2_counter, COUNTER_REG   
   RETI         

;/********************************************************************************
;* Du hade skapat denna subrutin som en branch döpt timer_toggle i ISR_PCINT0.
;* Denna var bra gjord, men det finns inget behov av toggling av Timer 0. Däremot
;* finns behov av toggling av Timer 1 - 2. Jag ger dig toggling av Timer 1 här,
;* du kan göra motsvarande för Timer 2 sedan.
;********************************************************************************/
timer1_toggle:
	LDS R24, TIMSK1			  
	ANDI R24, (1 << OCIE1A) 
	BRNE timer1_off			  
timer1_on:
	STS TIMSK1, R17 ; TIMSK1 = (1 << OCIE1A);          
	RETI
timer1_off:
	CLR R24					  
	STS TIMSK1, R24 ; TIMSK1 = 0;			  
	IN R24, PORTB	 ; PORTB &= ~(1 << LED1)
	ANDI R24, ~(1 << LED1)	  
	OUT PORTB, R24			 
   RET   
   
;/********************************************************************************
;* Fixa denna!
;********************************************************************************/
timer2_toggle:
   LDS R24, TIMSK2
   ANDI R24, (1 << OCIE2A)
   BRNE timer2_off
timer2_on:
   STS TIMSK2, R17
   RETI
timer2_off:
   CLR R24
   STS TIMSK0, R24
   IN R24, PORTB
   ANDI R24, ~(1 << LED2)
   OUT PORTB, R24
  RET

   
 
   
;/********************************************************************************
;* system_reset: Återställer systemet till startläge; Timer 1 - Timer 2 
;*               inaktiveras och LED1 - LED2 släcks. Timer 0 inaktiveras ej,
;*               då den inaktiverar "sig själv" efter 300 ms och samtidigt 
;*               återställer PCI-avbrott. Om Timer 0 var aktiverad och vi
;*               stängde av den här hade PCI-avbrott inte återställts.
;********************************************************************************/
system_reset:
   CLR R24
   STS TIMSK1, R24
   STS TIMSK2, R24
   IN R24, PORTB
   ANDI R24, ~((1 << LED1) | (1 << LED2))
   OUT PORTB, R24
   RET

;/********************************************************************************
;* main: Initierar systemet vid start. Programmet hålls sedan igång så länge
;*       matningsspänning tillförs.
;********************************************************************************/
main:
;/********************************************************************************
;* setup: Sätter lysdiodernas pinnar till utportar samt aktiverar timerkretsarna
;*        så att avbrott sker var 16.384:e millisekund för respektive timer.
;*        Notering: 256 = 1 0000 0000, som skrivs till OCR1AH respektive OCR1AL.
;********************************************************************************/
setup:
   LDI R16, (1 << LED1) | (1 << LED2)			     
   OUT DDRB, R16                                     
   LDI R24, (1 << BUTTON1) | (1 << BUTTON2) | (1 << BUTTON3)
   OUT PORTB, R24
init_registers:
   LDI R16, (1 << LED1) ; Du lade till dessa längre ned, men du använder dem i init_interrupts,
                        ; så lade till dem här.
   LDI R17, (1 << LED2)
 init_interrupts:
   SEI   
   STS PCICR, R16
   STS PCMSK0, R24                                            
init_timer0:
   LDI R24, (1 << CS02) | (1 << CS00)  ; Undviker överskrivning av R16-R17, använder R24 i stället.            
   OUT TCCR0B, R24                              
   ; Timer 0 ska inte vara på vid start (sätts på när någon av knapparna trycks ned), så tog bort kod här.   
init_timer1:
   LDI R24, (1 << CS12) | (1 << CS10) | (1 << WGM12) 
   STS TCCR1B, R24                               
   LDI R25, 0x01                                     
   LDI R24, 0x00                                     
   STS OCR1AH, R25                                   
   STS OCR1AL, R24                                   
   ; Timer 1 ska inte vara på heller förrän BUTTON1 trycks ned, då den togglas, så tog bort här.                             
init_timer2:
   LDI R24, (1 << CS22) | (1 << CS21) | (1 << CS20)  
   STS TCCR2B, R24                                   
   ; Timer 1 ska inte vara på heller förrän BUTTON1 trycks ned, då den togglas, så tog bort här.                  
   
/********************************************************************************
* main_loop: Kontinuerlig loop som håller igång programmet.
********************************************************************************/
main_loop:   
   RJMP main_loop 