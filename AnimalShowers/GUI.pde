// GUI controls
import controlP5.*;
import java.util.*;

ControlP5 cp5;

// about messeage
static final String aboutMessage = "Animal Showers is a Zoos Victoria " +
  "project in collaboration with RMIT University.\n \n" + 
  "This software was originally designed for keepers at Melbourne Zoo, Healesville Sanctuary " +
  "and Werribee Open Range Zoo.\n \n" +
  "Code and electronics for the Animal Showers project are available " +
  "under an open source license. Original code and circuit design " +
  "by Scott Mitchell, School of Architecture + Design, RMIT University.";

// initialize GUI items
controlP5.Button aboutButton;
Textlabel textHeader;
controlP5.Button bluetooth;
controlP5.ScrollableList ports;
Textlabel timeLabel;
Textlabel voltageLabel;
Textlabel moistureLabel;
Textlabel tempLabel;
controlP5.Toggle onOffToggle;
controlP5.Slider showerTime;
controlP5.Slider sensorDistance;
controlP5.Slider sleepTimeDay;
controlP5.Toggle timeToggle;
Range timeRange;
controlP5.Toggle tempToggle;
controlP5.Slider tempSlider;
controlP5.Toggle rainToggle;
controlP5.Slider rainSlider;
controlP5.Toggle limitToggle;
controlP5.Slider limitShowers;
controlP5.Button getValues;
controlP5.Button defaultValues;
controlP5.Button setValues;
// set colors
int sensorGoodColor = color(255, 255, 0);
int sensorBadColor = color(255, 0, 0);
int actColor = color(100, 180, 255);
int fgrdColor = color(40, 130, 255);
int bgrdColor = color(30, 50, 100);
int disFgrdColor = color(80, 80, 100);
int disBgrdColor = color(50, 50, 70);
int butOnColor = color(0, 255, 0);
int butOffColor = color(200, 0, 0);
// declare images
PImage[] iImages = new PImage[3];
PImage[] BTimages = new PImage[3];


void setupGUI() {
  // Setup the GUI
  orientation(PORTRAIT);
  noStroke();
  cp5 = new ControlP5(this);

  // set dimention variables
  int screenWidth = width;
  int screenHeight = height;
  int paddingTop = int(screenHeight/23.7); // 50
  int paddingSide = int(screenWidth/12); // 60
  int labelSpacing = 5;
  int labelWidth = (screenWidth - (paddingSide * 2) - (labelSpacing * 3))/4;
  int sliderTop = int(screenHeight/5.9); // 200
  int sliderLeft = int(screenWidth/4.5); // 160
  int sliderWidth = screenWidth - paddingSide - sliderLeft;
  int sliderHeight = int(screenHeight/29.6); // 40
  int sliderSpacing = (screenHeight - sliderTop)/8;
  int buttonSpacing = 5;
  int buttonHeight = int(screenHeight/14.8); // 80
  int buttonWidth = (screenWidth - (paddingSide * 2) - (buttonSpacing * 2))/3;
  int listHeight = int(screenHeight/19.7); // 60

  ControlFont header1 = new ControlFont(createFont("Arial", 
    int(screenHeight/25))); // 50
  ControlFont cf1 = new ControlFont(createFont("Arial", 
    int(screenHeight/42))); // 30

  // load images
  if (screenHeight/23 < 75) {
    iImages[0] = loadImage("info_a_50.png");
    iImages[1] = loadImage("info_b_50.png");
    iImages[2] = loadImage("info_c_50.png");
    BTimages[0] = loadImage("bluetooth_r_50.png");
    BTimages[1] = loadImage("bluetooth_g_50.png");
    BTimages[2] = loadImage("bluetooth_b_50.png");
  } else if (screenHeight/23 < 100) {
    iImages[0] = loadImage("info_a_75.png");
    iImages[1] = loadImage("info_b_75.png");
    iImages[2] = loadImage("info_c_75.png");
    BTimages[0] = loadImage("bluetooth_r_75.png");
    BTimages[1] = loadImage("bluetooth_g_75.png");
    BTimages[2] = loadImage("bluetooth_b_75.png");
  } else if (screenHeight/23 < 125) {
    iImages[0] = loadImage("info_a_100.png");
    iImages[1] = loadImage("info_b_100.png");
    iImages[2] = loadImage("info_c_100.png");
    BTimages[0] = loadImage("bluetooth_r_100.png");
    BTimages[1] = loadImage("bluetooth_g_100.png");
    BTimages[2] = loadImage("bluetooth_b_100.png");
  } else {
    iImages[0] = loadImage("info_a_125.png");
    iImages[1] = loadImage("info_b_125.png");
    iImages[2] = loadImage("info_c_125.png");
    BTimages[0] = loadImage("bluetooth_r_125.png");
    BTimages[1] = loadImage("bluetooth_g_125.png");
    BTimages[2] = loadImage("bluetooth_b_125.png");
  }

  // about indicator
  aboutButton = cp5.addButton("about")
    .setPosition(paddingSide, paddingTop)
    .setImages(iImages)
    .updateSize()
    ;

  // Page Heading
  textHeader = cp5.addTextlabel("header")
    .setText("Animal Showers")
    .setPosition(sliderLeft, paddingTop)
    .setFont(header1)
    ;

  // bluetooth indicator
  bluetooth = cp5.addButton("Bluetooth")
    .setPosition(screenWidth - paddingSide - 50, paddingTop)
    .setImages(BTimages)
    .updateSize()
    ;

  // current system time
  timeLabel = cp5.addTextlabel("systemTime")
    .setText("H: --:--")
    .setPosition(paddingSide, paddingTop + buttonHeight)
    .setColorValue(sensorBadColor)
    .setFont(cf1)
    ;

  // current battery voltage
  voltageLabel = cp5.addTextlabel("batteryVoltage")
    .setText("B: --.-V")
    .setPosition(paddingSide + labelWidth + labelSpacing, paddingTop + buttonHeight)
    .setColorValue(sensorBadColor)
    .setFont(cf1)
    ;

  // current moisture
  moistureLabel = cp5.addTextlabel("moistureGauge")
    .setText("M: --%")
    .setPosition(paddingSide + (labelWidth*2) + (labelSpacing*2), 
    paddingTop +buttonHeight)
    .setColorValue(sensorBadColor)
    .setFont(cf1)
    ;

  // current temp
  tempLabel = cp5.addTextlabel("tempGauge")
    .setText("T: -- C")
    .setPosition(screenWidth - paddingSide - labelWidth, paddingTop + buttonHeight)
    .setColorValue(sensorBadColor)
    .setFont(cf1)
    ;

  // recent shower activity - not implimented

  // System ON/OFF
  onOffToggle = cp5.addToggle("systemOnOff")
    .setPosition(paddingSide, sliderTop)
    .setSize(sliderHeight, sliderHeight)
    .setValue(true)
    .setColorActive(butOnColor)
    .setColorBackground(butOffColor)
    ;
  onOffToggle.getCaptionLabel()
    .align(ControlP5.LEFT, ControlP5.BOTTOM_OUTSIDE)
    .setPaddingX(0)
    .setPaddingY(10)
    .setFont(cf1)
    .toUpperCase(false)
    .setText("On")
    ;

  showerTime = cp5.addSlider("defaultShower")
    .setPosition(sliderLeft, sliderTop)
    .setSize(sliderWidth, sliderHeight)
    .setRange(1, 240)
    ;
  // reposition the Labels for the controller
  showerTime.getValueLabel()
    .align(ControlP5.LEFT, ControlP5.BOTTOM_OUTSIDE)
    .setPaddingX(0)
    .setPaddingY(10)
    .setFont(cf1)
    .toUpperCase(false)
    .setText(defaultShower + " sec");
  showerTime.getCaptionLabel()
    .align(ControlP5.RIGHT, ControlP5.BOTTOM_OUTSIDE)
    .setPaddingX(0)
    .setPaddingY(10)
    .setFont(cf1)
    .toUpperCase(false)
    .setText("Shower Duration")
    ;

  sensorDistance = cp5.addSlider("sensorThreshold")
    .setPosition(sliderLeft, sliderTop + sliderSpacing)
    .setSize(sliderWidth, sliderHeight)
    .setRange(0, 500)
    ;
  // reposition the Labels for the controller
  sensorDistance.getValueLabel()
    .align(ControlP5.LEFT, ControlP5.BOTTOM_OUTSIDE)
    .setPaddingX(0)
    .setPaddingY(10)
    .setFont(cf1)
    .toUpperCase(false)
    .setText(sensorThreshold + " cm");
  sensorDistance.getCaptionLabel()
    .align(ControlP5.RIGHT, ControlP5.BOTTOM_OUTSIDE)
    .setPaddingX(0)
    .setPaddingY(10)
    .setFont(cf1)
    .toUpperCase(false)
    .setText("Sensor Distance")
    ;

  sleepTimeDay = cp5.addSlider("defaultSleep")
    .setPosition(sliderLeft, sliderTop + (sliderSpacing * 2))
    .setSize(sliderWidth, sliderHeight)
    .setRange(0, 5)
    ;
  // reposition the Labels for the controller
  sleepTimeDay.getValueLabel()
    .align(ControlP5.LEFT, ControlP5.BOTTOM_OUTSIDE)
    .setPaddingX(0)
    .setPaddingY(10)
    .setFont(cf1)
    .toUpperCase(false)
    .setText(nf(defaultSleep, 1, 1) + " sec")
    ;
  sleepTimeDay.getCaptionLabel()
    .align(ControlP5.RIGHT, ControlP5.BOTTOM_OUTSIDE)
    .setPaddingX(0)
    .setPaddingY(10)
    .setFont(cf1)
    .toUpperCase(false)
    .setText("Sensor Interval")
    ;

  timeToggle = cp5.addToggle("clockOnOff")
    .setPosition(paddingSide, sliderTop + (sliderSpacing * 3))
    .setSize(sliderHeight, sliderHeight)
    .setValue(true)
    .setColorActive(butOnColor)
    .setColorBackground(butOffColor)
    ;
  timeToggle.getCaptionLabel()
    .setText("")
    ;

  timeRange = cp5.addRange("operatingHours")
    // disable broadcasting since setRange and setRangeValues will trigger an event
    .setBroadcast(false) 
    .setPosition(sliderLeft, sliderTop + (sliderSpacing * 3))
    .setSize(sliderWidth, sliderHeight)
    .setHandleSize(sliderHeight)
    .setRange(0, 24)
    .setRangeValues(morningTime, eveningTime)
    .setHighValueLabel("")
    // after the initialization we turn broadcast back on again
    .setBroadcast(true)
    ;
  // reposition the Labels for the controller
  timeRange.getValueLabel()
    .align(ControlP5.LEFT, ControlP5.BOTTOM_OUTSIDE)
    .setPaddingX(0)
    .setPaddingY(10)
    .setFont(cf1)
    .toUpperCase(false)
    .setText(morningTime + " - " + eveningTime + " hrs");
  timeRange.getCaptionLabel()
    .align(ControlP5.RIGHT, ControlP5.BOTTOM_OUTSIDE)
    .setPaddingX(0)
    .setPaddingY(10)
    .setFont(cf1)
    .toUpperCase(false)
    .setText("Operating Hours")
    ;

  rainToggle = cp5.addToggle("rainOnOff")
    .setPosition(paddingSide, sliderTop + (sliderSpacing * 4))
    .setSize(sliderHeight, sliderHeight)
    .setValue(true)
    .setColorActive(butOnColor)
    .setColorBackground(butOffColor)
    ;
  rainToggle.getCaptionLabel()
    .setText("")
    ;

  rainSlider = cp5.addSlider("maxRain")
    .setPosition(sliderLeft, sliderTop + (sliderSpacing * 4))
    .setSize(sliderWidth, sliderHeight)
    .setRange(0, 100)
    ;
  // reposition the Labels for the controller
  rainSlider.getValueLabel()
    .align(ControlP5.LEFT, ControlP5.BOTTOM_OUTSIDE)
    .setPaddingX(0)
    .setPaddingY(10)
    .setFont(cf1)
    .toUpperCase(false)
    .setText(maxRain + " %");
  rainSlider.getCaptionLabel()
    .align(ControlP5.RIGHT, ControlP5.BOTTOM_OUTSIDE)
    .setPaddingX(0)
    .setPaddingY(10)
    .setFont(cf1)
    .toUpperCase(false)
    .setText("Max Moisture")
    ;

  tempToggle = cp5.addToggle("tempOnOff")
    .setPosition(paddingSide, sliderTop + (sliderSpacing * 5))
    .setSize(sliderHeight, sliderHeight)
    .setValue(true)
    .setColorActive(butOnColor)
    .setColorBackground(butOffColor)
    ;
  tempToggle.getCaptionLabel()
    .setText("")
    ;

  tempSlider = cp5.addSlider("minTemp")
    .setPosition(sliderLeft, sliderTop + (sliderSpacing * 5))
    .setSize(sliderWidth, sliderHeight)
    .setRange(0, 30)
    ;
  // reposition the Labels for the controller
  tempSlider.getValueLabel()
    .align(ControlP5.LEFT, ControlP5.BOTTOM_OUTSIDE)
    .setPaddingX(0)
    .setPaddingY(10)
    .setFont(cf1)
    .toUpperCase(false)
    .setText(minTemp + " C");
  tempSlider.getCaptionLabel()
    .align(ControlP5.RIGHT, ControlP5.BOTTOM_OUTSIDE)
    .setPaddingX(0)
    .setPaddingY(10)
    .setFont(cf1)
    .toUpperCase(false)
    .setText("Min Temp")
    ;

  limitToggle = cp5.addToggle("limitOnOff")
    .setPosition(paddingSide, sliderTop + (sliderSpacing * 6))
    .setSize(sliderHeight, sliderHeight)
    .setValue(true)
    .setColorActive(butOnColor)
    .setColorBackground(butOffColor)
    ;
  limitToggle.getCaptionLabel()
    .setText("")
    ;

  limitShowers = cp5.addSlider("limitReadings")
    .setPosition(sliderLeft, sliderTop + (sliderSpacing * 6))
    .setSize(sliderWidth, sliderHeight)
    .setRange(0, 100)
    ;
  // reposition the Labels for the controller
  limitShowers.getValueLabel()
    .align(ControlP5.LEFT, ControlP5.BOTTOM_OUTSIDE)
    .setPaddingX(0)
    .setPaddingY(10)
    .setFont(cf1)
    .toUpperCase(false)
    .setText(limitReadings + " %");
  limitShowers.getCaptionLabel()
    .align(ControlP5.RIGHT, ControlP5.BOTTOM_OUTSIDE)
    .setPaddingX(0)
    .setPaddingY(10)
    .setFont(cf1)
    .toUpperCase(false)
    .setText("Limit Shower")
    ;

  getValues = cp5.addButton("getValues")
    .setPosition(paddingSide, sliderTop + (sliderSpacing * 7))
    .setSize(buttonWidth, buttonHeight)
    ;
  // resize the Labels for the controller
  getValues.getCaptionLabel()
    .setFont(cf1)
    .toUpperCase(false)
    .setText("Get")
    ;

  defaultValues = cp5.addButton("defaultValues")
    .setPosition(paddingSide + buttonWidth + buttonSpacing, 
    sliderTop + (sliderSpacing * 7))
    .setSize(buttonWidth, buttonHeight)
    ;
  // resize the Labels for the controller
  defaultValues.getCaptionLabel()
    .setFont(cf1)
    .toUpperCase(false)
    .setText("Defaults")
    ;

  setValues = cp5.addButton("setValues")
    .setPosition(paddingSide + ((buttonWidth + buttonSpacing)*2), 
    sliderTop + (sliderSpacing * 7))
    .setSize(buttonWidth, buttonHeight)
    ;
  // resize the Labels for the controller
  setValues.getCaptionLabel()
    .setFont(cf1)
    .toUpperCase(false)
    .setText("Send")
    ;


  // bluetooth port list (visible when the bluetooth indicator is pressed)
  // Draw this last so that it apears above the other items on screen
  //if (messenger.discoveredDevices.size() < 1)
  //messenger.discoveredDevices = Arrays.asList("a", "b", "c", "d", "e", "f", "g", "h");

  ports = cp5.addScrollableList("bluetoothList")
    .setPosition(paddingSide, paddingTop + buttonHeight)
    .setSize(screenWidth - paddingSide - paddingSide, 
    screenHeight - (paddingTop + buttonHeight))
    .setBarHeight(listHeight)
    .setItemHeight(listHeight)
    .setBackgroundColor(color(0))
    // .actAsPulldownMenu()
    .hide()
    .setType(ScrollableList.LIST) // currently supported DROPDOWN and LIST
    ;
  ports.getCaptionLabel()
    .set("Select a Bluetooth Device")
    .setFont(cf1)
    .toUpperCase(false)
    ;
  ports.getValueLabel()
    .setFont(cf1)
    .toUpperCase(false)
    ;
}


// -----------------------------------
// GUI Functions

void controlEvent(ControlEvent theControlEvent) {
  if (theControlEvent.isFrom("operatingHours")) {
    // min and max values are stored in an array.
    // access this array with controller().arrayValue().
    // min is at index 0, max is at index 1.
    morningTime = byte(timeRange.getArrayValue(0));
    eveningTime = byte(timeRange.getArrayValue(1));
    timeRange.setHighValueLabel("");
    timeRange.getValueLabel()
      .setText(morningTime + " - " + eveningTime + " hrs");
  }

  // update the slider labels
  if (theControlEvent.isFrom("defaultShower")) {
    showerTime.getValueLabel()
      .setText(defaultShower + " sec");
  }
  if (theControlEvent.isFrom("sensorThreshold")) {
    sensorDistance.getValueLabel()
      .setText(sensorThreshold + " cm");
  }
  if (theControlEvent.isFrom("defaultSleep")) {
    sleepTimeDay.getValueLabel()
      .setText(nf(defaultSleep, 1, 1) + " sec");
  }
  if (theControlEvent.isFrom("minTemp")) {
    tempSlider.getValueLabel()
      .setText(minTemp + " C");
  }
  if (theControlEvent.isFrom("maxRain")) {
    rainSlider.getValueLabel()
      .setText(maxRain + " %");
  }
  if (theControlEvent.isFrom("limitReadings")) {
    limitShowers.getValueLabel()
      .setText(limitReadings + " %");
  }
}

public void about(int theValue) {
  // get the current settings from the Arduino device
  // print message to screen
  KetaiAlertDialog.popup(this, "About", aboutMessage);
}

public void Bluetooth(int theValue) {
  if (ports.isVisible()) {
    ports.hide();
  } else {
    List<String> portList;
    if (messenger.discoveredDevices.size() != 0) portList = messenger.discoveredDevices;
    else portList = Arrays.asList("No Devices Found");
    println(portList);
    ports.setItems(portList);
    if (messenger.isConnected()) ports.addItem("Disconnect Current Device", "disconnect");
    ports.show()
      .setOpen(true)
      ;
  }
}

void bluetoothList(int n) {
  /* request the selected item based on index n */
  println(n);
  String portName = (String)ports.getItem(n).get("name");
  // Stop the existing bluetooth connection
  messenger.stop();
  if (portName != "No Devices Found" && portName != "Disconnect Current Device") {
    println("Starting New Connection");
    // Construct a new Arduino instance for communicating
    messenger = new ArduinoMessenger(this, portName);
    BTportWaiting = true;
    BTportStartTime = millis();
  } else {
    // set up a dummy messenger so that we don't connect
    messenger = new ArduinoMessenger(this, "nothing");
    BTportWaiting = false;
  }
  ports.hide();
}

void systemOnOff(boolean theFlag) {
  if (theFlag==true) {
    systemOnOff = true;
    onOffToggle.getCaptionLabel()
      .setText("On");
    enableSlider(showerTime);
    enableSlider(sensorDistance);
    enableSlider(sleepTimeDay);
    enableToggle(timeToggle);
    if (timeToggle.getState()) enableRange(timeRange);
    enableToggle(tempToggle);
    if (tempToggle.getState()) enableSlider(tempSlider);
    enableToggle(rainToggle);
    if (rainToggle.getState()) enableSlider(rainSlider);
    enableToggle(limitToggle);
    if (limitToggle.getState()) enableSlider(limitShowers);
  } else {
    systemOnOff = false;
    onOffToggle.getCaptionLabel()
      .setText("Off");
    disableSlider(showerTime);
    disableSlider(sensorDistance);
    disableSlider(sleepTimeDay);
    disableToggle(timeToggle);
    disableRange(timeRange);
    disableToggle(tempToggle);
    disableSlider(tempSlider);
    disableToggle(rainToggle);
    disableSlider(rainSlider);
    disableToggle(limitToggle);
    disableSlider(limitShowers);
  }
}

void enableToggle(controlP5.Toggle theToggle) {
  theToggle
    .setLock(false)
    .setColorActive(butOnColor)
    .setColorBackground(butOffColor)
    ;
}

void disableToggle(controlP5.Toggle theToggle) {
  theToggle
    .setLock(true)
    .setColorActive(disFgrdColor)
    .setColorBackground(disBgrdColor)
    ;
}

void enableSlider(controlP5.Slider theSlider) {
  theSlider
    .setColorActive(actColor)
    .setColorForeground(fgrdColor)
    .setColorBackground(bgrdColor)
    .setLock(false)
    ;
}

void disableSlider(controlP5.Slider theSlider) {
  theSlider
    .setColorForeground(disFgrdColor)
    .setColorBackground(disBgrdColor)
    .setLock(true)
    ;
}

void enableRange(Range theRange) {
  theRange
    .setColorActive(actColor)
    .setColorForeground(fgrdColor)
    .setColorBackground(bgrdColor)
    .setLock(false)
    ;
}

void disableRange(Range theRange) {
  theRange
    .setColorForeground(disFgrdColor)
    .setColorBackground(disBgrdColor)
    .setLock(true)
    ;
}

void clockOnOff(boolean theFlag) {
  clockOnOff = theFlag;
  if (theFlag==true) {
    // enable slider
    enableRange(timeRange);
    timeRange.getValueLabel()
      .setText(morningTime + " - " + eveningTime + " hrs");
  } else {
    // disable slider
    disableRange(timeRange);
    timeRange.getValueLabel()
      .setText("Disabled");
  }
}

void tempOnOff(boolean theFlag) {
  tempOnOff = theFlag;
  if (theFlag==true) {
    // enable slider
    enableSlider(tempSlider);
    tempSlider.getValueLabel()
      .setText(minTemp + " C");
  } else {
    // disable slider
    disableSlider(tempSlider);
    tempSlider.getValueLabel()
      .setText("Disabled");
  }
}

void rainOnOff(boolean theFlag) {
  rainOnOff = theFlag;
  if (theFlag==true) {
    // enable slider
    enableSlider(rainSlider);
    rainSlider.getValueLabel()
      .setText(maxRain + " %");
  } else {
    // disable slider
    disableSlider(rainSlider);
    rainSlider.getValueLabel()
      .setText("Disabled");
  }
}

void limitOnOff(boolean theFlag) {
  limitOnOff = theFlag;
  if (theFlag==true) {
    // enable slider
    enableSlider(limitShowers);
    limitShowers.getValueLabel()
      .setText(limitReadings + " %");
  } else {
    // disable slider
    disableSlider(limitShowers);
    limitShowers.getValueLabel()
      .setText("Disabled");
  }
}

public void getValues(int theValue) {
  // get the current settings from the Arduino device
  // print message to screen
  if (messenger.isConnected()) {
    getSettings();
    updateGUI();
  } else {
    KetaiAlertDialog.popup(this, 
      "Data Transfer Error", "Bluetooth is not connected");
  }
}

public void defaultValues(int theValue) {
  // load default settings
  loadDefaultSettings();
  // update GUI
  updateGUI();
}


public void setValues(int theValue) {
  // send new settings to the Arduino device
  if (messenger.isConnected()) sendSettings();
  else KetaiAlertDialog.popup(this, 
    "Data Transfer Error", "Bluetooth is not connected");
}


// Update the sensor display as active or inactive
void updateSensorDisplay(boolean _active) {
  if (_active) {
    timeLabel.setColorValue(sensorGoodColor);
    voltageLabel.setColorValue(sensorGoodColor);
    moistureLabel.setColorValue(sensorGoodColor);
    tempLabel.setColorValue(sensorGoodColor);
  } else {
    timeLabel.setColorValue(sensorBadColor);
    voltageLabel.setColorValue(sensorBadColor);
    moistureLabel.setColorValue(sensorBadColor);
    tempLabel.setColorValue(sensorBadColor);
  }
}


// Update the sensor readings
void updateSensorDisplay(int _hour, int _min, int _volt, int _moist, int _temp) {
  // values of -100 will disable reading
  // display time
  timeLabel
    .setColorValue(sensorGoodColor)
    .setText("H: " + nf(_hour, 2) + ":" + nf(_min, 2))
    ;
  float batteryVolage = _volt / 10.0;
  voltageLabel
    .setColorValue(sensorGoodColor)
    .setText("B: " + nf(batteryVolage, 1, 1) + "V")
    ;
  moistureLabel
    .setColorValue(sensorGoodColor)
    .setText("M: " + _moist + "%")
    ;
  tempLabel
    .setColorValue(sensorGoodColor)
    .setText("T: " + _temp + " C")
    ;
}


public void updateGUI() {
  // update the display with current values
  showerTime.setValue(defaultShower);
  sensorDistance.setValue(sensorThreshold);
  sleepTimeDay.setValue(defaultSleep);
  timeToggle.setValue(clockOnOff);
  timeRange.setRangeValues(morningTime, eveningTime);
  tempToggle.setValue(tempOnOff);
  tempSlider.setValue(minTemp);
  rainToggle.setValue(rainOnOff);
  rainSlider.setValue(maxRain);
  limitToggle.setValue(limitOnOff);
  limitShowers.setValue(limitReadings);
  onOffToggle.setValue(systemOnOff);
}