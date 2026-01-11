import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import '../utils/shared_preferences.dart';

class TasbeehWidget extends StatefulWidget {
  @override
  _TasbeehWidgetState createState() => _TasbeehWidgetState();
}

class _TasbeehWidgetState extends State<TasbeehWidget> {
  int counter = 0;

  bool isChecked = true;
  late TextEditingController controller1, controller2, controller3;

  @override
  void initState() {
    counter = SP.prefs.getInt("count") ?? 0;
    controller1 = TextEditingController(text: "34");
    controller2 = TextEditingController(text: "67");
    controller3 = TextEditingController(text: "100");
    super.initState();
    trackScreen('Tasbeeh Page');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Tap anywhere to start")));
      }
    });
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
            SystemSound.play(SystemSoundType.click);
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
                      if (v != null) {
                        setState(() {
                          isChecked = v;
                        });
                      }
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
                        style: Theme.of(context).textTheme.displayMedium)),
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

  @override
  void dispose() async {
    super.dispose();
    await SP.prefs.setInt("count", counter);
  }
}
