import 'package:flutter/material.dart';
import 'package:flutter_beep/flutter_beep.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/pages/item_page.dart';
import 'package:shia_companion/pages/list_items.dart';

import '../constants.dart';

class TasbeehWidget extends StatefulWidget {
  @override
  _TasbeehWidgetState createState() => _TasbeehWidgetState();
}

class _TasbeehWidgetState extends State<TasbeehWidget> {
  int counter = 0;

  bool isChecked = true;
  TextEditingController controller1, controller2, controller3;

  @override
  void initState() {
    counter = sharedPreferences.getInt("count") ?? 0;
    controller1 = TextEditingController(text: "34");
    controller2 = TextEditingController(text: "67");
    controller3 = TextEditingController(text: "100");
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Tasbeeh Counter"),
      ),
      body: InkWell(
        onTap: () {
          counter++;
          if (isChecked &&
              (counter == int.parse(controller1.text) ||
                  counter == int.parse(controller2.text) ||
                  counter == int.parse(controller3.text))) {
            FlutterBeep.beep();
          }
          setState(() {});
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Checkbox(
                    value: isChecked,
                    onChanged: (v) {
                      setState(() {
                        isChecked = v;
                      });
                    },
                  ),
                  Text("Enable beep"),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextFormField(
                        keyboardType: TextInputType.number,
                        controller: controller1,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextFormField(
                        keyboardType: TextInputType.number,
                        controller: controller2,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextFormField(
                        keyboardType: TextInputType.number,
                        controller: controller3,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                    child: Text("$counter",
                        style: Theme.of(context).textTheme.headline2)),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                      onPressed: () {
                        setState(() {
                          if (counter > 0) counter--;
                        });
                      },
                      child: Text("MINUS ONE")),
                  ElevatedButton(
                      onPressed: () {
                        setState(() {
                          counter = 0;
                        });
                      },
                      child: Text("RESET")),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildZikrRow(BuildContext context, UidTitleData itemData) {
    return InkWell(
      onTap: () {
        if (itemData.getUId().contains("~")) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      ItemList(itemData.getUId().split("~")[1])));
        } else {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => ItemPage(itemData)));
        }
      },
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(itemData.title),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() async {
    super.dispose();
    await sharedPreferences.setInt("count", counter);
  }
}
