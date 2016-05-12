import ketai.net.bluetooth.*;
// needed for 'List'
// import java.util.*;


/** For sending data to the Arduino device with the given name via bluetooth. */
class ArduinoMessenger {

  /** The messenger's bluetooth instance used for sending data. */
  KetaiBluetooth bluetooth;
  /** The name of the device name with which we want to communicate. */
  String arduinoName;
  String arduinoAddress;  
  List<String> discoveredDevices;

  /**
   Constructor for an `ArduinoMessenger` instance.
   This constructs our `KetaiBluetooth` instance and starts it up.
   It also sets the given name as the `arduinoName`.
   */
  ArduinoMessenger(PApplet papp, String _arduinoName) {
    arduinoName = _arduinoName;
    bluetooth = new KetaiBluetooth(papp);
    bluetooth.start();
  }


  /** Returns whether or not we're currently connected to our arduino device or not. */
  Boolean isConnected() {
    ArrayList<String> connectedDevices = bluetooth.getConnectedDeviceNames();
    for (String connectedDeviceNameAndAddress : connectedDevices) {

      /*
      For some reason the ketai library concatenates the MAC address onto the end after the
       name for `getConnectedDeviceNames` even though it does not for `getDiscoveredDeviceNames`
       or `getPairedDeviceNames`...
       
       This line retrieves just the name from the front.
       i.e. we get "Foo" from "Foo(1F:5E:9A:32:1F)".
       */
      String connectedDeviceName = connectedDeviceNameAndAddress.substring(0, arduinoName.length());

      // If we're connected to our target, we're done.
      if (connectedDeviceName.equals(arduinoName)) {
        arduinoAddress = connectedDeviceNameAndAddress.substring(
          arduinoName.length() + 1, arduinoName.length() + 18);
        return true;
      }
    }
    return false;
  }


  /**
   This method is designed to be called regularaly (i.e. within an update loop).
   It does the following:
   - Checks to see if we're connected to the target.
   If we are, it returns `true`.
   If we are not...
   - Checks to see if our target has been discovered yet or not.
   If so, it attempts to connect to the device and returns whether or not it was successful.
   If not...
   - Checks to see if we're searching for devices or not.
   If so, returns `false`.
   If not, starts searching for devices and returns `false`.
   It returns true if we are connected to the target device.
   It returns false if we are not.
   */
  Boolean maintainConnection() {

    // Check to see if we're connected to our target. If we are, we're done.
    if (isConnected()) {
      return true;
    }

    // no need to be discoverable to initiate a connection with a slave device
    /*
    // If we're not yet connected, we need to make sure that we are discoverable.
     if (!bluetooth.isDiscoverable()) {
     bluetooth.makeDiscoverable();
     }
     */

    // We also need to check if we've discovered the arduino device yet or not.
    discoveredDevices = bluetooth.getDiscoveredDeviceNames();
    for (String discoveredDeviceName : discoveredDevices) {
      // If we've already discovered our target, we'll try connecting.
      if (discoveredDeviceName.equals(arduinoName)) {
        Boolean wasSuccessful = bluetooth.connectToDeviceByName(arduinoName);
        // update the arduino bluetooth address. Needed when we check incoming messages
        if (wasSuccessful) this.isConnected();
        return wasSuccessful;
      }
    }

    // If we have not yet discovered the target, check to see that we're searching.
    if (!bluetooth.isDiscovering()) {
      // If not, start searching.
      bluetooth.discoverDevices();
    }

    return false;
  }

  /** Sends the given `byte`s to the target device. */
  void sendBytes(byte[] data) {
    bluetooth.writeToDeviceName(arduinoName, data);
  }
  
  // stop the connection
  void stop(){
    bluetooth.stop();
  }

  /**
   Produces a String with the current state of the messenger.
   This is just for debugging purposes.
   */
  String getStateInformation() {
    String bluetoothState = "";
    bluetoothState += "`Arduino`'s Bluetooth State:\n";
    bluetoothState += ("\tServer Running: " + bluetooth.isStarted() + "\n");
    bluetoothState += ("\tDiscovering: " + bluetooth.isDiscovering() + "\n");
    bluetoothState += ("\tDevice Discoverable: " + bluetooth.isDiscoverable() + "\n");

    bluetoothState += "\tDiscovered Devices:\n";
    discoveredDevices = bluetooth.getDiscoveredDeviceNames();
    for (String deviceName : discoveredDevices) {
      String address = bluetooth.lookupAddressByName(deviceName);
      bluetoothState += ("\t\tName: " + deviceName + " | Address: " + address + "\n");
    }

    bluetoothState += "\tConnected Devices:\n";
    ArrayList<String> connectedDevices = bluetooth.getConnectedDeviceNames();
    for (String deviceName : connectedDevices) {
      String address = bluetooth.lookupAddressByName(deviceName);
      bluetoothState += ("\t\tName: " + deviceName + " | Address: " + address + "\n");
    }

    bluetoothState += "\tPaired Devices:\n";
    ArrayList<String> pairedDevices = bluetooth.getPairedDeviceNames();
    for (String deviceName : pairedDevices) {
      String address = bluetooth.lookupAddressByName(deviceName);
      bluetoothState += ("\t\tName: " + deviceName + " | Address: " + address + "\n");
    }

    return bluetoothState;
  }
}