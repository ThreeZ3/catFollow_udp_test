import 'dart:convert';
import 'dart:io';

class Api {
  static var ip = "192.168.3.100";
  static int tcpPort = 8888;
}

class SocketManage {
  static late Socket _socket;

  // 建立连接
  static void connectSocket() async {
    await Socket.connect(
      Api.ip,
      Api.tcpPort,
      timeout: const Duration(seconds: 5),
    ).then((Socket socket) {
      _socket = socket;
      _socket.listen(onData,
          onError: onError, onDone: onDone, cancelOnError: false); // 订阅流
    }).catchError((e) {
      print("Unable to connect: $e");
      connectSocket(); // 连接超时，重新建立连接
    });
  }

  // 收到消息回调
  static void onData(event) {
    String str = utf8.decode(event);
    print("---onData---$str");
  }

  // 收到错误回调
  static void onError(err) {
    print("---onError---");
  }

  // 断开回调
  static void onDone() {
    Future.delayed(Duration(milliseconds: 2000), () {
      connectSocket(); // 重新建立连接
    });

    print("---onDone---");
  }

  // 发数据
  static void writeData(Object object) {
    _socket.write(object);
  }

  // 关闭流通道
  static void socketClose() {
    _socket.close();
  }
}
