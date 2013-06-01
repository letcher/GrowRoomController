/*
 * GreenRoomController.pde
 *
 * This program keeps track of the current time, date,
 * temperature and humidity. It controls the enviroment
 * using a light, a heater and an exhast fan. The light is
 * turned on and off using the TimeAlarms library along with
 * a DS1307 RTC. Temperature is controlled using maxmimum
 * and minimum thesholds that turn on the designated appliances.
 * The user is given a warning message when the current 
 * humidity is outside the nominal range. A LCD display is used
 * to show the current time, sensor readings and appliance power
 * states. Update messages are sent over the serial port when the
 * a terminal if available. When a SD card is attached 
 * data and events are logged onto CSV files that are 
 * organized like so:'Year/Month/Date/file.csv'
 *
 * Change Log:
 * v1.0 - Original release with temperture control, timed lighting
 * humidity readings and data logging
 *
 * v1.1 - Moved repeated LCD display patterns to funtions,
 * Changed all Strings(except functions) to char arrays, removed
 * LCD Status indicators, Added Humidity Control
 * Now compatable with Arduino Uno and Duemilanove
 * 
 * v1.11 - Fixed bug that causes the system to stop operating
 * controllers, now displays message when unable to connect to
 * the SD card durring startup
 *
 * Copyright 2011 Nickolas K. Grillone
 * Email: Nikg92@gmail.com
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <stdlib.h>
#include <Time.h>
#include <TimeAlarms.h>
#include <Wire.h>
#include <DS1307RTC.h>
#include <SHT1x.h>
#include <SLCD.h>
#include <NewSoftSerial.h>
#include <SD.h>

//Define CS pin for SD card and the ethernet board
#define SD_PIN 4

// Control pins for the light, fan, heater, humidifier & dehumidifier
#define LIGHT_PIN 9
#define FAN_PIN 5
#define HEATER_PIN 6
#define HUMIDIFIER_PIN A0
#define DEHUMIDIFIER_PIN A1

// Serial LCD has 2x16 character display
// **The RX pin from the SLCD display connects to pin 8**
#define numRows 2
#define numCols 16

// Lenths of certain Messages and Strings
#define eventMsgLen 24

// Start the Serial LCD instance
SLCD lcd = SLCD(numRows, numCols);

//LCD Message Delay Time
int lcdDelay = 2000;

// Create Controller Structure, one of these is needed for each appliance
struct Controller
{
  byte pin; //The pin that the relay that controlls the appliance is connected to
  int invert; // 0 - heater, humidifier, etc; 1 - Air Conditioner, dehumifier, etc.
  int turnPoint; //The maximum (minimum if inverted) the sensor reading can be before turning on
  int status; // 0 - off; 1 - on
  char label[16]; // The name of the appliance (ex: Heater)
  char controlLabel[12]; // The reading that is being controlled (ex: Temperature)
};

// Create controller for the Heater, Fan, Humidifier
// and Dehumidifier
Controller Heater;
Controller Fan;
Controller Humidifier;
Controller Dehumidifier;

// String to pass on to controlLabel for Temperature, Humidity and Light
const char tempString[12] = "Temperature";
const char humiString[10] = "Humidity";
const char lightStr[6] = "Light";

// CSV box Seperator
const char boxSeperator[3] = ", ";

// Message strings for powering on and off appliances
const char powerOnMsg[16] = "Powering ON: ";
const char powerOffMsg[16] = "Powering OFF: ";
  
// Variables to store the power state of the light, fan and heater
boolean lightState = false;

// Specify data and clock connections and instantiate SHT1x object
#define dataPin  2
#define clockPin 3
SHT1x sht1x(dataPin, clockPin);

// Variable to store temperature and humidity readings
float temp_f;
float humidity;

// Hours that the light is switched on and off
int LightOnHour = 20;
int LightOffHour = 11;

// Maximum and minimum temperature and humidity
int maxTemp = 75;
int minTemp = 65;
int maxHumi = 75;
int minHumi = 40;

// Previous Date for keeping track of log files
int prevDate = 0;

// File object for the data log file
File dataFile;

// True if SD card was able to initilize
boolean SDavailable = false;

/************************************
 *               Setup              *
 ************************************/
 
void setup()
{  
  // Start the serial port to communicate to the PC at 9600 baud
  Serial.begin(9600);
  
  // Start up the LCD display
  lcd.init();
  lcd.clear();
  lcd.print("Starting up...");
  
  // Get the time from the RTC
  setSyncProvider(RTC.get);
  
  // Report whether the Arduino was able to communicate with the RTC
  if(timeStatus()!= timeSet) 
     Serial.println("Unable to sync with the RTC");
  else
     Serial.println("RTC has set the system time");   
  
  // See if the card is present and can be initialized
  if (!SD.begin(SD_PIN)) {
    Serial.println("SD card failed to initialize");
    lcd.clear();
    lcd.print("SD failed to",0,0);
    lcd.print("initialize",1,0);
  }
  else {
    Serial.println("SD card initialized.");
    SDavailable = true;
  }
  
  // Read values from the sensor
  temp_f = sht1x.readTemperatureF();
  humidity = sht1x.readHumidity();
  
  // Save a reading to the current log file
  LogData();
  
  // Log the time of Startup in the current event Log
  char startMsg[15] = "Device Startup";
  LogEvent(startMsg);
  
  // Create alarms that turn on and off the light
  Alarm.alarmRepeat(LightOnHour,00,0, LightOnAlarm);  // 8:00pm every day
  Alarm.alarmRepeat(LightOffHour,00,0,LightOffAlarm);  // 11:00am every day 
  
  // Update the time displayed on the LCD every 60 seconds
  Alarm.timerRepeat(60, LCDtimeRefresh);
  
  // Set controller variables for Heater
  Heater.pin = HEATER_PIN;
  Heater.invert = 1;
  Heater.turnPoint = minTemp;
  Heater.status = 0;
  strncpy(Heater.label, "Heater", 8);
  strncpy(Heater.controlLabel, tempString, 12);
  
  // Set controller variables for Fan
  Fan.pin = (byte)FAN_PIN;
  Fan.invert = 0;
  Fan.turnPoint = maxTemp;
  Fan.status=0;
  strncpy(Fan.label, "Fan", 12);
  strncpy(Fan.controlLabel, tempString, 12);
  
  //Set controller variables for the Humidifier
  Humidifier.pin = HUMIDIFIER_PIN;
  Humidifier.invert = 1;
  Humidifier.turnPoint = minHumi;
  Humidifier.status=0;
  strncpy(Humidifier.label, "Humidifier", 12);
  strncpy(Humidifier.controlLabel, humiString, 12);
  
  //Set controller variables for Dehumidifier
  Dehumidifier.pin = DEHUMIDIFIER_PIN;
  Dehumidifier.invert = 0;
  Dehumidifier.turnPoint = maxHumi;
  Dehumidifier.status=0;
  strncpy(Dehumidifier.label, "Dehumidifier", 12);
  strncpy(Dehumidifier.controlLabel, humiString, 12);
  
  pinMode(LIGHT_PIN, OUTPUT); // set pin as an output for light control
  pinMode(FAN_PIN, OUTPUT); // set pin as an output for fan control
  pinMode(HEATER_PIN, OUTPUT); // set pin as an output for heater control
  pinMode(HUMIDIFIER_PIN, OUTPUT); // set pin as output for humidifier control
  pinMode(DEHUMIDIFIER_PIN, OUTPUT); // set pin as output for dehumidifier control
  
  pinMode(SD_PIN, OUTPUT); // set chip seldect pin as an output
  
  // If the light is supposed to be on turn it on
  if(hour()<LightOffHour || hour()>=LightOnHour)
  {
    digitalWrite(LIGHT_PIN, HIGH);
    lightState = true;
  }
  
  // Update LCD Screen
  LCDrefresh();
}

/*********************************
 *             Loop              *
 *********************************/

void loop()
{ 
  while(second()%10==0)
  {
    // Display message over Serial
  Serial.println("Taking Sensor Readings");
  
  // Read values from the sensor
  temp_f = sht1x.readTemperatureF();
  humidity = sht1x.readHumidity();

  // Print the temperature and humidity readings over the serial port
  Serial.print("Temperature: ");
  Serial.print(temp_f, DEC);
  Serial.print("F. Humidity: ");
  Serial.print(humidity);
  Serial.println("%");
  
  // Check whether the temperature or humidity have passed
  // their turn point. If so turn on the required appliance.
  CheckController(temp_f, Heater);
  CheckController(temp_f, Fan);
  CheckController(humidity, Humidifier);
  CheckController(humidity, Dehumidifier);
  
  // Write Data Entry to SD Card
  LogData();
  
  // Refresh the sensor reading indicators on the LCD screen
  LCDsensorRefresh();
  }
  
  Alarm.delay(100); // wait one second between clock display
}

/*************************************
 *        Light Control Alarms       *
 *************************************/
 
void LightOffAlarm()
{
  // Turn off the light, update lightStatus, report the change
  // over Serial, in the current eventLog and on the LCD screen
  char msg[24];
  strncpy(msg, powerOffMsg, 24);
  strcat(msg, lightStr);
  
  digitalWrite(LIGHT_PIN, LOW);
  lightState = false;
  
  lcd.clear();
  lcd.print(powerOffMsg,0,0);
  lcd.print(lightStr,1,0);
  
  Serial.println(msg);
  
  LogEvent(msg);
    
  Alarm.delay(lcdDelay);
  LCDrefresh();
}

void LightOnAlarm()
{
  // Turn on the light, update lightStatus, report the change
  // over Serial, in the current eventLog and on the LCD screen
  char msg[24];
  strncpy(msg, powerOnMsg, 24);
  strcat(msg, lightStr);
  
  digitalWrite(LIGHT_PIN, HIGH);
  lightState = true;
  
  lcd.clear();
  lcd.print(powerOnMsg,0,0);
  lcd.print(lightStr,1,0);
  
  Serial.println(msg);  
  
  LogEvent(msg);
  
  Alarm.delay(lcdDelay);  
  LCDrefresh();
}

void CheckController(int sensorReading, struct Controller &c)
{
  
  // If inverted, check if sensorReading is below the turn point
  if(c.invert)
  {
    if(sensorReading<=c.turnPoint)
    {
      // Report that sensorReading is below the turnpoint
      Serial.print(c.controlLabel);
      Serial.println(" is BELOW nominal range");
      
      // If the appliance is powered off turn it on, update 
      // the controller status and report it over serial
      if(c.status==0)
      {
        // Display "Powering ON: 'LABEL'" on LCD screen
        lcd.clear();
        lcd.print(powerOnMsg,0,0);
        lcd.print(c.label,1,0);
        
        // Set appliance control pin to HIGH
        digitalWrite(c.pin, HIGH);
        c.status=1;
        
        // Log event on SD card
        char event[eventMsgLen];
        strncpy(event, powerOnMsg, eventMsgLen);
        strcat(event, c.label);
        LogEvent(event);
        
        // Display "Powering ON: 'LABEL'" over Serial
        Serial.print(powerOnMsg);
        Serial.println(c.label);
        Alarm.delay(lcdDelay);
        LCDrefresh();
      }
      // Else, report that it is already powered on
      else
      {
        Serial.print(c.label);
        Serial.println(" is powered ON");
      }
    }
    else
    {
      // If the sensorReading is not below the turn point power
      // the appliance off if needed, update the controller status
      // and report it over serial
      if(c.status==1 && sensorReading >= (c.turnPoint+5))
      {
        // Display "Powering OFF: 'LABEL'" on LCD screen
        lcd.clear();
        lcd.print(powerOffMsg,0,0);
        lcd.print(c.label,1,0);
        
        // Set appliance control pin to LOW
        digitalWrite(c.pin, LOW);
        c.status=0;
        
        // Log event on SD card
        char event[eventMsgLen];
        strncpy(event, powerOffMsg, eventMsgLen);
        strcat(event, c.label);
        LogEvent(event);
        
        // Display "Powering OFF: 'LABEL'" over Serial
        Serial.print(powerOffMsg);
        Serial.println(c.label);
        Alarm.delay(lcdDelay);
        LCDrefresh();
      }
      else
      {
      // Else, report that it is already powered off 
        Serial.print(c.label);
        Serial.println(" is powered OFF");
      }
    }
  }
  
  //if not inverted...
  else
  {
  // If inverted, check if sensorReading is above the turn point
    if(sensorReading>=c.turnPoint)
    {
      // Report that sensorReading is above the turnpoint
      Serial.print(c.controlLabel);
      Serial.println(" is ABOVE nominal range");
      
      // If the appliance is powered off turn it on, update 
      // the controller status and report it over serial
      if(c.status==0)
      {
        // Display "Powering ON: 'LABEL'" on LCD screen
        lcd.clear();
        lcd.print(powerOnMsg,0,0);
        lcd.print(c.label,1,0);
        
        // Set appliance control pin to HIGH
        digitalWrite(c.pin, HIGH);
        c.status=1;
        
        // Log event on SD card
        char event[eventMsgLen];
        strncpy(event, powerOnMsg, eventMsgLen);
        strcat(event, c.label);
        LogEvent(event);
        
        // Display "Powering ON: 'LABEL'" over Serial
        Serial.print(powerOnMsg);
        Serial.println(c.label);
        Alarm.delay(lcdDelay);
        LCDrefresh();
      }
      // Else, report that it is already powered on
      else
      {
        Serial.print(c.label);
        Serial.println(" is powered ON");
      }
    }
    // If the sensorReading is not below the turn point power
    // the appliance off if needed, update the controller status
    // and report it over serial
    else
    {
      if(c.status==1 && sensorReading <= (c.turnPoint-5))
      {
        // Display "Powering OFF: 'LABEL'" on LCD screen
        lcd.clear();
        lcd.print(powerOffMsg,0,0);
        lcd.print(c.label,1,0);
        
        // Set appliance control pin to LOW
        digitalWrite(c.pin, LOW);
        c.status=0;
        
        // Log event on SD card
        char event[eventMsgLen];
        strncpy(event, powerOffMsg, eventMsgLen);
        strcat(event, c.label);
        LogEvent(event);
        
        // Display "Powering OFF: 'LABEL'" over Serial
        Serial.print(powerOffMsg);
        Serial.println(c.label);
        Alarm.delay(lcdDelay);
        LCDrefresh();
      }
      
      // Else, report that it is already powered off
      else
      {
        Serial.print(c.label);
        Serial.println(" is powered OFF");
      }
    }
  }
}

void printDigits(int digits)
{
  // utility function for digital clock display: prints preceding colon and leading 0
  Serial.print(":");
  if(digits < 10)
    Serial.print('0');
  Serial.print(digits);
}

 void printDigitsDate(int digits)
{
  // utility function for digital clock display: prints preceding ":" and leading 0
  Serial.print("/");
  if(digits < 10)
    Serial.print('0');
  Serial.print(digits);
}

void LCDsensorRefresh()
{
  // Create a small buffer for itoa fuction
  char buf[3];
  
  // Clear the bottom line of the LCD screen
  lcd.print("                ",1,0);
  
  // If temperature reading is more or equal to 100,
  // display the characters one space to the right to
  // fit the reading, should look like this:
  // T:1XXF RH:XX% X
  if(temp_f>=100)
  {
    lcd.print("T:1",1,0);
    LcdPrintInt(temp_f,1,3);
    lcd.print("F",1,5);
    
    lcd.print("RH:",1,8);
    LcdPrintInt(humidity,1,11);
    lcd.print("%",1,13);
  }
  
  // If temperature reading is not more or equal to 100,
  // display the characters to fit the reading
  // it should look like this:
  // T:XXF RH:XX% X
  else
  {
    lcd.print("T:",1,0);
    LcdPrintInt(temp_f,1,2);
    lcd.print("F",1,4);
    
    lcd.print("RH:",1,7);
    LcdPrintInt(humidity,1,10);
    lcd.print("%",1,12);
  }
}

void LcdPrintInt(float num, int row, int col)
{
  // Convert a float between 0-99 to an int and display
  // it to a designated LCD segment
  char buf[3];
  lcd.print(itoa(((int)num/10),buf,10),row,col);
  lcd.print(itoa(((int)num%10),buf,10),row,col+1);
}


void LCDtimeRefresh() {
  // Get the current hour and minute
  int displayHour = hour();
  int displayMinute = minute();
  // PM indicator, 0-AM ; 1-PM
  int PM = 0;
  // Create a small buffer for itoa function
  char buf[3];
 
  // If it is past noon, it is PM and subtract 12 from the display hour
  if(displayHour>12)
  {
    PM = 1; 
    displayHour = displayHour-12;
  }
  
  // if it is midnight display 12 as the display hour and it is AM
  if(displayHour==0)
  {
    displayHour=12;
    PM = 0;
  }
  
  // If it is noon it is PM
  if(hour()==12) PM=1;
  
  // Clear the section of the LCD that displays the time
  lcd.print("       ",0,0);
  
  // If displayHour is more or equal to 10, format the time on
  // the screen to fit the extra integer, Exaple: "HH:MMXM" where XM= AM/PM
  if(displayHour<=10)
  {
    lcd.print(itoa(displayHour,buf,10),0,0);
    lcd.print(":",0,1);
    
    LcdPrintInt(displayMinute,0,2);
    
    LcdPrintAMPM(PM, 0, 4);
  }
  
  // If displayHour is not more or equal to 10, display the time
  // accordingly, Example: "H:MMXM" where XM = AM/PM
  else
  {
    LcdPrintInt(displayHour,0,0);
    lcd.print(":",0,2);
    LcdPrintInt(displayMinute,0,3);
   
    LcdPrintAMPM(PM,0,5);
  }
}

void LcdPrintAMPM(boolean PM, int row, int col)
{
  // If PM is true, display "P" else display "A"
  if(PM==1)
  {
    lcd.print("P",row,col);
  }
  
  else
  {
    lcd.print("A",row,col);
  }
    
  lcd.print("M",row,col+1);
}

void LCDrefresh()
{
  // Clear the LCD and refresh all indicators
  lcd.clear();
  LCDtimeRefresh();
  LCDsensorRefresh();
}

/***********************************
 *      Data Logging Fuctions      *
 ***********************************/
 
String CurrentDirectory()
{
  // This function returns the current date's direcory
  char dirString[12];
  char buf[6];
  const char devider[2] = "/";
  
  // Assemble the directory string
  strncpy(dirString, itoa(year(),buf,10), 12);
  strcat(dirString, devider);
  strcat(dirString, itoa(month(),buf,10));
  strcat(dirString, devider);
  strcat(dirString, itoa(day(),buf,10));
  strcat(dirString, devider);
  Serial.print("Current Logging Directory: ");
  Serial.println(dirString);
  
  return dirString;
}
 
File OpenCurrentLog()
{
  // If the SD card is not present report it over serial and do nothing
  if (!SDavailable) {
    Serial.println("SD card failed to initialize");
  }
  else {
  // Create String and buffer for the file string
  String dirStr = CurrentDirectory();
  char dirString[32];
  dirStr.toCharArray(dirString,32);
  char fileString[32];
  char header[32] = "Time, Temperature(F), Humidity";
  
  //If any branch off the directory don't exist create it or them
  if(!SD.exists(dirString))
  {
    Serial.print(dirString);
    Serial.println(" does not exist");
    Serial.print("Creating: ");
    Serial.println(dirString);
    SD.mkdir(dirString);
  }
  else
  {
    // If it already exist report so over the Serial port
    Serial.print(dirString);
    Serial.println(" exists");
  }
  
  // Assemble the file string
  strncpy(fileString, dirString, 32);
  strcat(fileString, "datalog.csv");
  Serial.print("Current Logging File: ");
  Serial.println(fileString);
  
  //Open or Create the log file
  File logFile = SD.open(fileString, FILE_WRITE);
  
  //Check if header is already present, if not write it
  CheckFileHeader(logFile, header, fileString);
  
  // Return the logFile object
  return logFile;
  }
}

void LogData()
{
  // If the SD card is not present report it over serial and do nothing
  if (!SDavailable) {
    Serial.println("SD card failed to initialize");
  }
  else
  {
    // If the day has changed report so over Serial, close the old file
    // and open a new DataLog the current dates directory
    if(prevDate != day())
    {
      Serial.println("The Date has Changed");
      Serial.println("Opening New Log File");
      dataFile.close();
      dataFile = OpenCurrentLog();
      prevDate = day();
    }
  
    Serial.println("Preparing Data Entry...");
  
    // Get current temperature and humidity
    int temp = int(temp_f);
    int humid = int(humidity);
  
    // Log Date Entry Ex: "HH:MM:SS, TT, RH"
    PrintTimeSD(dataFile);
    dataFile.print(temp_f);
    dataFile.print(boxSeperator);
    dataFile.println(humidity);
    
    //Display the data entry over serial
    Serial.print("Data Entry: ");
    Serial.print(hour());
    printDigits(minute());
    printDigits(second());
    Serial.print(boxSeperator);
    Serial.print(temp_f);
    Serial.print(boxSeperator);
    Serial.println(humidity);
  }
}

void LogEvent(char *msg)
{
  char fileString[32];
  String fileStr = CurrentDirectory();
  fileStr.toCharArray(fileString,32);
  char header[12] = "Time,Event"; //header for the file
  strcat(fileString, "eventlog.csv"); // assemble the file string
  
  // Close the dataLog and open the eventLog file
  dataFile.close();
  File eventFile = SD.open(fileString, FILE_WRITE);
  
  // If the header has not been placed yet write it to the file
  CheckFileHeader(eventFile, header, fileString);
  
  // Print the message as follows: "HH:MM:SS, 'MESSAGE'"
  PrintTimeSD(eventFile);
  eventFile.println(msg);
  
  //close the eventLog
  eventFile.close();
  
  // Reopen the dataLog
  dataFile = OpenCurrentLog();
}

void CheckFileHeader(File &logFile, char header[], char fileString[])
{
  // If this is a new file write the header at the top
  if(logFile) {
    if(logFile.size() == 0)
    {
      logFile.println(header);
      Serial.println("New File Detected, Writing Header");
    }
    // If log file already exists display the size and
    // begin writing to the end of the file
    else
    {
      char fileSize[32];
      itoa(logFile.size(), fileSize, 10);
      
      logFile.seek(logFile.size());
      Serial.print(fileString);
      Serial.print(" size: ");
      Serial.println(fileSize);
      Serial.println("Writing to end of the file");
    }
  }
    
  // If the file is unavailable report it over serial
  else {
    Serial.print("Error opening: ");
    Serial.println(fileString);
  }
}

void PrintTimeSD(File &file)
{
    // Print the current time of the day as follows to the current File:
    // "HH:MM:SS, "
    file.print(hour());
    printDigitsSD(minute(), file);
    printDigitsSD(second(), file);
    file.print(boxSeperator);
}
void printDigitsSD(int digits, File &file)
{
  // function for digital clock display: prints preceding colon and leading 0
  file.print(":");
  if(digits < 10)
    file.print('0');
  file.print(digits);
}
