import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() {
    return SettingsScreenState();
  }
}

class SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: const <Widget>[
          // TODO <ADD CODE HERE>
        ],
      ),
    );
  }
}