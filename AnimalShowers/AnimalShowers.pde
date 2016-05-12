/*
 Animal Showers
 by Scott Mitchell, RMIT University
 <scott.mitchell@rmit.edu.au>
 
 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU LGPL
 as published by the Free Software Foundation.
 
 -------------------------------
 
 This program communicates with a sensor device running 'HelloTortoise.ino'
 - a software and hardware system designed for animal activated showers.
 The system was developed by RMIT University Industrial Design
 for Zoos Victoria and was initially deployed in the Giant Tortoise enclosure
 at Melbourne Zoo.
 
 Functions include:
 - Modify Shower Settings
 - Disable Clock
 - Disable Temperature Reading
 - Disable Rain Sensor
 - Display Recent Shower Activity
 
 Serial communication is established via bluetooth. User Variables are set
 by sending the following bytes:
 
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
 byte 9&10: Set time between sensor readings in Millisecs (1000 Millisec): 03 E8
 byte 11: Set start hour (8 o'clock): 08
 byte 12: Set end hour (20 o'clock): 14
 byte 13: Set max moisture for operation (20%): 14
 byte 14: Set min deg C for operation (15 deg): 0F
 byte 15: Set maximum time with shower on (10%): 0A
 
 Revision History:
 D06 . 06/03/16
 - published to GitHub
 - generic security bytes
 D05 . 14/02/16
 - added scaled GUI for different sized screens
 D04 . 08/02/16
 - fully functional
 - added bluetooth port control
 D03 . 07/02/16
 - fully functional
 - removed byte copy to array
 D02
 - simplify Arduino bluetooth communication
 D01
 - synced version number with Arduino
 - START_BYTES sent separately
 - checksum with data bytes only
 A08
 - Bluetooth communication alternate method
 A07
 - Bluetooth communication using array[]
 A06
 - Bluetooth communication with shower controller
 A05
 - Separate code into tabs
 - toggles disable sliders (functional)
 A04
 - added bluetooth control from Milky Pigs
 A03
 - removed "on/off" labels from toggles
 - toggles disable sliders (not fully functional)
 
 
 */

// access to Arduino UI
import ketai.ui.*;

// Security Bytes. These should match the Processing code
static final byte[] START_BYTES = {'A', 'B', 'C', 'D'};

// Default User Settings
// These are overwritten by User Settings stored in EEPROM
// turn the system on or off. default on.
static final boolean SYSTEM_ON_OFF = true;
// Duration of shower in second intervals. default 60 sec
static final int DEFAULT_SHOWER = 60;
// Trigger distance in cm.
static final int SENSOR_THRESHOLD = 150;
// Time between senses in second intervals. default 1.0 seconds
static final float DEFAULT_SLEEP = 1.0;
// sleep during the night in seconds. default 10 seconds
// static final float NIGHT_SLEEP = 10.0;
// turn the clock on or off. default on.
static final boolean CLOCK_ON_OFF = true;
// Morning start time in hours. default 8 hrs
static final int MORNINGTIME = 8;
// Evening end time in hours. default 20 hrs
static final int EVENINGTIME = 20;
// turn the temp sensor on or off. default on.
static final boolean TEMP_ON_OFF = true;
// Min Temp. default 15 deg C.
static final int MIN_TEMP = 15;
// turn the rain sensor on or off. default on.
static final boolean RAIN_ON_OFF = true;
// Max Rainfall moisture. default 10 %.
static final int MAX_RAIN = 10;
// turn the limit on or off. default on.
static final boolean LIMIT_ON_OFF = true;
// Max % of time the shower is allowed to be ON
static final int MAX_PERCENT_SHOWERS = 10;

// Shower settings
// processing uses signed bytes, Arduino uses unsigned bytes
// store settings as integers and convert to bytes when sending
// system on or off: 0 = off, 1 = on
boolean systemOnOff;
// Duration of shower in seconds
int defaultShower;
// user set sensor threshold
int sensorThreshold;
// Time between senses in seconds
float defaultSleep;
// sleep during the night in seconds
// float night_sleep;
// Clock on/off
boolean clockOnOff;
// Morning start time in hours
int morningTime;
// Evening end time in hours
int eveningTime;
// Temp on/off
boolean tempOnOff;
// Min Temp in deg C.
int minTemp;
// Rain on/off
boolean rainOnOff;
// Max Rain in %.
int maxRain;
// Limit on/off
boolean limitOnOff;
// max number of showers allowed per numReadings
int limitReadings;
// Device system time
// String systemTime;
int unixSystemTime;

// Define Bluetooth connection
ArduinoMessenger messenger;
// int BTinterval = 1000;
// int BTprocess = 0;
int BTportStartTime = 0;
int BTsensorStartTime = 0;
int BTsendStartTime = 0;
int BTgetStartTime = 0;
boolean BTportWaiting = false;
boolean BTsensorWaiting = false;
boolean BTsendWaiting = false;
boolean BTgetWaiting = false;
static final int BT_TIMEOUT = 3000;
static final int BT_CONNECTION_TIMEOUT = 20000;
static final int BT_INTERVAL = 5000;

void setup() {
  println("Starting Setup");
  // Construct and set up the Arduino instance for communicating
  // Start with a device named "HC-05" - a common Bluetooth device.
  messenger = new ArduinoMessenger(this, "HC-05");

  // Load defaults before and after setting up GUI to avoid '100' limit bug
  // documented here: https://code.google.com/archive/p/controlp5/issues/82
  loadDefaultSettings();
  // setup the GUI
  setupGUI();

  if (messenger.isConnected()) {
    // get the devices current settings
    getSettings();
  } else {
    // Load default settings
    loadDefaultSettings();
  }

  // update the GUI with new settings
  updateGUI();
}


void draw() {
  //Set background to black
  background(0); 

  // check to see if port selection has timed out
  if (BTportWaiting && millis() - BTportStartTime > BT_CONNECTION_TIMEOUT) {
    BTportWaiting = false;
    if (!messenger.isConnected()) KetaiAlertDialog.popup(this, 
      "Bluetooth Error", "Could not connect to selected port.");
  }
  // get the sensor data
  if (millis() - BTsensorStartTime > BT_INTERVAL) {
    if (BTsensorWaiting) {
      BTsensorWaiting = false;
      updateSensorDisplay(false);
    }
    getSensorReadings();
  }
  // check to see if send data request has timed out
  if (BTsendWaiting && millis() - BTsendStartTime > BT_TIMEOUT) {
    BTsendWaiting = false;
    KetaiAlertDialog.popup(this, "Data Transfer Error", 
      "Data could not be sent.");
  }
  // check to see if get data request has timed out
  if (BTgetWaiting && millis() - BTgetStartTime > BT_TIMEOUT) {
    BTgetWaiting = false;
    KetaiAlertDialog.popup(this, "Data Transfer Error", 
      "Current settings could not be retrieved.");
  }

  // Maintain the connection with the target device
  if (messenger.maintainConnection()) {
    // set bluetooth indicator to green
    bluetooth.setImage(BTimages[1]);
  } else {
    // set bluetooth indicator to red
    bluetooth.setImage(BTimages[0]);
  }
}


// This gets called whenever the app receives some bluetooth event.
// This will only get called for as long as `messenger` lives.
void onBluetoothDataEvent(String who, byte[] data) { 
  // Check that the event is from our arduino.
  if (who.equals(messenger.arduinoAddress)) {
    println(data.length + " bytes coming from the Arduino");
    for (int i = 0; i < (data.length - 4); i++) {
      if (data[i] == START_BYTES[0] && data[i+1] == START_BYTES[1] &&
        data[i+2] == START_BYTES[2] && data[i+3] == START_BYTES[3]) {
        // we have valid data
        println("Start Bytes Collected");
        i += 4;
        int packageSize;
        // start checksum
        byte sum = 0;
        println("Data Type: " + data[i]);
        switch(data[i]) {
        case 0: 
          println("New Sensor Data");
          // update sensor data
          packageSize = 6;
          if (data.length - i > packageSize) {
            // checksum
            for (int x = i; x <= i+packageSize; x++) sum ^= data[x];
            if (sum == 0) {
              // data is good
              // send data to function
              updateSensorData(subset(data, i+1, packageSize));
              i += packageSize;
            }
          }
          break;
        case 1: 
          println("New User Settings");
          // update user settings
          packageSize = 17;
          if (data.length - i > packageSize) {
            // checksum
            for (int x = i; x <= i+packageSize; x++) sum ^= data[x];
            if (sum == 0) {
              // data is good
              // send data to function
              updateUserSettings(subset(data, i+1, packageSize));
              i += packageSize;
            }
          }
          break;
        case 100: 
          println("Confirmation Message");
          // confirmation of user settings updated
          packageSize = 2;
          if (data.length - i > packageSize) {
            // checksum
            for (int x = i; x <= i+packageSize; x++) sum ^= data[x];
            if (sum == 0) {
              // data is good
              if (data[i+1] == 0) {
                KetaiAlertDialog.popup(this, 
                  "Data Transfer", "New settings have been sent to the sensor.");
              } else KetaiAlertDialog.popup(this, 
                "Data Transfer Error", "Data could not be read by sensor.");
              i += packageSize;
              BTsendWaiting = false;
            }
          }
          break;
        }
      }
    }
  }
}


// Update the sensor readings
void updateSensorData(byte[] _newData) {
  // processing uses signed bytes, Arduino uses unsigned bytes
  // convert signed bytes to unsigned integers
  updateSensorDisplay(_newData[0] & 0xFF, _newData[1] & 0xFF, 
    _newData[2] & 0xFF, _newData[3] & 0xFF, _newData[4] & 0xFF);
  BTsensorWaiting = false;
}


// Load user settings
void updateUserSettings(byte[] _newData) {
  // processing uses signed bytes, Arduino uses unsigned bytes
  // convert signed bytes to unsigned integers
  println(_newData.length + "bytes");
  // update settings
  systemOnOff = boolean(_newData[0]);
  defaultShower = combineBytes(_newData[1] & 0xFF, _newData[2] & 0xFF);
  println("Default Shower: " + defaultShower);
  sensorThreshold = combineBytes(_newData[3] & 0xFF, _newData[4] & 0xFF);
  println("Sensor Threshold: " + sensorThreshold);
  defaultSleep = ((float)combineBytes(_newData[5] & 0xFF, 
    _newData[6] & 0xFF))/1000;
  println("Default Sleep: " + defaultSleep);
  clockOnOff = boolean(_newData[7]);
  morningTime = _newData[8] & 0xFF;
  eveningTime = _newData[9] & 0xFF;
  tempOnOff = boolean(_newData[10]);
  minTemp = _newData[11] & 0xFF;
  rainOnOff = boolean(_newData[12]);
  maxRain = _newData[13] & 0xFF;
  limitOnOff = boolean(_newData[14]);
  limitReadings = _newData[15] & 0xFF;
  // update the GUI with new settings
  updateGUI();
  BTgetWaiting = false;
  KetaiAlertDialog.popup(this, "Data Transfer", 
    "Current settings have been retrieved from the sensor.");
}


// Get the system sensor readings via bluetooth
void getSensorReadings() {
  if (messenger.isConnected()) {
    byte[] msgBytes = new byte[4];
    // construct message
    msgBytes[0] = 0;
    msgBytes[1] = 0; // these bytes arent used
    msgBytes[2] = 0; // these bytes arent used
    // calculate checksum
    byte sum = 0;
    for (int x = 0; x < 3; x++) sum ^= msgBytes[x];
    msgBytes[3] = sum;
    // send message
    // send start bytes twice because they tend to get missed on the Arduino
    messenger.sendBytes(START_BYTES);
    messenger.sendBytes(START_BYTES);
    messenger.sendBytes(msgBytes);
  }
  BTsensorStartTime = millis();
  BTsensorWaiting = true;
}


// Get the current settings via bluetooth
void getSettings() {
  if (messenger.isConnected()) {
    byte[] msgBytes = new byte[4];
    // construct message
    println("get settings");
    msgBytes[0] = 1;
    msgBytes[1] = 0; // these bytes arent used
    msgBytes[2] = 0; // these bytes arent used
    // calculate checksum
    byte sum = 0;
    for (int x = 0; x < 3; x++) sum ^= msgBytes[x];
    msgBytes[3] = sum;
    // send message
    // send start bytes twice because they tend to get missed on the Arduino
    messenger.sendBytes(START_BYTES);
    messenger.sendBytes(START_BYTES);
    messenger.sendBytes(msgBytes);
    BTgetStartTime = millis();
    BTgetWaiting = true;
  } else {
    KetaiAlertDialog.popup(this, 
      "Data Transfer Error", "Bluetooth is not connected.");
  }
}


void sendSettings() {
  // processing uses signed bytes, Arduino uses unsigned bytes
  // convert integers to bytes before sending
  if (messenger.isConnected()) {
    byte[] msgBytes = new byte[18];
    // construct message
    // data type 2: Set user settings
    msgBytes[0] = 2;
    // pack user settings
    msgBytes[1] = byte(systemOnOff);
    msgBytes[2] = highByte(defaultShower);
    msgBytes[3] = lowByte(defaultShower);
    msgBytes[4] = highByte(sensorThreshold);
    msgBytes[5] = lowByte(sensorThreshold);
    int sleepMillis = (int)defaultSleep * 1000;
    msgBytes[6] = highByte(sleepMillis);
    msgBytes[7] = lowByte(sleepMillis);
    msgBytes[8] = byte(clockOnOff);
    msgBytes[9] = byte(morningTime);
    msgBytes[10] = (byte)eveningTime;
    msgBytes[11] = byte(tempOnOff);
    msgBytes[12] = (byte)minTemp;
    msgBytes[13] = byte(rainOnOff);
    msgBytes[14] = (byte)maxRain;
    msgBytes[15] = byte(limitOnOff);
    msgBytes[16] = (byte)limitReadings;
    // calculate checksum
    byte sum = 0;
    for (int x = 0; x < 17; x++) sum ^= msgBytes[x];
    msgBytes[17] = sum;
    // send message
    // send start bytes twice because they tend to get missed on the Arduino
    messenger.sendBytes(START_BYTES);
    messenger.sendBytes(START_BYTES);
    messenger.sendBytes(msgBytes);
    BTsendStartTime = millis();
    BTsendWaiting = true;
  } else {
    KetaiAlertDialog.popup(this, 
      "Data Transfer Error", "Bluetooth is not connected.");
  }
}


// combine bytes to form an int
int combineBytes(int highValue, int lowValue)
{
  // bit shift the high byte into the left most 8 bits
  int newValue = (highValue << 8 | lowValue);
  return newValue;
}

// return high byte from an int
byte highByte(int _value)
{
  // bit shift the high byte into the left most 8 bits
  byte highValue = byte((_value >>> 8 & 0xff));
  return highValue;
}

// return low byte from an int
byte lowByte(int _value)
{
  // bit shift the high byte into the left most 8 bits
  byte lowValue = byte(_value & 0xff);
  return lowValue;
}


// Load default settings
void loadDefaultSettings() {
  systemOnOff = SYSTEM_ON_OFF;
  defaultShower = DEFAULT_SHOWER;
  sensorThreshold = SENSOR_THRESHOLD;
  defaultSleep = DEFAULT_SLEEP;
  // night_sleep = NIGHT_SLEEP;
  clockOnOff = CLOCK_ON_OFF;
  morningTime = MORNINGTIME;
  eveningTime = EVENINGTIME;
  tempOnOff = TEMP_ON_OFF;
  minTemp = MIN_TEMP;
  rainOnOff = RAIN_ON_OFF;
  maxRain = MAX_RAIN;
  limitOnOff = LIMIT_ON_OFF;
  limitReadings = MAX_PERCENT_SHOWERS;
}