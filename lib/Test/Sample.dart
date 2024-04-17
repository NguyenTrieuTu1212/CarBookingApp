/*
import 'package:flutter/material.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

class PanelButton extends StatefulWidget {
  @override
  _PanelButtonState createState() => _PanelButtonState();
}

class _PanelButtonState extends State<PanelButton> {
  double _panelPosition = 0.0; // Vị trí của Sliding Up Panel, mặc định là 0.0 (đóng)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sliding Up Panel Button Example'),
      ),
      body: SlidingUpPanel(
        onPanelSlide: (double position) {
          setState(() {
            _panelPosition = position;
          });
        },
        body: Center(
          child: Text('Main Content'),
        ),
        panel: Center(
          child: Text('Panel Content'),
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _panelPosition,
        builder: (context, child) {
          // Duyệt qua trục Y của Sliding Up Panel và tính toán vị trí của nút
          double buttonPosition = MediaQuery.of(context).size.height * (1 - _panelPosition) - 50.0;
          return Positioned(
            bottom: buttonPosition,
            right: 20.0,
            child: FloatingActionButton(
              onPressed: () {
                // Xử lý sự kiện khi nút được nhấn
                print('Button pressed!');
              },
              child: Icon(Icons.add),
            ),
          );
        },
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: PanelButton(),
  ));
}
*/
