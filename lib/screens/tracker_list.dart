import 'package:cartracker/data/tracker.dart';
import 'package:cartracker/database/database.dart';
import 'package:cartracker/database/tracker_db.dart';
import 'package:cartracker/screens/tracker_edit.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

class TrackerListScreen extends StatefulWidget {
  const TrackerListScreen({Key? key}) : super(key: key);

  @override
  State<TrackerListScreen> createState() {
    return TrackerListScreenState();
  }
}

class TrackerListScreenState extends State<TrackerListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: () async {
          Database? db = await DataBase.get();
          return TrackerDB.list(db!);
        }(),
        builder: (BuildContext context, AsyncSnapshot<List<Tracker>> entries) {
          if (entries.data == null) {
            return const SizedBox();
          }

          return ListView.builder(
              padding: const EdgeInsets.all(0),
              itemCount: entries.data!.length,
              itemBuilder: (BuildContext context, int index) {
                return SizedBox(
                    height: 80,
                    child: ListTile(
                      leading: const Icon(Icons.gps_fixed, size:40.0),
                      title: Text(entries.data![index].name),
                      subtitle: Text(entries.data![index].uuid),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) {
                          return TrackerEditScreen(entries.data![index]);
                        }));
                      },
                    )
                );
              }
          );
        }
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          Tracker tracker = Tracker();
          Database? db = await DataBase.get();
          await TrackerDB.add(db!, tracker);

          Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) {
             return TrackerEditScreen(tracker);
          }));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}