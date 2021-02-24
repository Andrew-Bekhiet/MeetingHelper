library globals;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const List<Color> colors = [
  Colors.white,
  Colors.grey,
  Colors.black,
  Colors.transparent,
  Colors.brown,
  Colors.red,
  Colors.deepOrange,
  Colors.orange,
  Colors.amber,
  Colors.yellow,
  Colors.lime,
  Colors.lightGreen,
  Colors.green,
  Colors.blue,
  Colors.cyan,
  Colors.lightBlue,
  Colors.teal,
  Colors.indigo,
  Colors.deepPurple,
  Colors.purple,
  Colors.pink,
];

const List<Color> accents = <Color>[
  Colors.redAccent,
  Colors.pinkAccent,
  Colors.purpleAccent,
  Colors.deepPurpleAccent,
  Colors.indigoAccent,
  Colors.blueAccent,
  Colors.lightBlueAccent,
  Colors.cyanAccent,
  Colors.tealAccent,
  Colors.greenAccent,
  Colors.lightGreenAccent,
  Colors.limeAccent,
  Colors.yellowAccent,
  Colors.amberAccent,
  Colors.orangeAccent,
  Colors.deepOrangeAccent,
  Colors.brown,
  Colors.blueGrey,
  Colors.black
];

AndroidParameters androidParameters = AndroidParameters(
    packageName: 'com.AndroidQuartz.meetinghelper',
    minimumVersion: 4,
    fallbackUrl: Uri.parse(
        'https://onedrive.live.com/download?cid=857C7F256422E764&resid=85'
        '7C7F256422E764%212535&authkey=AOvqyUErovriovU'));

GetOptions dataSource = GetOptions(source: Source.serverAndCache);

DynamicLinkParametersOptions dynamicLinkParametersOptions =
    DynamicLinkParametersOptions(
        shortDynamicLinkPathLength: ShortDynamicLinkPathLength.unguessable);

FlutterSecureStorage flutterSecureStorage = FlutterSecureStorage();

bool historyOrder = false;
String historyOrderBy = 'Day';

IosParameters iosParameters =
    IosParameters(bundleId: 'com.AndroidQuartz.meetinghelper');

GlobalKey<ScaffoldState> mainScfld = GlobalKey<ScaffoldState>();

List<Color> primaries = <Color>[
  Colors.red,
  Colors.pink,
  Colors.purple,
  Colors.deepPurple,
  Colors.indigo,
  Colors.blue,
  Colors.lightBlue,
  Colors.cyan,
  Colors.teal,
  Colors.green,
  Colors.lightGreen,
  Colors.lime,
  Colors.yellow,
  Colors.amber,
  Colors.orange,
  Colors.deepOrange,
  Colors.deepOrangeAccent,
  Colors.blueAccent,
  Colors.grey.shade700
];

RemoteConfig remoteConfig;

String uriPrefix = 'https://meetinghelper.page.link';
enum DayListType { Meeting, Kodas, Tanawol }
enum PhoneCallAction { AddToContacts, Call, Message, Whatsapp }
