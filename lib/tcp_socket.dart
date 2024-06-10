import 'dart:io';

import 'dart:async';

class TcpServer {
  late ServerSocket _serverSocket;
  List<Socket> _clients = [];
  final StreamController<int> _clientCountController = StreamController<int>.broadcast();
  Stream<int> get clientCountStream => _clientCountController.stream;

  final StreamController<String> _messageController = StreamController<String>.broadcast();
  Stream<String> get messageStream => _messageController.stream;

  int _playerIdCounter = 1; // Player ID counter starting from 1
  Set<int> readyClients = {}; // Track clients ready for a new game

  Future<void> startServer(String address, int port) async {
    _serverSocket = await ServerSocket.bind(address, port);
    _serverSocket.listen((Socket socket) {
      _clients.add(socket);
      _clientCountController.add(_clients.length);

      // Assign playerId to this client
      int playerId = _playerIdCounter++;
      print('Assigned playerId $playerId to client ${_clients.length}');
      socket.write('playerId:$playerId\n'); // Send playerId to client

      socket.listen(
            (data) {
          // Handle data from the client
              String receivedMessage = String.fromCharCodes(data).trim();
              print('Received from client: $receivedMessage');
              _handleReceivedMessage(receivedMessage, playerId);
        },
        onDone: () {
          _clients.remove(socket);
          _clientCountController.add(_clients.length);
        },
      );
    });
  }

  void stopServer() {
    for (var client in _clients) {
      client.close();
    }
    _serverSocket.close();
    _clients.clear();
    _clientCountController.add(_clients.length);
  }

  void sendToAllClients(String message) {
    _clients.forEach((client) {
      client.write(message);
    });
  }

  void sendGameStartMessage() {
    sendToAllClients("game_start");
  }

  void _handleReceivedMessage(String message, int playerId) {
    if (message.startsWith('ready_for_new_game:')) {
      // 处理客户端准备好进行新游戏的消息
      readyClients.add(playerId);
      if (readyClients.length == _clients.length) {
        // 如果所有客户端都准备好了，则开始新游戏
        readyClients.clear();
        sendGameStartMessage();
      }
    } else {
      // 处理其他消息
      _messageController.add(message);
    }
  }

  void sendGameEndMessage() {
    sendToAllClients("game_end");
  }

  int getClientCount() {
    return _clients.length;
  }
}

class TcpClient {
  Socket? socket;
  int playerId = -1;
  StreamController<String> _messageController = StreamController<String>.broadcast();

  Stream<String> get messageStream => _messageController.stream;

  // 连接到服务器
  Future<void> connectToServer(String ip, int port) async {
    socket = await Socket.connect(ip, port);
    print('Connected to server: $ip:$port');
    socket!.listen(
          (data) {
            String message = String.fromCharCodes(data);
            print('Received data: $message');
            _messageController.add(message);
            // Extract playerId from message
            if (message.startsWith('playerId:')) {
              playerId = int.tryParse(message.substring(9).trim()) ?? -1;
              print('playerId set as $playerId');
            } else if (message.startsWith('winner:')){

            }
      },
      onDone: () {
        print('Server disconnected');
      },
    );
  }

  // 发送消息到服务器
  void sendMessage(String message) {
    socket?.write(message);
  }

  // 断开与服务器的连接
  Future<void> disconnect() async {
    await socket?.close();
    _messageController.close();
    print('Disconnected from server');
  }
}