/*
  SLCD.cpp - Library for controlling Sparkfun SerLCD
  serial lcd controller
  Created by Ian McDougall, April 27, 2008.

  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 2.1 of the License, or (at your option) any later version.

  This library is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with this library; if not, write to the Free Software
  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
*/

#include <inttypes.h> 
#include <stdlib.h>
#include "WConstants.h" 
#include "SLCD.h"      

#include "NewSoftSerial.h"

#define SPECIAL_CONTROL 0x7C
#define DISPLAY_CONTROL	0xFE
#define CLEAR			0x01
#define CURSOR_RIGHT	0x14
#define CURSOR_LEFT		0x10
#define SCROLL_RIGHT	0x1C
#define SCROLL_LEFT		0x18
#define DISPLAY_ON		0x0C
#define DISPLAY_OFF		0x08
#define UNDERLINE_CURSOR_ON		0x0E
#define UNDERLINE_CURSOR_OFF	0x0C
#define BLINK_CURSOR_ON		0x0D
#define BLINK_CURSOR_OFF	0x0C
#define SET_POSITION		0x80
   
NewSoftSerial mySerial(7, 8);

SLCD::SLCD(int rows, int cols)
{                          
  	_numRows = rows;
	_numCols = cols;
}

void SLCD::init()
{   
	mySerial.begin(9600);  
                     
	clear();
	print("SerLCD Class", 0, 2);
	brightness(100);
	underlineCursorOff();
	print("initialized", 1, 3);
	
	flash(3, 100) ;
}

void SLCD::brightness(int pct) { 
	int level = (pct > 100 ? pct % 100 : pct); 
	
	float brightness = (((float)level)/100) * 29 + 128;
 	mySerial.print((char)SPECIAL_CONTROL);
 	mySerial.print((char)brightness);
	// wait for the long string to be sent 
	delay(5); 
}

void SLCD::flash(int count, int delayMs) {
	
	for (int i=0 ; i < count; i++) {
		brightness(0);
		delay(delayMs%1000);
		brightness(100);
		delay(delayMs%1000);
	}
	
}
     
void SLCD::print(const char *s, int line, int col) {
	cursor(line, col);
	mySerial.print(s);
} 

void SLCD::print(int line, int col, const char *s) {
	print(s, line, col);
}

void SLCD::print(const char *s) {
	mySerial.print(s);
}  

void SLCD::vscroll(int spaces, int delayMs) {
  byte controlChar = (spaces >= 0)  ? SCROLL_RIGHT : SCROLL_LEFT;

  int numSpaces = abs(spaces);

  for (int i =0; i<numSpaces; i++) {
   sendControl((char)controlChar);
    delay(delayMs); 
  }
}


void SLCD::sendControl(char c) {
   	mySerial.print((char)DISPLAY_CONTROL);
    mySerial.print(c);
}

void SLCD::clear() {
 sendControl(CLEAR);
}

void SLCD::cursor(int line, int col) {

	line %= _numRows;      
	col %= _numCols;
	int offset = ((line%2)*64) + (line >1 ? 20 : 0);
    
 	sendControl((char)(offset + col + 128));
  	delay(10);
}      
 
void SLCD::cursorLeft(){
	sendControl(CURSOR_LEFT);
}   

void SLCD::cursorRight(){
	sendControl(CURSOR_RIGHT);		
}
   
		
void SLCD::underlineCursorOn(){
	sendControl(UNDERLINE_CURSOR_ON); 
}
void SLCD::underlineCursorOff(){
	sendControl(UNDERLINE_CURSOR_OFF);
}
	
void SLCD::blinkCursorOn(){
	sendControl(BLINK_CURSOR_ON);
}
void SLCD::blinkCursorOff(){
	sendControl(BLINK_CURSOR_OFF);
}


void SLCD::displayOn(){
	sendControl(DISPLAY_ON);
}
void SLCD::displayOff(){
	sendControl(DISPLAY_OFF);	
}


