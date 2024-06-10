import 'dart:async';

import 'package:flutter/material.dart';
import 'main.dart';
import 'tcp_socket.dart';

class HostPage extends StatefulWidget {
  @override
  _HostPageState createState() => _HostPageState();
}

class _HostPageState extends State<HostPage> {
  TextEditingController _ipController = TextEditingController(text: '10.0.2.15');
  TextEditingController _portController = TextEditingController(text: '4000');
  late TcpServer tcpServer;

  @override
  void initState() {
    super.initState();
    tcpServer = TcpServer();
  }

  Future<void> _createGame() async {
    String ip = _ipController.text;
    int port = int.parse(_portController.text);
    await tcpServer.startServer(ip, port);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => WaitingPage(tcpServer: tcpServer)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('設定主機'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: _ipController,
              decoration: InputDecoration(
                labelText: 'IP Address',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _portController,
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
                  onPressed: _createGame,
                  child: Text('創建'),
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

class WaitingPage extends StatefulWidget {
  final TcpServer tcpServer;

  WaitingPage({required this.tcpServer});

  @override
  _WaitingPageState createState() => _WaitingPageState();
}

class _WaitingPageState extends State<WaitingPage> {
  late StreamSubscription<int> _clientCountSubscription;
  int _clientCount = 0;

  @override
  void initState() {
    super.initState();
    _clientCount = widget.tcpServer.getClientCount();
    _clientCountSubscription = widget.tcpServer.clientCountStream.listen((count) {
      setState(() {
        _clientCount = count;
      });
    });
  }

  @override
  void dispose() {
    _clientCountSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('等待中'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            StreamBuilder<int>(
              stream: widget.tcpServer.clientCountStream,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text('當前玩家數量：${snapshot.data}');
                } else {
                  return Text('當前玩家數量：$_clientCount');
                }
              },
            ),
            ElevatedButton(
              onPressed: _startGame,
              child: Text('開始遊戲'),
            ),
            ElevatedButton(
              onPressed: _returnToMainPage,
              child: Text('返回主畫面'),
            ),
          ],
        ),
      ),
    );
  }

  void _startGame() {
    widget.tcpServer.sendGameStartMessage();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GamePage(
          tcpServer: widget.tcpServer,
        ),
      ),
    );
  }

  void _returnToMainPage() {
    widget.tcpServer.stopServer(); // 关闭TCP连接

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => HomePage()),
          (route) => false,
    );
  }
}

class GamePage extends StatefulWidget {
  final TcpServer tcpServer;

  GamePage({required this.tcpServer});

  @override
  _GamePageState createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  List<int> numbers = List.generate(25, (index) => index + 1);
  int selectedNumber = -1;
  List<int> sentNumbers = [];
  int _clientCount = 0;
  late StreamSubscription<int> _clientCountSubscription;
  Map<int, int> playerInfoMap = {};

  @override
  void initState() {
    super.initState();
    _clientCount = widget.tcpServer.getClientCount();
    _clientCountSubscription = widget.tcpServer.clientCountStream.listen((count) {
      setState(() {
        _clientCount = count;
      });
    });
    _setupListener();
  }

  void _setupListener() {
    widget.tcpServer.messageStream.listen((String message) {
      if (message.startsWith('id_and_conn')) {
        String data = message.split(':')[1];
        List<String> parts = data.split(',');
        if (parts.length == 2) {
          int playerId = int.tryParse(parts[0]) ?? -1;
          int connectedCount = int.tryParse(parts[1]) ?? 0;
          if (playerId != -1) {
            _updatePlayerInfo(playerId, connectedCount);
            if (connectedCount >= 5) {
              widget.tcpServer.sendToAllClients('winner:$playerId,');
            }
          }
        }
      }
    });
  }

  void _updatePlayerInfo(int playerId, int connectedCount) {
    setState(() {
      playerInfoMap[playerId] = connectedCount;
    });

    // Check if any player's connectedCount is 5 or more
    List<int> winners = [];
    playerInfoMap.forEach((playerId, connectedCount) {
      if (connectedCount >= 5) {
        winners.add(playerId);
      }
    });

    if (winners.isNotEmpty) {
      Future.delayed(Duration(milliseconds: 250), () {
        print('players $winners won');
        _showWinnerDialog(winners);
      });
    }
  }


  void _showWinnerDialog(List<int> winnerIds) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('玩家 ${winnerIds.join(', ')} 已獲勝!'),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              _resetGameState(); // 重置游戏状态
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => WaitingPage(tcpServer: widget.tcpServer)),
                    (route) => false,
              );
            },
            child: Text('再來一局'),
          ),
          TextButton(
            onPressed: () {
              _sendGameEndMessageToClients();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => HomePage()),
                    (route) => false,
              );
            },
            child: Text('結束遊戲'),
          ),
        ],
      ),
    );
  }

  void _resetGameState() {
    setState(() {
      numbers = List.generate(25, (index) => index + 1);
      selectedNumber = -1;
      sentNumbers.clear();
      playerInfoMap.clear();
    });
  }

  void _sendNumberToClients(int number) {
    String message = '$number';
    widget.tcpServer.sendToAllClients(message);
  }

  void _sendGameEndMessageToClients() {
    widget.tcpServer.sendToAllClients("game_end");
    widget.tcpServer.stopServer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('遊戲進行中'),
      ),
      body: Column(
        children: <Widget>[
          StreamBuilder<int>(
            stream: widget.tcpServer.clientCountStream,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Text('當前玩家數量：${snapshot.data}');
              } else {
                return Text('當前玩家數量：$_clientCount');
              }
            },
          ),
          Expanded(
            child: Center(
              child: Container(
                padding: EdgeInsets.all(8.0),
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
                    bool isSent = sentNumbers.contains(numbers[index]);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (!isSent) {
                            selectedNumber = numbers[index];
                          } else {
                            selectedNumber = -1;
                          }
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: selectedNumber == numbers[index]
                              ? Colors.green
                              : isSent
                              ? Colors.orange
                              : Colors.grey,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Center(
                          child: Text(
                            '${numbers[index]}',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20.0,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ElevatedButton(
                  onPressed: selectedNumber != -1 && !sentNumbers.contains(selectedNumber)
                      ? () {
                    setState(() {
                      sentNumbers.add(selectedNumber);
                    });
                    _sendNumberToClients(selectedNumber);
                    selectedNumber = -1;
                  }
                      : null,
                  child: Text('發送'),
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.resolveWith<Color>(
                          (Set<MaterialState> states) {
                        if (states.contains(MaterialState.disabled)) {
                          return Colors.grey;
                        }
                        return Colors.orange;
                      },
                    ),
                  ),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () {
                    // 按下“結束”按鈕時的處理邏輯
                    _sendGameEndMessageToClients();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: Text('結束'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}