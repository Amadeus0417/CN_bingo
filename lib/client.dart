import 'package:cn_bingo/main.dart';
import 'package:flutter/material.dart';
import 'tcp_socket.dart';

class ClientPage extends StatefulWidget {
  @override
  _ClientPageState createState() => _ClientPageState();
}

class _ClientPageState extends State<ClientPage> {
  TextEditingController ipAddressController = TextEditingController(text: '10.0.2.2');
  TextEditingController portController = TextEditingController(text: '6000');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('設定客戶端'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: ipAddressController,
              decoration: InputDecoration(
                labelText: 'IP Address',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: portController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Port Number',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ElevatedButton(
                  onPressed: () {
                    // 按下“加入”按鈕时的处理逻辑
                    String ip = ipAddressController.text;
                    int port = int.tryParse(portController.text) ?? 6000;
                    TcpClient tcpClient = TcpClient();
                    // 连接到服务器
                    tcpClient.connectToServer(ip, port).then((_) {
                      // 跳转到 PlayerPage
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => PlayerPage(tcpClient: tcpClient)),
                      );
                    }).catchError((error) {
                      // 连接失败时的处理逻辑
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('连接失败'),
                          content: Text('无法连接到服务器：$error'),
                          actions: <Widget>[
                            TextButton(
                              child: Text('确定'),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        ),
                      );
                    });
                  },
                  child: Text('加入'),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () {
                    // 按下“返回”按鈕時的處理邏輯
                    Navigator.pop(context);
                  },
                  child: Text('返回'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PlayerPage extends StatefulWidget {
  final TcpClient tcpClient;

  PlayerPage({required this.tcpClient});

  @override
  _PlayerPageState createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  List<int> numbers = List.generate(25, (index) => index + 1);
  List<int> gridData = List.generate(25, (index) => index + 1);
  List<int> gridHighlighted = List.filled(25, 0);
  bool isRandom = false;
  String serverMessage = '';
  bool canMoveNumbers = true;
  int connectedCount = 0;

  @override
  void initState() {
    super.initState();
    _resetGridData();
    _setupListener();
  }

  @override
  void dispose() {
    widget.tcpClient.disconnect();
    super.dispose();
  }

  void _highlightNumber(int number) {
    int index = gridData.indexOf(number);
    if (index != -1) {
      setState(() {
        if (gridHighlighted[index] == 0) {
          gridHighlighted[index] = 1; // Mark as received but not connected (orange)
        }
      });
    }
  }

  void _setupListener() {
    widget.tcpClient.messageStream.listen((String message) {
      setState(() {
        serverMessage = message;
        if (serverMessage == "game_start") {
          canMoveNumbers = false; // 收到 "game_start" 消息后禁止移动数字方格
        } else if (serverMessage == "game_end") {
          _handleGameEnd();
        } else if (serverMessage.startsWith('winner:')) {
          // Handle multiple winners
          List<String> winnerMessages = serverMessage.split(',');
          List<int> winnerIds = [];
          winnerMessages.forEach((winnerMessage) {
            if (winnerMessage.startsWith('winner:')) {
              int winnerId = int.tryParse(winnerMessage.split(':')[1]) ?? 0;
              if (winnerId != 0) {
                winnerIds.add(winnerId);
              }
            }
          });
          if (winnerIds.isNotEmpty) {
            Future.delayed(Duration(milliseconds: 250), () {
              _showWinnerDialog(winnerIds);
            });
          }
        } else {
          int receivedNumber = int.tryParse(serverMessage) ?? -1;
          if (receivedNumber != -1) {
            _highlightNumber(receivedNumber);
            _checkBingo();
          }
        }
      });
    });
  }

  void _showWinnerDialog(List<int> winnerIds) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('遊戲結束'),
          content: Text('玩家 ${winnerIds.join(', ')} 已獲勝!'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                widget.tcpClient.sendMessage('ready_for_new_game');
                _resetGameState(); // 重置游戏状态
                Navigator.pop(context); // 关闭对话框
              },
              child: Text('再來一局'),
            ),
            TextButton(
              onPressed: () {
                // 按下“離開遊戲”按鈕时的处理逻辑
                widget.tcpClient.disconnect().then((_) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => HomePage()),
                        (route) => false,
                  );
                });
              },
              child: Text('離開遊戲'),
            ),
          ],
        );
      },
    );
  }

  void _resetGameState() {
    setState(() {
      numbers = List.generate(25, (index) => index + 1);
      gridData = List.generate(25, (index) => index + 1);
      gridHighlighted = List.filled(25, 0);
      isRandom = false;
      canMoveNumbers = true;
      connectedCount = 0;
      serverMessage = '';
    });
  }

  void _handleGameEnd() {
    widget.tcpClient.disconnect().then((_) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('主持人已離開'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => HomePage()),
                      (route) => false,
                );
              },
              child: Text('確定'),
            ),
          ],
        ),
      );
    });
  }

  void _resetGridData() {
    setState(() {
      if (isRandom) {
        _generateRandomNumbers();
      } else {
        gridData = List.generate(25, (index) => index + 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('玩家頁面'),
      ),
      body: Center(
        child: Column(
          children: <Widget>[
            SizedBox(height: 20),
            Text(
              '來自服務器的消息：$serverMessage',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            Expanded(
              child: Center(
                child: GridView.builder(
                  shrinkWrap: true,
                  itemCount: numbers.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 8.0,
                    crossAxisSpacing: 8.0,
                    childAspectRatio: 1.2,
                  ),
                  itemBuilder: (context, index) {
                    return _buildGridItem(index);
                  },
                ),
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ElevatedButton(
                  onPressed: canMoveNumbers
                      ? () {
                    setState(() {
                      isRandom = true;
                      _generateRandomNumbers();
                    });
                  }
                  : null,
                  child: Text('隨機產生'),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () {
                    // 按下“離開遊戲”按鈕时的处理逻辑
                    widget.tcpClient.disconnect().then((_) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => HomePage()),
                            (route) => false,
                      );
                    });
                  },
                  child: Text('離開遊戲'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridItem(int index) {
    Color color;
    switch (gridHighlighted[index]) {
      case 0:
        color = Colors.grey; // 未收到，灰色
        break;
      case 1:
        color = Colors.orange; // 收到未连接，橘色
        break;
      case 2:
        color = Colors.red; // 已连接，红色
        break;
      default:
        color = Colors.grey; // 默认灰色
        break;
    }

    return Draggable<int>(
      data: index,
      feedback: Material(
        elevation: 8.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        color: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Center(
            child: Text(
              '${gridData[index]}',
              style: TextStyle(fontSize: 20.0, color: Colors.white),
            ),
          ),
        ),
      ),
      child: DragTarget<int>(
        builder: (BuildContext context, List<int?> data, List<dynamic> rejectedData) {
          return Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Center(
              child: Text(
                '${gridData[index]}',
                style: TextStyle(fontSize: 20.0, color: Colors.white),
              ),
            ),
          );
        },
        onWillAccept: (int? fromIndex) => canMoveNumbers,
        onAccept: (int? fromIndex) {
          setState(() {
            _reorderNumbers(fromIndex!, index);
          });
        },
      ),
    );
  }

  void _checkBingo() {
    connectedCount = 0;
    // Check rows
    for (int i = 0; i < 5; i++) {
      int index1 = i * 5;
      int index2 = i * 5 + 1;
      int index3 = i * 5 + 2;
      int index4 = i * 5 + 3;
      int index5 = i * 5 + 4;

      _checkLine(index1, index2, index3, index4, index5);
    }

    // Check columns
    for (int i = 0; i < 5; i++) {
      int index1 = i;
      int index2 = i + 5;
      int index3 = i + 10;
      int index4 = i + 15;
      int index5 = i + 20;

      _checkLine(index1, index2, index3, index4, index5);
    }

    // Check diagonals
    _checkLine(0, 6, 12, 18, 24);
    _checkLine(4, 8, 12, 16, 20);

    // Send playerId and connectedCount to server
    String message = 'id_and_conn:${widget.tcpClient.playerId},$connectedCount';
    widget.tcpClient.sendMessage(message);
  }

  void _checkLine(int index1, int index2, int index3, int index4, int index5) {
    if (gridHighlighted[index1] >= 1 &&
        gridHighlighted[index2] >= 1 &&
        gridHighlighted[index3] >= 1 &&
        gridHighlighted[index4] >= 1 &&
        gridHighlighted[index5] >= 1) {
      _markBingo(index1, index2, index3, index4, index5);
      connectedCount++;
    }
  }

  void _markBingo(int index1, int index2, int index3, int index4, int index5) {
    setState(() {
      gridHighlighted[index1] = 2; // Mark as connected (red)
      gridHighlighted[index2] = 2; // Mark as connected (red)
      gridHighlighted[index3] = 2; // Mark as connected (red)
      gridHighlighted[index4] = 2; // Mark as connected (red)
      gridHighlighted[index5] = 2; // Mark as connected (red)
    });
  }

  void _generateRandomNumbers() {
    numbers.shuffle();
    gridData = List.from(numbers);
  }

  void _reorderNumbers(int fromIndex, int toIndex) {
    if (fromIndex != toIndex) {
      setState(() {
        int fromData = gridData[fromIndex];
        gridData[fromIndex] = gridData[toIndex];
        gridData[toIndex] = fromData;
      });
    }
  }
}

