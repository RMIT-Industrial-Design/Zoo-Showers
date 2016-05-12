/*
 Hello Tortoise
 by Scott Mitchell, RMIT University
 <scott.mitchell@rmit.edu.au>

 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU LGPL
 as published by the Free Software Foundation.
 
 -------------------------------
 
 This program forms part of a hardware and software system designed
 to provide animal activated showers in Zoo enclosures.
 The system was developed by RMIT University Industrial Design for 
 Zoos Victoria and was initially deployed in the Giant Tortoise 
 enclosure at Melbourne Zoo. HelloTortoise is designed to run in tandem
 with the AnimalShowers Android app however will function as a stand alone
 control system.
 
 This program checks a LIDAR-LITE module for distance
 (the presence of a tortoise or Emu) and turns on a water
 valve for a set period of time if a tortoise/emu is present.
 
 The system goes into low power sleep mode between sensor events and when
 outside the hours of operation (using reference to a RTC).
 
 The sensor trigger threshold (distance to tortoise) can be set via 
 the AnimalShowers app or by using the onboard potentiometer, the software
 will automatically determine which interface to use based on user 
 action.
 
 The Adruino watchdog timer is used to prevent the system from hanging
 and becoming stuck in the on position; if the software becomes 
 unresponsive then the Arduino restarts. Note: the Watchdog Timer requires 
 the optiboot bootloader (if you are using an Arduino Pro Mini you will 
 need to burn optiboot to the Arduino).
 
 The AnimalShowers app communicates with the system using Bluetooth. 
 User Variables are set by sending the following bytes.
 
 Each Data String begins with:
 startByte1 + startByte2 + startByte3 + startByte4 + data type
 data type is either:
 0 to request sensor data
 1 to request user settings or
 2 to set user settings
 A data type of 2 is followed by 16 bytes:
 byte 0: Disable shower off/on: 00 / 01
 byte 1: Disable clock off/on: 00 / 01
 byte 2: Disable Moisture sensor off/on: 00 / 01
 byte 3: Disable temp off/on: 00 / 01
 byte 4: Disable limit off/on: 00 / 01
 byte 5&6: Set shower duration in seconds (60 sec): 00 3C
 byte 7&8: Set sensor threshold (100 cm): 00 64
 byte 9&10: Set time between sensor readings in Millisecs 
   (1000 Millisec): 03 E8
 byte 11: Set start hour (8 o'clock): 08
 byte 12: Set end hour (20 o'clock): 14
 byte 13: Set max moisture for operation (20%): 14
 byte 14: Set min deg C for operation (15 deg): 0F
 byte 15: Set maximum time with shower on (10%): 0A

 Revision History:
 D02
 - published to GitHub
 - generic security bytes
 D01
 - synced version number with Processing
 - START_BYTES sent separately
 - checksum with data bytes only
 - battery voltage calibrated
 C06
 - analog pin added for reading battery voltage
 - analog pin added for reading moisture level
 C05
 - extra byte added to serial communication and user preferences
 - added on/off control for clock, temp sensor and shower limits 
 - added 4 char security code for data transfer
 - added transfer of shower history
 C04
 - added shower limits to User Settings and Bluetooth control
 C03
 - tested OK
 - include sensor threshold in user settings
 - send confirmation bluetooth signal
 - fixed watchdog timer
 C02
 - added bluetooth control
 B11
 - wake during long sleeps to reset watchdog timer
 B10
 - rationalise code in functions
 - reduce night time sleep so watchdog timer isn't triggered
 B09
 - included watchdog timer
 - watchdog timer crashes Arduino Pro Mini.
 - Solution: Burn Pro Mini with Uno optiboot.

*/

const boolean DEBUG = 0;
// Hardware Settings
const byte LED_PIN = 2;
const byte POT_PIN = A3;
const byte POT_GND_PIN = A2; // only used in Emu enclosure at MZ
const byte VALVE_PIN = 3;
const byte LIDAR_POWER_PIN = 7;
const byte VOLTAGE_PIN = A0;
const byte RAIN_PIN = A1;
const byte ONE_WIRE = 4;
const byte BT_TX = 11;
const byte BT_RX = 12;
// TX & RX reversed on MZ emu install
// I2c Bus is on A4 & A5

// Security Bytes. These should match the Processing code
const byte START_BYTES[4] = {'A', 'B', 'C', 'D'};

// battery voltage multiplication factor.
// circuit is a 1:10 ratio voltage divider with 5v reference.
// multiplication factor was determined through experiemntation.
const byte BAT_X_FACTOR = 55;
// Default User Settings
// These are overwritten by User Settings stored in EEPROM
// turn the system on or off. default on.
const boolean SYSTEM_ON_OFF = 1;
// Duration of shower in second intervals. default 60 sec
const unsigned int DEFAULT_SHOWER = 60;
// Time between senses in millisecond intervals. default 1000 millisec
const unsigned int DEFAULT_SLEEP = 1000;
// sleep during the night in seconds. default 10 sec
const unsigned int NIGHT_SLEEP = 10;
// turn the clock on or off. default on.
const boolean CLOCK_ON_OFF = 1;
// Morning start time in hours. default 8 hrs
const byte MORNINGTIME = 8;
// Evening end time in hours. default 20 hrs
const byte EVENINGTIME = 20;
// turn the temp sensor on or off. default on.
const boolean TEMP_ON_OFF = 1;
// Min Temp. default 15 deg C.
const byte MIN_TEMP = 15;
// turn the rain sensor on or off. default on.
const boolean RAIN_ON_OFF = 1;
// Max Rainfall moisture. default 10 %.
const byte MAX_RAIN = 10;
// turn the limit on or off. default on.
const boolean LIMIT_ON_OFF = 1;
// Max % of time the shower is allowed to be ON
const byte MAX_PERCENT_SHOWERS = 10;

// include the watchdog timer library
#include <avr/wdt.h>

// include Wire library for I2C bus
#include <Wire.h>
#define    LIDARLite_ADDRESS   0x62   // Default I2C Address of LIDAR-Lite.
#define    RegisterMeasure     0x00   // Register to write to initiate ranging.
#define    MeasureValue        0x04   // Value to initiate ranging.
#define    RegisterHighLowB    0x8f   // Get both High and Low bytes.

#include "RTClib.h"
RTC_DS1307 RTC;
unsigned long lastClockRead = 0;
// time between clock readings.
// every 5 minutes (300000)
const unsigned long CLOCK_READ_INTERVAL = 300000;

// Serial for bluetooth module
#include <SoftwareSerial.h>
SoftwareSerial BTserial(BT_TX, BT_RX);
// boolean BTconfirm = true;
// const unsigned long BT_TIMEOUT = 3000;

#include <OneWire.h>
// One-Wire device DS18x20 connected on pin 4
OneWire  dsTemp(ONE_WIRE);
byte tempAddr[8];
int tempType_s;
// remember the last time temp data was read
unsigned long lastTempRead = 0;
// time between temperature readings (each reading takes approx 1 sec).
// every 5 minutes (300000)
const unsigned long TEMP_READ_INTERVAL = 300000;

// remember the last time moisture data was read
unsigned long lastRainRead = 0;
// time between moisture readings.
// every 5 minutes (300000)
const unsigned long RAIN_READ_INTERVAL = 300000;

#include <Narcoleptic.h>
// remember sleep time because Narcoleptic.millis() doesn't seem to work
unsigned long NarcMillis = 0;

// for storing user settings
#include <EEPROM.h>

// User settings
// turn the system on or off: 0 = off, 1 = on
boolean systemOnOff;
// Duration of shower in seconds
unsigned int defaultShower;
// pot set sensor threshold
unsigned int potThreshold;
// user set sensor threshold
unsigned int sensorThreshold;
// Time between senses in Millis
unsigned int defaultSleep;
// sleep during the night in seconds
unsigned int nightSleep;
// turn the RTC on or off
boolean clockOnOff;
// Morning start time in hours
byte morningTime;
// Evening end time in hours
byte eveningTime;
// turn the Temp sensor on or off
boolean tempOnOff;
// Min Temp in deg C.
byte minTemp;
// Rain on/off
boolean rainOnOff;
// Max Rain in %.
byte maxRain;
// turn the limit check on or off
boolean limitOnOff;
// max number of showers allowed per NUM_READINGS
byte limitReadings;

// Limit Showers
// remember shower history. 1 reading per defaultShower time.
const int NUM_READINGS = 100;
// max number of concecutive showers allowed
const int LIMIT_CONSEC = 2;
boolean readings[NUM_READINGS];
int index = 0;
int totalOn = 0;
int consecOn = 0;
// remember reading time and check for Millsecond rollover
unsigned long lastMillis = 0;

// Machine State
boolean dayTime = false;
boolean itsHot = false;
boolean itsDry = false;
boolean showerState = false;

// Remember shower times
unsigned long showerStart = 0;
// Remember when LED was switched on
unsigned long LEDstartTime = 0;
// duration of LED on
const byte LED_ON = 200;

void setup(void) {
  // setup serial for debugging
  if (DEBUG) {
    Serial.begin(9600);
    Serial.println("Serial ON");
  }

  // set default user settings
  setDefaultValues();

  // update user settings from EEPROM
  loadUserSettings();

  // setup Bluetooth
  BTserial.begin(9600);
  delay(10);

  // start the watchdog timer to reset the Arduino if it becomes unresponsive
  wdt_enable(WDTO_8S);

  // setup the Arduino pins
  pinMode(LED_PIN, OUTPUT); // setup LED
  digitalWrite(LED_PIN, HIGH); // turn LED on
  LEDstartTime = currentTime();

  pinMode(POT_GND_PIN, OUTPUT); // setup Pot GND
  digitalWrite(POT_GND_PIN, LOW); // activate GND

  pinMode(VALVE_PIN, OUTPUT);   // setup solenoid valve pin
  digitalWrite(VALVE_PIN, LOW); // turn solenoid off

  // setup LIDAR power pin
  pinMode(LIDAR_POWER_PIN, OUTPUT);
  // turn LIDAR on
  LIDARon();

  // initialize all shower readings to 0
  clearShowerReadings();

  // begin Wire I2C
  Wire.begin();

  // begin RTC
  RTC.begin();
  if (DEBUG) Serial.println("RTC ON");
  checkDayTime();

  // setup One-Wire temperature device
  setupTempSensor();
  checkTemp();

  // turn LIDAR off
  LIDARoff();

  if (DEBUG) Serial.println(" ...Setup End");
}


void loop(void) {
  // reset the watchdog timer
  wdt_reset();

  // init variable for shower trigger
  boolean trigger = false;

  // update shower history
  updateShowerReadings(currentTime());

  // turn off shower if shower time is over
  if ((currentTime() - showerStart) > (defaultShower * 1000)) {
    showerOff();
  }

  // check for bluetooth data
  if (BTserial.available()) getSerialData();

  // check for on-off status
  if (systemOnOff) {

    // turn LIDAR on
    LIDARon();

    // check RTC Time
    if (clockOnOff) {
      if ((currentTime() - lastClockRead) > CLOCK_READ_INTERVAL) {
        checkDayTime();
        lastClockRead = currentTime();
      }
    } else {
      dayTime = true;
    }

    // check Temp
    if (tempOnOff) {
      if ((currentTime() - lastTempRead) > TEMP_READ_INTERVAL) {
        checkTemp();
        lastTempRead = currentTime();
      }
    } else {
      itsHot = true;
    }

    // check Moisture
    if (rainOnOff) {
      if ((currentTime() - lastRainRead) > RAIN_READ_INTERVAL) {
        checkRain();
        lastRainRead = currentTime();
      }
    } else {
      itsDry = true;
    }

    // get sensor threshold
    getThreshold();

    // check LIDAR
    int distance = LIDARdistance();

    if (distance < 1) {
      if (DEBUG) Serial.print(" ERROR");
    }
    else {
      // check distance against threshold values
      if (distance < sensorThreshold) {
        trigger = true;
        // turn on the LED
        digitalWrite(LED_PIN, HIGH);
        LEDstartTime = currentTime();
      }
    }

    // if its daytime, no shower, high temp & no rain then trigger shower
    if (dayTime && !showerState && itsHot && itsDry) {
      if (trigger) {
        // if shower limit has not been met then turn on the shower
        if (consecOn < LIMIT_CONSEC) {
          consecOn++;
          if (limitOnOff) {
            if (totalOn < limitReadings) showerOn();
          } else showerOn();
        }
      } else {
        consecOn--;
        if (consecOn < 0) consecOn = 0;
      }
    }

    if (DEBUG) {
      Serial.print(" T: ");
      Serial.print(currentTime());
      Serial.print(" Shower: ");
      Serial.print(showerState);
      Serial.print(" Trig: ");
      Serial.print(trigger);
      Serial.print(" ConsecOn: ");
      Serial.print(consecOn);
      Serial.print(" TotalOn: ");
      Serial.print(totalOn);
    }

    // turn off LED
    if (currentTime() - LEDstartTime > LED_ON) digitalWrite(LED_PIN, LOW);

    // turn LIDAR off
    LIDARoff();
  }

  // sleep time
  sleepUnit();
}


// set default values
void setDefaultValues() {
  // turn the system on or off: 0 = off, 1 = on
  systemOnOff = SYSTEM_ON_OFF;
  // Duration of shower in seconds
  defaultShower = DEFAULT_SHOWER;
  // Time between senses in Millis
  defaultSleep = DEFAULT_SLEEP;
  // sleep during the night in seconds
  nightSleep = NIGHT_SLEEP;
  // turn the clock on
  clockOnOff = CLOCK_ON_OFF;
  // Morning start time in hours
  morningTime = MORNINGTIME;
  // Evening end time in hours
  eveningTime = EVENINGTIME;
  // turn the temp sensor on
  tempOnOff = TEMP_ON_OFF;
  // Min Temp in deg C
  minTemp = MIN_TEMP;
  // turn the rain sensor on
  rainOnOff = RAIN_ON_OFF;
  // Max Rain in %
  maxRain = MAX_RAIN;
  // Max % of shower on
  limitReadings = MAX_PERCENT_SHOWERS;
  // turn the limit on or off. default on.
  limitOnOff = LIMIT_ON_OFF;
  // reset Pot Threshold
  potThreshold = 0;
}


// Load user settings from EEPROM
void loadUserSettings() {
  // check for valid data
  if (EEPROM.read(0) == START_BYTES[0] && EEPROM.read(1) == START_BYTES[1]) {

    if (DEBUG) Serial.println("Loading User Settings");

    // get the system state.
    // saved as 1 or 0
    systemOnOff = EEPROM.read(2);
    if (DEBUG) {
      Serial.print("ON/OFF: ");
      Serial.println(systemOnOff);
    }
    // get the shower duration in seconds
    // saved as second
    defaultShower = combineBytes(EEPROM.read(3), EEPROM.read(4));
    if (DEBUG) {
      Serial.print("Shower Duration: ");
      Serial.print(defaultShower);
      Serial.println(" sec");
    }
    // get the pot threshold setting
    // saved as cm
    potThreshold = combineBytes(EEPROM.read(5), EEPROM.read(6));
    if (DEBUG) {
      Serial.print("Pot Threshold: ");
      Serial.print(potThreshold);
      Serial.println(" cm");
    }
    // get the min sensor threshold
    // saved as cm
    sensorThreshold = combineBytes(EEPROM.read(7), EEPROM.read(8));
    if (DEBUG) {
      Serial.print("Threshold: ");
      Serial.print(sensorThreshold);
      Serial.println(" cm");
    }
    // get the time between sensor readings in Millisec
    // saved as half second intervals
    defaultSleep = combineBytes(EEPROM.read(9), EEPROM.read(10));
    if (DEBUG) {
      Serial.print("Sensor Reading Interval: ");
      Serial.print(defaultSleep);
      Serial.println(" Millisec");
    }
    // get the time between sensor readings at night in seconds
    // saved as seconds
    nightSleep = combineBytes(EEPROM.read(11), EEPROM.read(12));
    if (DEBUG) {
      Serial.print("Night Sensor Interval: ");
      Serial.print(nightSleep);
      Serial.println(" sec");
    }
    // get the clock state.
    // saved as 1 or 0
    clockOnOff = EEPROM.read(13);
    if (DEBUG) {
      Serial.print("Clock ON/OFF: ");
      Serial.println(clockOnOff);
    }
    // get the start hour
    morningTime = EEPROM.read(14);
    if (DEBUG) {
      Serial.print("Start hr: ");
      Serial.print(morningTime);
      Serial.println();
    }
    // get the end hour
    eveningTime = EEPROM.read(15);
    if (DEBUG) {
      Serial.print("End hr: ");
      Serial.print(eveningTime);
      Serial.println();
    }
    // get the temp sensor state.
    // saved as 1 or 0
    tempOnOff = EEPROM.read(16);
    if (DEBUG) {
      Serial.print("Temp ON/OFF: ");
      Serial.println(tempOnOff);
    }
    // get the min temp for operation
    minTemp = EEPROM.read(17);
    if (DEBUG) {
      Serial.print("Min Temp: ");
      Serial.print(minTemp);
      Serial.println(" C");
    }
    // get the rain sensor state.
    // saved as 1 or 0
    rainOnOff = EEPROM.read(18);
    if (DEBUG) {
      Serial.print("Rain ON/OFF: ");
      Serial.println(rainOnOff);
    }
    // get the min temp for operation
    maxRain = EEPROM.read(19);
    if (DEBUG) {
      Serial.print("Max Rain: ");
      Serial.print(maxRain);
      Serial.println(" C");
    }
    // get the shower limit state.
    // saved as 1 or 0
    limitOnOff = EEPROM.read(20);
    if (DEBUG) {
      Serial.print("Shower Limit ON/OFF: ");
      Serial.println(limitOnOff);
    }
    // get the max % shower time on
    limitReadings = EEPROM.read(21);
    if (DEBUG) {
      Serial.print("Shower Limit: ");
      Serial.print(limitReadings);
      Serial.println("%");
    }

    if (DEBUG) Serial.println("End Read.");

  } else {
    if (DEBUG) Serial.println("No User Settings found");
  }
}


// Save user settings to EEPROM
void saveUserSettings() {

  if (DEBUG) Serial.println("Save User Settings");

  // Sign the first two bytes
  EEPROM.write(0, START_BYTES[0]);
  EEPROM.write(1, START_BYTES[1]);
  // save the system state.
  EEPROM.write(2, systemOnOff);
  // save the shower duration as seconds
  EEPROM.write(3, highByte(defaultShower));
  EEPROM.write(4, lowByte(defaultShower));
  // save the sensor trigger threshold
  EEPROM.write(5, highByte(potThreshold));
  EEPROM.write(6, lowByte(potThreshold));
  // save the sensor trigger threshold
  EEPROM.write(7, highByte(sensorThreshold));
  EEPROM.write(8, lowByte(sensorThreshold));
  // save the time between sensor readings as Milliseconds
  EEPROM.write(9, highByte(defaultSleep));
  EEPROM.write(10, lowByte(defaultSleep));
  // save the time between sensor readings at night in seconds
  EEPROM.write(11, highByte(nightSleep));
  EEPROM.write(12, lowByte(nightSleep));
  // save the clock state.
  EEPROM.write(13, clockOnOff);
  // save the start hour
  EEPROM.write(14, morningTime);
  // save the end hour
  EEPROM.write(15, eveningTime);
  // save the temp sensor state.
  EEPROM.write(16, tempOnOff);
  // save the min temp for operation
  EEPROM.write(17, minTemp);
  // save the temp sensor state.
  EEPROM.write(18, rainOnOff);
  // save the min temp for operation
  EEPROM.write(19, maxRain);
  // save the shower limit state.
  EEPROM.write(20, limitOnOff);
  // save the max % shower time on
  EEPROM.write(21, limitReadings);

  if (DEBUG) Serial.println("End EEPROM Write.");

}


// clear the user settings in EEPROM
void clearEEPROM() {
  for ( int i = 0 ; i < 50 ; i++ ) EEPROM.write(i, 0);
  if (DEBUG) Serial.println("EEPROM cleared");
}


// get data from bluetooth serial connection
boolean getSerialData() {

  if (DEBUG) Serial.println("Get Bluetooth");

  // declare byte array big enough for the largest package
  byte packageIn[20];
  byte packageSize;
  byte byte1, byte2, byte3, byte4;

  // check for security code
  if (BTserial.available()) byte1 = BTserial.read();
  if (DEBUG) Serial.println(byte1);
  if (BTserial.available()) byte2 = BTserial.read();
  if (DEBUG) Serial.println(byte2);
  if (BTserial.available()) byte3 = BTserial.read();
  if (DEBUG) Serial.println(byte3);
  if (BTserial.available()) byte4 = BTserial.read();
  if (DEBUG) Serial.println(byte4);

  while (BTserial.available()) {
    if (byte1 == START_BYTES[0] && byte2 == START_BYTES[1]
        && byte3 == START_BYTES[2] && byte4 == START_BYTES[3]) {
      byte sum = 0;
      byte errorCode = 0; // 0 = no errors
      byte dataType = BTserial.read();
      sum ^= dataType;
      switch (dataType) {
        case 0:
          // transmit the sensor data
          packageSize = 3; // 2 bytes of data + checksum
          for (int i = 0; i < packageSize; i++) {
            if (BTserial.available()) {
              packageIn[i] = BTserial.read();
              sum ^= packageIn[i];
            } else errorCode = 101;
          }
          // checksum
          if (sum == 0 && errorCode == 0) postSensorReadings();
          else errorCode = 102; // not used

          break;

        case 1:
          // transmit the user settings
          packageSize = 3; // 2 bytes of data + checksum
          for (int i = 0; i < packageSize; i++) {
            if (BTserial.available()) {
              packageIn[i] = BTserial.read();
              sum ^= packageIn[i];
            } else errorCode = 101;
          }
          // checksum
          if (sum == 0 && errorCode == 0) postUserSettings();
          else errorCode = 102; // not used

          break;

        case 2:
          // set the user settings
          packageSize = 17; // 16 bytes of data + checksum
          for (int i = 0; i < packageSize; i++) {
            if (BTserial.available()) {
              packageIn[i] = BTserial.read();
              sum ^= packageIn[i];
            } else errorCode = 101;
          }
          // checksum
          if (sum == 0 && errorCode == 0) {
            // update user settings
            systemOnOff = boolean(packageIn[0]);
            defaultShower = combineBytes(packageIn[1], packageIn[2]);
            sensorThreshold = combineBytes(packageIn[3], packageIn[4]);
            defaultSleep = combineBytes(packageIn[5], packageIn[6]);
            clockOnOff = boolean(packageIn[7]);
            morningTime = packageIn[8];
            eveningTime = packageIn[9];
            tempOnOff = boolean(packageIn[10]);
            minTemp = packageIn[11];
            rainOnOff = boolean(packageIn[12]);
            maxRain = packageIn[13];
            limitOnOff = boolean(packageIn[14]);
            limitReadings = packageIn[15];

            // save new settings to EEPROM
            saveUserSettings();

          } else errorCode = 102;

          // send confirmation reply to Android
          postReply(errorCode);
          break;
      }

    } else {
      // get the next byte for security code
      byte1 = byte2;
      byte2 = byte3;
      byte3 = byte4;
      byte4 = BTserial.read();
    }
  }

  if (DEBUG) Serial.println("End Get Data");
}


// Post Sensor Readings
void postSensorReadings() {

  // get system time
  // turn LIDAR on (I2C bus wont work if it isn't on)
  LIDARon();
  DateTime now = RTC.now();
  byte theHour = byte(now.hour());
  byte theMin = byte(now.minute());
  // turn LIDAR off
  LIDARoff();
  // get battery voltage as 10 x actual voltage.
  // circuit is a 1:10 ratio voltage divider with 5v reference.
  // multiplication factor was determined through experiemntation.
  byte batteryVoltage = (analogRead(VOLTAGE_PIN) * BAT_X_FACTOR) / 100;
  // get moisture reading
  byte moistureReading = map(analogRead(RAIN_PIN), 0, 1023, 100, 0);
  // get temperature
  byte theTemp = byte(getTemp());
  if (DEBUG) Serial.print("Analog Read V: ");
  if (DEBUG) Serial.println(analogRead(VOLTAGE_PIN));
      if (DEBUG) Serial.print("Voltage: ");
      if (DEBUG) Serial.println(batteryVoltage);
        if (DEBUG) Serial.print("Moisture: ");
          if (DEBUG) Serial.println(moistureReading);

            // construct message
            const byte msgSize = 7;
            byte msgBytes[msgSize];
            // data type 0: send sensor settings
            msgBytes[0] = 0;
            // pack sensor settings
            msgBytes[1] = theHour;
            msgBytes[2] = theMin;
            msgBytes[3] = batteryVoltage;
            msgBytes[4] = moistureReading;
            msgBytes[5] = theTemp;
            // calculate checksum
            byte sum = 0;
            for (int x = 0; x < 6; x++) sum ^= msgBytes[x];
msgBytes[6] = sum;
// send message
// sending an additional start byte improves communication
BTserial.write(START_BYTES[0]);
  for (int b = 0; b < 4; b++) BTserial.write(START_BYTES[b]);
  for (int i = 0; i < msgSize; i++) {
  if (DEBUG) Serial.println(msgBytes[i]);
    BTserial.write(msgBytes[i]);
  }

  if (DEBUG) Serial.println("Sending Sensor Readings");
}


// Post User Settings
void postUserSettings() {
  const byte msgSize = 18;
  byte msgBytes[msgSize];
  // construct message
  // data type 2: Send user settings
  msgBytes[0] = 1;
  // pack user settings
  msgBytes[1] = byte(systemOnOff);
  if (DEBUG) Serial.print("Default Shower: ");
  if (DEBUG) Serial.println(defaultShower);
  msgBytes[2] = highByte(defaultShower);
  msgBytes[3] = lowByte(defaultShower);
  if (DEBUG) Serial.print("Sensor Threshold: ");
  if (DEBUG) Serial.println(sensorThreshold);
  msgBytes[4] = highByte(sensorThreshold);
  msgBytes[5] = lowByte(sensorThreshold);
  if (DEBUG) Serial.print("Default Sleep: ");
  if (DEBUG) Serial.println(defaultSleep);
  msgBytes[6] = highByte(defaultSleep);
  msgBytes[7] = lowByte(defaultSleep);
  msgBytes[8] = byte(clockOnOff);
  msgBytes[9] = morningTime;
  msgBytes[10] = eveningTime;
  msgBytes[11] = byte(tempOnOff);
  msgBytes[12] = minTemp;
  msgBytes[13] = byte(rainOnOff);
  msgBytes[14] = maxRain;
  msgBytes[15] = byte(limitOnOff);
  msgBytes[16] = limitReadings;
  // calculate checksum
  byte sum = 0;
  for (int x = 0; x < 17; x++) sum ^= msgBytes[x];
  msgBytes[17] = sum;
  // send message
  // sending an additional start byte improves communication
  BTserial.write(START_BYTES[0]);
  for (int b = 0; b < 4; b++) BTserial.write(START_BYTES[b]);
  if (DEBUG) Serial.println("User Settings");
  for (int i = 0; i < msgSize; i++) {
    if (DEBUG) Serial.println(msgBytes[i]);
    BTserial.write(msgBytes[i]);
  }

  if (DEBUG) Serial.println("Sending User Settings");

  // wait for transmission to finish
  // BTserial.flush();
}


// Post Confirmation
void postReply(byte _value) {
  const byte msgSize = 3;
  byte msgBytes[msgSize];
  // add data type
  msgBytes[0] = 100;
  // add data
  msgBytes[1] = _value;
  // calculate checksum
  byte sum = 0;
  for (int x = 0; x < 2; x++) sum ^= msgBytes[x];
  msgBytes[2] = sum;
  // send message
  // sending an additional start byte improves communication
  BTserial.write(START_BYTES[0]);
  for (int b = 0; b < 4; b++) BTserial.write(START_BYTES[b]);
  for (int i = 0; i < msgSize; i++) {
    BTserial.write(msgBytes[i]);
  }

  if (DEBUG) {
    Serial.print("Sending Reply :");
    Serial.println(_value, DEC);
  }
}


// combine bytes to form an int
int combineBytes( unsigned char highValue, unsigned char lowValue)
{
  int newValue = highValue;
  // bit shift the high byte into the left most 8 bits
  newValue = newValue << 8;
  // add with logical OR the low byte
  newValue |= lowValue;
  return newValue;
}


// turn LIDAR on
void LIDARon() {
  digitalWrite(LIDAR_POWER_PIN, HIGH);
  // wait for startup
  delay(100);
}


// turn LIDAR off
void LIDARoff() {
  digitalWrite(LIDAR_POWER_PIN, LOW);
}


// get LIDAR distance
int LIDARdistance() {
  int d = 0;

  Wire.beginTransmission((int)LIDARLite_ADDRESS); // transmit to LIDAR-Lite
  Wire.write((uint8_t)RegisterMeasure); // sets register pointer to  (0x00)
  Wire.write((int)MeasureValue); // sets register pointer to  (0x00)
  Wire.endTransmission(); // stop transmitting

  delay(20); // Wait 20ms for transmit

  Wire.beginTransmission((int)LIDARLite_ADDRESS); // transmit to LIDAR-Lite
  Wire.write((int)RegisterHighLowB); // sets register pointer to (0x8f)
  Wire.endTransmission(); // stop transmitting

  delay(20); // Wait 20ms for transmit

  // request 2 bytes from LIDAR-Lite
  Wire.requestFrom((int)LIDARLite_ADDRESS, 2);

  if (2 <= Wire.available()) // if two bytes were received
  {
    d = Wire.read(); // receive high byte (overwrites previous reading)
    d = d << 8; // shift high byte to be high 8 bits
    d |= Wire.read(); // receive low byte as lower 8 bits
  }

  Serial.print(" dist: ");
  Serial.print(d);

  return d;
}


// check trim pot reading
void getThreshold() {
  // check to see if pot has been moved
  // if it has changed then this superceeds the current
  // User Threshold Settings
  // full range of pot is mapped to 510 cm
  unsigned int newPotThreshold = map(analogRead(POT_PIN), 0, 1023, 10, 510);
  if (newPotThreshold < ((int)potThreshold - 10)
      || newPotThreshold > ((int)potThreshold + 10)) {
    potThreshold = newPotThreshold;
    sensorThreshold = potThreshold;
    // Update the User Settings in EEPROM
    saveUserSettings();
  }

  if (DEBUG) {
    Serial.print(" threshold: ");
    Serial.print(sensorThreshold);
  }
}


// clear shower readings
void clearShowerReadings() {
  for (int thisReading = 0; thisReading < NUM_READINGS; thisReading++) {
    readings[thisReading] = false;
  }

  if (DEBUG) Serial.println(" Shower Readings Cleared");
}


// Setup the DS18x20 One-Wire temperature sensor
void setupTempSensor() {
  dsTemp.search(tempAddr);
  delay(250);

  if (DEBUG) {
    Serial.print("ROM =");
    for (int i = 0; i < 8; i++) {
      Serial.write(' ');
      Serial.print(tempAddr[i], HEX);

      if (OneWire::crc8(tempAddr, 7) != tempAddr[7]) {
        Serial.println("CRC is not valid!");
      }
    }
  }

  // the first ROM byte indicates which chip
  switch (tempAddr[0]) {
    case 0x10:
      if (DEBUG) Serial.println(" DS18S20");  // or old DS1820
      tempType_s = 1;
      break;
    case 0x28:
      if (DEBUG) Serial.println(" DS18B20");
      tempType_s = 0;
      break;
    case 0x22:
      if (DEBUG) Serial.println(" DS1822");
      tempType_s = 0;
      break;
    default:
      if (DEBUG) Serial.println("Not a DS18x20 device.");
      tempType_s = -1;
      return;
  }
}

// get temperature from One-Wire sensor
void checkTemp() {
  int theTemp = getTemp();
  if (theTemp < minTemp) itsHot = false;
  else itsHot = true;
}

// get temperature from One-Wire sensor
int getTemp() {
  int celsius;

  if (tempType_s < 0) {
    // no temp sensor found
    celsius = 100;
  } else {
    byte data[12];

    dsTemp.reset();
    dsTemp.select(tempAddr);
    // start conversion, with parasite power on at the end
    dsTemp.write(0x44, 1);

    delay(1000);     // maybe 750ms is enough, maybe not
    // we might do a ds.depower() here, but the reset will take care of it.

    dsTemp.reset();
    dsTemp.select(tempAddr);
    dsTemp.write(0xBE);         // Read Scratchpad

    for (int i = 0; i < 9; i++) {           // we need 9 bytes
      data[i] = dsTemp.read();
    }

    // Convert the data to actual temperature
    // because the result is a 16 bit signed integer, it should
    // be stored to an "int16_t" type, which is always 16 bits
    // even when compiled on a 32 bit processor.
    int16_t raw = (data[1] << 8) | data[0];
    if (tempType_s == 1) {
      raw = raw << 3; // 9 bit resolution default
      if (data[7] == 0x10) {
        // "count remain" gives full 12 bit resolution
        raw = (raw & 0xFFF0) + 12 - data[6];
      }
    } else {
      byte cfg = (data[4] & 0x60);
      // at lower res, the low bits are undefined, so let's zero them
      if (cfg == 0x00) raw = raw & ~7;  // 9 bit resolution, 93.75 ms
      else if (cfg == 0x20) raw = raw & ~3; // 10 bit res, 187.5 ms
      else if (cfg == 0x40) raw = raw & ~1; // 11 bit res, 375 ms
      //// default is 12 bit resolution, 750 ms conversion time
    }
    celsius = raw / 16;
  }

  if (DEBUG) {
    Serial.print(" Temp: ");
    Serial.print(celsius);
    Serial.println(" C");
  }

  return celsius;
}


// get moisture reading
void checkRain() {
  int theRain = map(analogRead(RAIN_PIN), 0, 1024, 100, 0);
  if (theRain > maxRain) itsDry = false;
  else itsDry = true;
}

// get the current time including deep sleep time and rollover check
unsigned long currentTime() {
  unsigned long newTime = millis() + NarcMillis;
  if (newTime < lastMillis) {
    if (DEBUG) Serial.println("Millisec have rolled over");
    // reset all time values
    lastMillis = 0;
    showerStart = 0;
    lastTempRead = 0;
    lastClockRead = 0;
    NarcMillis = 0;
  }

  return newTime;
}


// remember the shower history to limit shower opperation
void updateShowerReadings(unsigned long newTime) {
  if ((newTime - lastMillis) > (defaultShower * 1000)) {
    // remove the oldest reading from the total
    if (readings[index]) totalOn--;
    // add current state to the total
    if (showerState) totalOn++;
    // remember this shower state
    readings[index] = showerState;
    // advance to the next position in the array:
    index++;
    // if we're at the end of the array then wrap the index number
    index = index % NUM_READINGS;
    // remember the reading time
    lastMillis = newTime;
  }
}


// check for daytime opperation
// if RTC is missing then now.hour() returns a large value (assume daytime)
void checkDayTime() {
  // turn LIDAR on (I2C bus wont work if it isn't on)
  LIDARon();

  DateTime now = RTC.now();
  unsigned int currentHour = now.hour();
  if (currentHour >= morningTime && currentHour < eveningTime
      || currentHour > 24) dayTime = true;
  else dayTime = false;

  // turn LIDAR off
  LIDARoff();

  if (DEBUG) {
    Serial.print(" hr: ");
    Serial.print(currentHour);
    Serial.print(" day: ");
    Serial.println(dayTime);
  }
}


void showerOn() {
  if (!showerState) {
    digitalWrite(VALVE_PIN, HIGH);
    if (DEBUG) Serial.print(" Shower On");
    // remember time on
    showerStart = currentTime();
    showerState = true;
  }
}


void showerOff() {
  digitalWrite(VALVE_PIN, LOW);
  if (DEBUG) Serial.print(" Shower Off");
  showerState = false;
}


void sleepUnit() {
  unsigned long duration = defaultSleep;
  if (!dayTime) duration = (long)nightSleep * 1000;

  // remember sleep time
  NarcMillis += duration;

  if (DEBUG) {
    // Serial.print(" sleep: ");
    Serial.println(duration);
    // wait for serial to send
    delay(100);
  }

  // break sleep into 6 sec intervals to keep the watchdog timer running
  while (duration >= 6000) {

    // reset the watchdog timer
    wdt_reset();

    // Low power sleep. During this time power consumption is minimised
    Narcoleptic.delay(6000);
    // wake up
    // wait for system to settle. min 100 millisec
    delay(100);


    // enable the watchdog timer
    wdt_enable(WDTO_8S);

    duration -= 6000;

    // check for serial communication. if true then exit while
    if (getSerialData()) duration = 0;
  }

  // reset the watchdog timer
  wdt_reset();

  // Low power sleep. During this time power consumption is minimised
  Narcoleptic.delay(duration);
  // wake up
  // wait for system to settle
  delay(100);

  // enable the watchdog timer
  wdt_enable(WDTO_8S);
}

