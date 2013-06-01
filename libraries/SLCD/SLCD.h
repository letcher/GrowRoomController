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


#ifndef SLCD_h
#define SLCD_h
  
#include <inttypes.h> 
 

class SLCD
{
  public:
    SLCD( int, int);
	void init();      
	void brightness(int);   
	void flash(int, int); 

    void print(const char[], int, int);  
    void print(int, int, const char[]);   
	void print(const char[]);
    void vscroll(int, int);  

	void clear();  
	void cursor(int, int);
	void cursorLeft();
	void cursorRight();
	void underlineCursorOn();
	void underlineCursorOff();
	void blinkCursorOn();
	void blinkCursorOff();
	void displayOn();
	void displayOff();

  private:      
	void sendControl(char);
    int _numRows;
	int _numCols;
   
};

#endif
