#include <SLCD.h>

// SLCD Demo
// by Ian McDougall 

// Demonstrates the use of the SLCD (Serial LCD) 
// library for the SparkFun serLCD controller

// Created 7 May 2008

// demo is for 2x16 char display
#define numRows 2
#define numCols 16

SLCD lcd = SLCD(numRows, numCols);

void setup() 
{ 
  lcd.init();
} 

void loop() 
{ 
  textTest();
  delay(1000);
  flashTest();
  delay(1000);
  fadeTest();
  delay(1000);
  scrollTest();
  delay(1000);
  cursorTest();
  delay(1000);

} 

void textTest() {
  lcd.clear();
  lcd.print("Print", 0, 6);
  lcd.print("test", 1, 6);
  delay(1000);
  lcd.clear();

  // can use string, line, col
  lcd.print("Hello", 0, 0); 
  // or line, col, string
  lcd.print(1, 11, "World"); 

  delay(500);
  lcd.print("Hello", 0, 11); 
  lcd.print(1, 0, "World"); 
  
  delay(500);
  lcd.print("Hello", 0, numCols/2-3); 
  lcd.print(1, numCols/2-3, "World"); 

}

void fadeTest() {
  lcd.clear();
  lcd.print("Fade", 0, 6);
  lcd.print("test", 1, 6);
  delay(1000);
  for (int j=0; j<2; j++) {
    for (char i=0; i<100; i += 5) {
      lcd.brightness(i);
      delay(50);
    }
    delay(500);
    for (char i=99; i>=4; i -= 5) {
      lcd.brightness(i);
      delay(50);
    }
  }

  lcd.brightness(100);
}


void flashTest() {
  lcd.clear();
  lcd.print("Flash", 0, 6);
  lcd.print("test", 1, 6);
  delay(1000);

  lcd.clear();
  lcd.print("5 x 500ms", 0, 0);
  lcd.flash(5, 500);

  lcd.clear();
  lcd.print("20 x 100ms", 0, 0);
  lcd.flash(20, 100);
}

void scrollTest() {
  lcd.clear();
  lcd.print("Scroll", 0, 5);
  lcd.print("test", 1, 6);

  delay(1000);

  for (int i=0; i<2; i++) {

    for (int col = 0; col < numCols; col++) {
      lcd.print(">", 0,  col);
      lcd.print("<", 1, numCols - 1 - col);

      delay(500/numCols);
    }
  }
  lcd.vscroll(numCols, 100);
  lcd.vscroll(numCols*-2, 100);
  lcd.vscroll(numCols, 100);
}

void cursorTest() {
  lcd.clear();
  lcd.print("Cursor", 0, 5);
  lcd.print("test", 1, 6);
  lcd.underlineCursorOn();
  cursorRun();
  lcd.blinkCursorOn();
  cursorRun();
  lcd.blinkCursorOff();

}


void cursorRun() {

  lcd.cursor(0,0);
  for (int i=0; i<numCols; i++){
    lcd.cursorRight();
    delay(200);
  }

  lcd.cursor(1,numCols-1);
  for (int i=numCols; i>=0; i--){
    lcd.cursorLeft();
    delay(200);
  }
}  


