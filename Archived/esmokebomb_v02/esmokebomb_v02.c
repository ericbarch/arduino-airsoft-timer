/*	Eric's Timed Smokebomb v0.2  */

#include <avr/interrupt.h>	//Defines pins, ports, etc to make programs easier to read
#define F_CPU 100000UL		//Sets up the default speed for delay.h
#include <util/delay.h>		//Used to delay the script

//Initialization Variables/Macros
int bomb_state = 0;			//0 - Set Disarm Code, 1 - Set Time, 2 - Armed, 3 - Detonated, 4 - Diffused
int disarm_key_1 = 0;		//First disarm button
int disarm_key_2 = 0;		//Second disarm button
int disarm_key_3 = 0;		//Third disarm button
int disarm_key_4 = 0;		//Fourth disarm button
int current_min = 0;		//Set countdown minutes to our macro definition
int current_sec = 0;		//Seconds should be 0 to start off
int current_key_set = 1;	//Keeps track of the current disarm key we're setting for the display function
#define MULTIPLEXING_MS	50	//Time, in ms, to multiplex 7 segment array

/* 7 Segment Display Functions */

void display1_on(void)	//Enables Display 1 for Writing
{
	PORTD &= ~(1<<PD4);	//Enable Display 1
	PORTD |= (1<<PD5);		//Disable Display 2
}

void display2_on(void)	//Enables Display 2 for Writing
{
	PORTD &= ~(1<<PD5);	//Enable Display 2
	PORTD |= (1<<PD4);		//Disable Display 1
}

void clear_display(void)	//Clears all VCC 7 Segment Pins
{
	PORTD &= ~(1<<PD1);
	PORTD &= ~(1<<PD2);
	PORTD &= ~(1<<PD0);
	PORTA &= ~(1<<PA0);
	PORTA &= ~(1<<PA1);
	PORTB &= ~(1<<PB5);
	PORTB &= ~(1<<PB6);
	PORTB &= ~(1<<PB7);
}

//Takes binary "byte" and outputs to VCC pins of 7 segments
void display_segment_byte(int bita,int bitb,int bitc,int bitd,int bite,int bitf,int bitg,int bitdp)
{
	if (bita)
		PORTD |= (1<<PD1);
	if (bitb)
		PORTD |= (1<<PD2);
	if (bitc)
		PORTD |= (1<<PD0);
	if (bitd)
		PORTA |= (1<<PA0);
	if (bite)
		PORTA |= (1<<PA1);
	if (bitf)
		PORTB |= (1<<PB5);
	if (bitg)
		PORTB |= (1<<PB6);
	//Blink the dot LEDs every even second while armed
	if ((current_sec % 2) == 0 && bomb_state == 2)
		PORTB |= (1<<PB7);
}

//Function for multiplexing segment array
void display_segment_array(int disp, int num)
{
	if (disp == 1)
		display1_on();
	else if (disp == 2)
		display2_on();

	if (num == 0)
		display_segment_byte(1,1,1,1,1,1,0,0);
	else if (num == 1)
		display_segment_byte(0,1,1,0,0,0,0,0);
	else if (num == 2)
		display_segment_byte(1,1,0,1,1,0,1,0);
	else if (num == 3)
		display_segment_byte(1,1,1,1,0,0,1,0);
	else if (num == 4)
		display_segment_byte(0,1,1,0,0,1,1,0);
	else if (num == 5)
		display_segment_byte(1,0,1,1,0,1,1,0);
	else if (num == 6)
		display_segment_byte(1,0,1,1,1,1,1,0);
	else if (num == 7)
		display_segment_byte(1,1,1,0,0,0,0,0);
	else if (num == 8)
		display_segment_byte(1,1,1,1,1,1,1,0);
	else if (num == 9)
		display_segment_byte(1,1,1,1,0,1,1,0);
	else if (num == 11)		//Display a "d"
		display_segment_byte(0,1,1,1,1,0,1,0);
	else if (num == 22)		//Display an "e"
		display_segment_byte(1,0,0,1,1,1,1,0);
	else if (num == 33)		//Display a "b"
		display_segment_byte(0,0,1,1,1,1,1,0);
		
	_delay_ms(MULTIPLEXING_MS);
	clear_display();
}

/* End 7 Segment Display Functions */

void detonated(void)
{
	static int frame_counter = 0;
	
	frame_counter++;
	
	//Tells the program that we are in the detonated state
	bomb_state = 3;	
	
	//Run Buzzer / Smoke Igniter for 5 frames
	if (frame_counter <= 5)
		PORTD |= (1<<PD6);
	else
		PORTD &= ~(1<<PD6);	
}

void diffused(void)
{
	//Diffused Sequence
	bomb_state = 4;		//Tells the program that we are in the diffused state
}

void key_check(int input)
{
	static int current_key = 1;
	static int last_input = 0;
	
	//Make sure to ignore multiple "same" button presses (acts as debouncer)
	if (input != last_input)
	{
		switch (current_key)
		{
			case 1:
				if (input != disarm_key_1)
					detonated();
				else
					current_key++;
				break;
			case 2:
				if (input != disarm_key_2)
					detonated();
				else
					current_key++;
				break;
			case 3:
				if (input != disarm_key_3)
					detonated();
				else
					current_key++;
				break;
			case 4:
				if (input != disarm_key_4)
					detonated();
				else
					diffused();
				break;
		}
	}
	
	//Keep track of the last hit button
	last_input = input;
}

void set_keys(int input)
{
	static int last_input = 0;
	
	//Make sure to ignore multiple "same" button presses (acts as debouncer)
	if (input != last_input)
	{
		switch (current_key_set)
		{
			case 1:
				disarm_key_1 = input;
				current_key_set++;
				break;
			case 2:
				disarm_key_2 = input;
				current_key_set++;
				break;
			case 3:
				disarm_key_3 = input;
				current_key_set++;
				break;
			case 4:
				disarm_key_4 = input;
				current_key_set++;
				_delay_ms(1000);
				bomb_state++;
				break;
		}
	}
	
	//Keep track of the last hit button
	last_input = input;
}

void handle_inputs(void)
{
	static int keyswitch_enabled = 0;

	//Keyswitch
	if (PINB & (1<<PB4))	//If PB0 goes high
	{
		if (bomb_state == 1)
			bomb_state++;
			
		keyswitch_enabled = 1;	//Enable Keyswitch Based Functions
		PORTD |= (1<<PD3);		//Turn Keyswitch LED On
	}
	else	//If PB0 goes low
	{
		keyswitch_enabled = 0;	//Disable Keyswitch Based Functions
		PORTD &= ~(1<<PD3);	//Turn Keyswitch LED Off
	}

	//Keypad
	if (bomb_state == 0)
	{
		if (PINB & (1<<PB0))		//If PB1 goes high
			set_keys(1);
		else if (PINB & (1<<PB1))	//If PB2 goes high
			set_keys(2);
		else if (PINB & (1<<PB2))	//If PB3 goes high
			set_keys(3);
		else if (PINB & (1<<PB3))	//If PB4 goes high
			set_keys(4);
	}
	else if (bomb_state == 1)
	{
		if (PINB & (1<<PB0))		//If PB1 goes high
		{
			_delay_ms(500);
			if (PINB & (1<<PB0))
				current_min--;
		}
		else if (PINB & (1<<PB3))	//If PB2 goes high
		{
			_delay_ms(500);
			if (PINB & (1<<PB3))
				current_min++;
		}
			
		//Keep within our range of 0-99 minutes
		if (current_min < 0)
			current_min = 0;
		else if (current_min > 99)
			current_min = 99;
	}
	else if (keyswitch_enabled && bomb_state == 2)
	{
		if (PINB & (1<<PB0))		//If PB1 goes high
			key_check(1);
		else if (PINB & (1<<PB1))	//If PB2 goes high
			key_check(2);
		else if (PINB & (1<<PB2))	//If PB3 goes high
			key_check(3);
		else if (PINB & (1<<PB3))	//If PB4 goes high
			key_check(4);
	}
	
}


/*	Function:	proc_init()
	Purpose:	Handles initialization of the system on startup.
	Called:		main()	*/
void proc_init(void)
{
	/* PORT CONFIG */
	
	//Keyswitch and Keypad - Inputs
	DDRB &= ~(1<<PB0);	//Setup PB0 for input in direction register
	DDRB &= ~(1<<PB1);	//Setup PB1 for input in direction register
	DDRB &= ~(1<<PB2);	//Setup PB2 for input in direction register
	DDRB &= ~(1<<PB3);	//Setup PB3 for input in direction register
	DDRB &= ~(1<<PB4);	//Setup PB4 for input in direction register
	
	//7 Segment Array Grounds - Outputs
	DDRD |= (1<<PD4);	//Setup Display 1 Ground as output
	DDRD |= (1<<PD5);	//Setup Display 2 Ground as output
	
	//7 Segment Array VCC Pins - Outputs
	DDRD |= (1<<PD1);	//Setup A pin as output
	DDRD |= (1<<PD2);	//Setup B pin as output
	DDRD |= (1<<PD0);	//Setup C pin as output
	DDRA |= (1<<PA0);	//Setup D pin as output
	DDRA |= (1<<PA1);	//Setup E pin as output
	DDRB |= (1<<PB5);	//Setup F pin as output
	DDRB |= (1<<PB6);	//Setup G pin as output
	DDRB |= (1<<PB7);	//Setup DP pin as output
	
	//Status LEDs/Buzzers - Outputs
	DDRD |= (1<<PD3);	//Used for Keyswitch LED
	DDRD |= (1<<PD6);	//Used for Buzzer/Smoke
	
	//Interrupt Config - PCIE
	PCMSK |= (1<<PCINT0); 	//Tell pin change mask to listen to pin12
	PCMSK |= (1<<PCINT1); 	//Tell pin change mask to listen to pin13
	PCMSK |= (1<<PCINT2); 	//Tell pin change mask to listen to pin14
	PCMSK |= (1<<PCINT3); 	//Tell pin change mask to listen to pin15
	PCMSK |= (1<<PCINT4); 	//Tell pin change mask to listen to pin16
	GIMSK |= (1<<PCIE); 	//Enable PCINT interrupt in the general interrupt mask
	
	//Interrupt Config - TIMER1
	TCCR1B |= (1<<WGM12);					// Configure timer 1 for CTC mode
	TIMSK |= (1<<OCIE1A);					// Enable CTC interrupt
	OCR1A = 15625;							// Set CTC compare value (1mhz = 1000000/64 = 15625)
	TCCR1B |= ((1<<CS10) | (1<<CS11));	// Start timer at FCPU/64
	
	//Enable all interrupts
	sei();
}


/*	Function:	main()
	Purpose:	Main program loop.
	Called:		On System Startup	*/
int main(void)
{
	//Used to store digits for each 7 segment display we're writing to
	int dig1 = 0;
	int dig2 = 0;
	
	proc_init();		//Let's init everything
	
	//While we're setting the disarm code...
	while(bomb_state == 0)
	{
		display_segment_array(1,33);				//Writes a "b" to display 1
		display_segment_array(2,current_key_set);	//Writes the current button being set to display 2
	}
	
	//While we're not detonated or diffused...
	while(bomb_state == 1 || bomb_state == 2)
	{
		//Display Minutes
		if (current_min > 0)
		{
			dig2 = (current_min % 10);
			dig1 = ((current_min - dig2) / 10);
		}
		//Display Seconds
		else if (current_sec > 0)
		{
			dig2 = (current_sec % 10);
			dig1 = ((current_sec - dig2) / 10);
		}
		//Display 00s
		else
			dig2 = dig1 = 0;
		
		//Actually write the display values to the segment array
		display_segment_array(1,dig1);	//Writes the first digit to display 1
		display_segment_array(2,dig2);	//Writes the second digit to display 2
	}
	
	//While we're detonated...
	while(bomb_state == 3)
	{
		display_segment_array(1,22);	//Writes an "e" to display 1
		display_segment_array(2,22);	//Writes an "e" to display 2
	}
	
	//While we're diffused...
	while(bomb_state == 4)
	{
		display_segment_array(1,11);	//Writes a "d" to display 1
		display_segment_array(2,11);	//Writes a "d" to display 2
	}
	
	return(0);
}


SIGNAL (SIG_PCINT)
{
	handle_inputs();	//A keypad/keyswitch interrupt has occured! Handle it to figure out which pin.
}


ISR(TIMER1_COMPA_vect)
{
	if (bomb_state == 2)
	{
		current_sec--;
		if (current_sec < 0)
		{
			current_min--;
			current_sec = 59;
		}
		if (current_min < 0)
			detonated();
	}
	else if (bomb_state == 3)
		detonated();
}
