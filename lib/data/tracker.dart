import 'package:cartracker/data/tracker_position.dart';
import 'package:cartracker/data/tracker_message.dart';
import 'package:cartracker/database/database.dart';
import 'package:cartracker/database/tracker_db.dart';
import 'package:cartracker/database/tracker_message_db.dart';
import 'package:cartracker/database/tracker_position_db.dart';
import 'package:cartracker/utils/sms_utils.dart';
import 'package:sqflite/sqflite.dart';
import 'package:telephony/telephony.dart';
import 'package:uuid/uuid.dart';

/// Tracker represents a GPS tracker, contains all the metadata required to communicate with the tracker.
class Tracker {
  /// UUID used to identify the tracker.
  String uuid = '';

  /// ID of the tracker device, each tracker has its own ID.
  String id = '';

  /// Name of the tracker.
  String name = 'Tracker';

  /// License plate of the vehicle where the tracker is placed
  String licensePlate = '';

  /// Chassis number of the vehicle  where the tracker is placed
  String chassisNumber = '';

  /// Model of the tracker.
  String model = '';

  /// Color to represent the tracker on the map in hexadecimal.
  int color = 0xFFFF0000;

  /// Phone number of the tracker used to send and receive messages.
  String phoneNumber = '';

  /// Admin number of the tracker.
  String adminNumber = '';

  /// SOS numbers associated with the tracker (up to 3 SOS numbers).
  List<String> sosNumbers = [];

  /// PIN number of the tracker used for authentication.
  ///
  /// Usually it is a 4 digit numeric pin.
  String pin = '123456';

  /// Limit speed in miles per hour, defined on the tracker.
  int speedLimit = 0;

  /// Time limit before the tracker enters into sleep mode.
  int sleepLimit = 0;

  /// If enabled the ignition alarm is fired every time the ACC signal changes.
  ///
  /// If the signal is not connected to the car it will not fire.
  bool ignitionAlarm = false;

  /// Indicates if the alarm sends an SMS to the admin it power was unplugged.
  bool powerAlarmSMS = false;

  /// Indicates if the alarm calls the admin it power was unplugged.
  bool powerAlarmCall = false;

  /// Level of battery of the tracker, has to be read manually using the info command.
  ///
  /// Value from 1 to 5, 5 meaning fully charged.
  int battery = 0;

  /// Access Point Name (APN) configured on the tracker for GPRS data access.
  String apn = '';

  /// Integrated Circuit Card Identifier (ICCID) of the SIM card inserted in the tracker.
  String iccid = '';

  /// Messages exchanged with the tracker device.
  List<TrackerMessage> messages = [];

  /// Positions of the tracker over time.
  List<TrackerPosition> positions = [];

  Tracker() {
    this.uuid = const Uuid().v4().toString();
  }

  /// Add a message to the tracker.
  ///
  /// Updates the local messages list and the database state.
  Future<void> addMessage(TrackerMessage message) async {
    Database? db = await DataBase.get();
    await TrackerMessageDB.add(db!, this.uuid, message);
    this.messages.add(message);
  }


  /// Add a new location to the tracker.
  ///
  /// Updates the local locations list and the database state.
  Future<void> addPosition(TrackerPosition position) async {
    Database? db = await DataBase.get();
    await TrackerPositionDB.add(db!, this.uuid, position);
    this.positions.add(position);
  }

  /// Update the tracker information in database.
  void update() async {
    Database? db = await DataBase.get();
    TrackerDB.update(db!, this);
  }

  /// Compare the phone number of the tracker with an external phone number.
  ///
  /// Check if they are the same allow for some tolerance (e.g. country codes etc).
  bool compareAddress(String address) {
    if (address.isEmpty || this.phoneNumber.isEmpty) {
      return false;
    }

    if (address.length > this.phoneNumber.length) {
      return address.contains(this.phoneNumber);
    } else if (address.length < this.phoneNumber.length) {
      return this.phoneNumber.contains(address);
    }

    return address == this.phoneNumber;
  }

  /// Process a message received from SMS and store its result on a tracker message.
  ///
  /// @param message Message received.
  void processSMS(SmsMessage msg) {
    String body = msg.body!;
    DateTime timestamp = DateTime.fromMillisecondsSinceEpoch(msg.date!);

    this.addMessage(TrackerMessage(MessageDirection.RECEIVED, body, timestamp));

    // Acknowledge message
    String ackMsg = body.toLowerCase();
    if (ackMsg == 'admin ok' || ackMsg == 'apn ok' || ackMsg == 'password ok' || ackMsg == 'speed ok' || ackMsg == 'ok') {
      // Modal.toast(Locales.get('trackerAcknowledge'));
      return;
    }

    // List of SOS numbers
    if (body.startsWith('101#')) {
      List<String> numbers = body.split(' ');
      for (int i = 0; i < numbers.length;  i++) {
        this.sosNumbers[i] = numbers[i].substring(4);
      }
      this.update();
      return;
    }

    // GPS Location
    if (body.startsWith('http')) {
      try {
        RegExp regex = RegExp("/https?\:\/\/maps\.google\.cn\/maps\??q?=?N?([\-0-9\.]*),?W?([\-0-9\.]*)\s*ID:([0-9]+)\s*ACC:([A-Z]+)\s*GPS:([A-Z]+)\s*Speed:([0-9\.]+) ?KM\/H\s*([0-9]+)\-([0-9]+)\-([0-9]+)\s*([0-9]+):([0-9]+):([0-9]+)/");
        List<RegExpMatch> regMatch = regex.allMatches(body).toList();
        List<String> matches = regMatch.map((val) => val.input).toList();

        // TODO <REMOVE THIS>
        print(matches);

        TrackerPosition data = TrackerPosition();
        data.timestamp = timestamp;

        data.latitude = double.parse(matches[1]);

        data.longitude = -double.parse(matches[2]);

        String id = matches[3];

        data.acc = matches[4] != 'OFF';
        data.gps = matches[5] == 'A';
        data.speed = double.parse(matches[6]);

        int year = int.parse(matches[7]) + 2000;
        int month = int.parse(matches[8]);
        int day = int.parse(matches[9]);

        int hour = int.parse(matches[10]);
        int minute = int.parse(matches[11]);
        int seconds = int.parse(matches[12]);

        this.id = id;

        this.addPosition(data);
        // Modal.toast(Locale.get('trackerLocation', {name: this.name}));

        return;
      } catch(e) {
        // Modal.alert(Locale.get('error'), Locale.get('errorParseLocationMsg'));
        return;
      }
    }

    // GPS Tracker data
    RegExp infoRegex = RegExp("/([A-Za-z0-9_\.]+) ([0-9]+)\/([0-9]+)\/([0-9]+)\s*ID:([0-9]+)\s*IP:([0-9\.a-zA-Z\\]+)\s*([0-9]+) BAT:([0-9])\s*APN:([0-9\.a-zA-Z\\]+)\s*GPS:([0-9A-Z\-]+)\s*GSM:([0-9]+)\s*ICCID:([0-9A-Z]+)/");
    try {
      if (infoRegex.hasMatch(body)) {
        List<RegExpMatch> regMatch = infoRegex.allMatches(body).toList();
        List<String> matches = regMatch.map((val) => val.input).toList();

        String model = matches[1];
        String id = matches[5];
        String ip = matches[6];
        String port = matches[7];
        int battery = int.parse(matches[8]);
        String apn = matches[9];
        String gps = matches[10];
        String gsm = matches[11];
        String iccid = matches[12];

        this.battery = battery;
        this.model = model;
        this.apn = apn;
        this.iccid = iccid;
        this.id = id;
        this.update();

        // Modal.toast(Locale.get('trackerUpdated', {name: this.name}));
        return;
      }
    }
    catch(e) {
      // Modal.alert(Locale.get('error'), Locale.get('errorParseInfoMsg'));
      return;
    }
  }


  /// Send a message to this tracker, store it in the messages list.
  ///
  /// @param message Message to be sent to the tracker.
  void sendSMS(String message) {
    SMSUtils.send(message, this.phoneNumber);
    this.addMessage(TrackerMessage(MessageDirection.SENT, message, DateTime.now()));
  }

  /// Request a data with the location of the device, status and speed of the tracker.
  void requestLocation() {
    this.sendSMS('g1234');
  }

  /// Change the timezone of tracker.
  ///
  /// @param timezone Timezone to be used by the tracker.
  void setTimezone(String timezone) {
    String msg = 'zone' + this.pin + ' ' + timezone;

    this.sendSMS(msg);
  }

  /// Request a data with the location of the device, status and speed of the tracker.
  void getTrackerInfo() {
    String msg = 'CXZT';

    this.sendSMS(msg);
  }


  /// Change the pin of the tracker.
  ///
  /// @param newPin New pin to be set on the tracker.
  void changePIN(String newPin) {
    String msg = 'password' + this.pin + ' ' + newPin;

    this.pin = newPin;
    this.sendSMS(msg);
    this.update();
  }


  /// Set admin number used for the admin related information.
  ///
  /// @param phoneNumber Phone number use for control.
  void setAdminNumber(String phoneNumber) {
    String msg = 'admin' + this.pin + ' ' + phoneNumber;

    this.adminNumber = phoneNumber;
    this.sendSMS(msg);
    this.update();
  }


  /// Set sos number used for the GPS to return requested information, alarm messages etc.
  ///
  /// @param phoneNumber Phone number use for control.
  /// @param slot Slot being set can be 1, 2 or 3.
  void setSOSNumber(String phoneNumber, int slot) {
    if (slot < 1 || slot > 3) {
      throw new Exception('Invalid slot value.');
    }

    String msg = '10' + slot.toString() + '#' + phoneNumber + '#';

    this.sosNumbers[slot - 1] = phoneNumber;
    this.sendSMS(msg);
    this.update();
  }

  /// Delete SOS number used for the GPS to return requested information, alarm messages etc.
  ///
  /// @param slot Slot being set can be 1, 2 or 3.
  void deleteSOSNumber(int slot) {
    if (slot < 1 || slot > 3) {
      throw new Exception('Invalid slot value.');
    }

    String msg = 'D10' + slot.toString() + '#';

    this.sosNumbers[slot - 1] = '';
    this.sendSMS(msg);
    this.update();
  }


  /// Request a list of the SOS numbers registered on the device.
  void listSOSNumbers() {
    String msg = 'C10#';

    this.sendSMS(msg);
  }


  /// Enable/disable ignition auto security, used for the tracker to send and SMS every time the car ignition is switched.
  ///
  /// @param enabled State of the ignition alarm.
  void setIgnitionAlarm(bool enabled) {
    String msg = 'accclock,' + this.pin + ',' + (enabled ? '1' : '0');

    this.ignitionAlarm = enabled;
    this.sendSMS(msg);
    this.update();
  }


  /// Configure the tracker to call the admin phone if the power is disconnected from the device.
  ///
  /// @param enabled State of the power alarm.
  void setPowerAlarmCall(bool enabled) {
    String msg = 'pwrcall,' + this.pin + ',' + (enabled ? '1' : '0');

    this.powerAlarmCall = enabled;
    this.sendSMS(msg);
    this.update();
  }


  /// Configure the tracker to send a SMS alarm if the power is disconnected from the device.
  ///
  /// @param enabled State of the power alarm.
  void setPowerAlarmSMS(bool enabled) {
    String msg = 'pwrsms,' + this.pin + ',' + (enabled ? '1' : '0');

    this.powerAlarmSMS = enabled;
    this.sendSMS(msg);
    this.update();
  }


  /// Set the speed limit of the GPS tracker before an alarm is triggered.
  ///
  /// @param speed Speed limit in MPH zero means no speed limit.

  void setSpeedLimit(int speed) {
    if (speed > 999) {
      speed = 999;
    }

    // Round speed value
    speed = speed.round();

    // Covert into 3 digit string
    String strSpeed = speed.toString();
    while (strSpeed.length < 3) {
      strSpeed = '0' + strSpeed;
    }

    String msg = 'speed' + this.pin + ' ' + strSpeed;

    this.speedLimit = speed;
    this.sendSMS(msg);
    this.update();
  }


  /// Set the time of the GPS before it enters sleep mode after being used (wakes up by movement or sms).
  ///
  /// @param time Time limit in minutes, if set to zero it will disable sleep.
  void setSleepTime(int time) {
    String msg = 'sleep,' + this.pin + ',' + time.toString();

    this.sleepLimit = time;
    this.sendSMS(msg);
    this.update();
  }
}