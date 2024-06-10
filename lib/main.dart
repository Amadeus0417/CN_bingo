import 'package:flutter/material.dart';
import 'client.dart';
import 'host.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('主畫面'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: () {
                // 按下“創建遊戲”按鈕時的處理邏輯
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => HostPage()),
                );
              },
              child: Text('創建遊戲'),
            ),
            SizedBox(height: 20), // 加一個間距
            ElevatedButton(
              onPressed: () {
                // 按下“加入遊戲”按鈕時的處理邏輯
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ClientPage()),
                );
              },
              child: Text('加入遊戲'),
            ),
            SizedBox(height: 20), // 加一個間距
            ElevatedButton(
              onPressed: () {
                // 按下“結束遊戲”按鈕時的處理邏輯
                Navigator.of(context).pop(); // 關閉主畫面
              },
              child: Text('結束遊戲'),
            ),
          ],
        ),
      ),
    );
  }
}
