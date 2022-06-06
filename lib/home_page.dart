import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage(
      {Key? key, this.listenHost = "Any", this.listenPort = "8081"})
      : super(key: key);
  final String listenHost;
  final String listenPort;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final TextEditingController hostC; // 目标主机
  late final TextEditingController portC; // 目标端口
  late final TextEditingController listenHostC; // 监听主机
  late final TextEditingController listenPortC; // 监听端口
  late final TextEditingController commandC;
  RawDatagramSocket? udpSocket;
  StreamSubscription? subscription;
  String receivedHost = ""; // 收到数据包的主机
  String receivedPort = ""; // 收到数据包的端口
  final String anyHost = "Any"; // Any 代表监听任何IP

  List<String> dataList = []; // 收到的数据集合
  final List<String> commandList = const [
    "AT+TEST",
    "AT+GETLINK",
    'AT+GMR?',
    "AT+FR",
    "AT+MAC?",
    "AT+BATTERY?",
    "AT+BEEP=ON",
    "AT+BEEP=OFF",
    "AT+UPDATEMODE=0,5",
    "AT+GPSLOCATION=ON",
    "AT+GPSLOCATION=OFF",
    "AT+WIFILOCATION=ON",
    "AT+WIFILOCATION=OFF",
    "AT+TAKINGPIC=VGA,63,0,2",
    "AT+SETWIFI=SinovoDev,ZYG13632808272.",
    "AT+SETWIFI=SinovoGW_R,enmvxcte",
    "AT+HOSTPOT=phone,123456",
    "AT+OTA=https://gws.qiksmart.com/W901-V1.0.bin",
    "AT+OTA=https://gws.qiksmart.com/W901-V1.1.bin",
  ];

  late Color targetColor; // 红色异常提示
  late Color listenColor; // 红色异常提示

  @override
  void initState() {
    hostC = TextEditingController(text: '255.255.255.255');
    portC = TextEditingController(text: '8080');
    listenHostC = TextEditingController(text: widget.listenHost);
    listenPortC = TextEditingController(text: widget.listenPort);
    commandC = TextEditingController(text: 'AT+GMR?');
    targetColor = Colors.black;
    listenColor = Colors.black;
    rawDatagramSocketListener();
    super.initState();
  }

  void rawDatagramSocketListener() async {
    subscription = null;
    udpSocket = null;
    InternetAddress listenAddress;
    int listenPort;
    try {
      listenAddress = listenHostC.text.trim() == anyHost
          ? InternetAddress.anyIPv4
          : InternetAddress.tryParse(listenHostC.text.trim())!;
      listenPort = int.tryParse(listenPortC.text.trim())!;
      udpSocket =
          await RawDatagramSocket.bind(listenAddress.address, listenPort);
      udpSocket?.broadcastEnabled = true;
      setState(() {
        listenColor = Colors.black;
      });
    } catch (e) {
      udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 8080);
      udpSocket?.broadcastEnabled = true;
      debugPrint("监听错误，已设置回默认值，" + e.toString());
      setState(() {
        listenColor = Colors.red;
      });
    }

    subscription = udpSocket?.listen((e) {
      Datagram? dg = udpSocket?.receive();
      if (dg != null) {
        String receivedData = String.fromCharCodes(dg.data);
        debugPrint(
            "接收--> address: ${dg.address} , port: ${dg.port} , receivedData: $receivedData , CharCodes: ${dg.data}");
        setState(() {
          receivedHost = dg.address.address;
          receivedPort = dg.port.toString();
        });
        if (!receivedData.contains("AT") || receivedData.length > 100) {
          // 包含 "AT" 是我们的指令，长度大于100视为图片数据
          setState(() {
            dataList.add(receivedData);
          });
        }
      }
    });
  }

  void sendUDPPacket() {
    InternetAddress sendAddress;
    int sendPort;
    String command = commandC.text.trim();
    List<int> data = utf8.encode(command);
    try {
      sendAddress = InternetAddress.tryParse(hostC.text.trim())!; // IP
      sendPort = int.tryParse(portC.text.trim())!; // Port
      udpSocket?.send(data, sendAddress, sendPort);
      setState(() {
        targetColor = Colors.black;
      });
    } catch (e) {
      sendAddress = InternetAddress.anyIPv4;
      sendPort = 8080;
      udpSocket?.send(data, sendAddress, sendPort);
      debugPrint("发包错误，已设置回默认值，" + e.toString());
      setState(() {
        targetColor = Colors.red;
      });
    }

    debugPrint(
        "发送--> address: $sendAddress , port: $sendPort , command: $command");
  }

  @override
  void dispose() {
    hostC.dispose();
    portC.dispose();
    listenHostC.dispose();
    listenPortC.dispose();
    commandC.dispose();
    subscription?.cancel();
    udpSocket?.close();
    super.dispose();
  }

  Widget imageWidget(String base64Url, int index) {
    try {
      Uint8List bytes = const Base64Decoder().convert(base64Url);
      return Image.memory(bytes, filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) {
        TextEditingController controller =
            TextEditingController(text: base64Url);
        return TextField(
          controller: controller,
          maxLines: 5,
        );
      });
    } catch (e) {
      TextEditingController controller = TextEditingController(text: base64Url);
      return TextField(
        controller: controller,
        maxLines: 5,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("W901-Tester"),
      ),
      body: Column(
        children: <Widget>[
          const Text("网络数据接收：",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                decoration: BoxDecoration(border: Border.all()),
                child: ListView.builder(
                    padding: const EdgeInsets.only(left: 5, top: 5),
                    itemCount: dataList.length,
                    itemBuilder: (ctx, index) {
                      String data = dataList[index];
                      String per2 = data.substring(0, 2);
                      if (per2.contains(per2) && data.length > 100) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 5.0),
                          child: imageWidget(data, index),
                        );
                      } else {
                        return Text("$index：" + data.toString());
                      }
                    }),
              )),
          Expanded(
              flex: 2,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 5.0),
                          child: Text("监听主机：",
                              style: TextStyle(color: listenColor)),
                        ),
                        Expanded(
                            flex: 2,
                            child: SizedBox(
                                height: 30,
                                child: TextField(
                                  controller: listenHostC,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      contentPadding:
                                          EdgeInsets.only(top: 12, left: 5),
                                      border: OutlineInputBorder()),
                                ))),
                        const SizedBox(width: 10),
                        Padding(
                          padding: const EdgeInsets.only(top: 5.0),
                          child:
                              Text("端口：", style: TextStyle(color: listenColor)),
                        ),
                        Expanded(
                            child: SizedBox(
                                height: 30,
                                child: TextField(
                                  controller: listenPortC,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      contentPadding:
                                          EdgeInsets.only(top: 12, left: 5),
                                      border: OutlineInputBorder()),
                                ))),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 3.0),
                            child: Text("目标主机：",
                                style: TextStyle(color: targetColor)),
                          ),
                          Expanded(
                              flex: 2,
                              child: SizedBox(
                                  height: 30,
                                  child: TextField(
                                    controller: hostC,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        contentPadding:
                                            EdgeInsets.only(top: 12, left: 5),
                                        border: OutlineInputBorder()),
                                  ))),
                          const SizedBox(width: 10),
                          Padding(
                            padding: const EdgeInsets.only(top: 5.0),
                            child: Text("端口：",
                                style: TextStyle(color: targetColor)),
                          ),
                          Expanded(
                              child: SizedBox(
                                  height: 30,
                                  child: TextField(
                                    controller: portC,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        contentPadding:
                                            EdgeInsets.only(top: 12, left: 5),
                                        border: OutlineInputBorder()),
                                  ))),
                        ],
                      ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.only(top: 8.0, left: 3, right: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text("数据包主机："),
                          Expanded(child: Text(receivedHost)),
                          const SizedBox(width: 10),
                          const Text("端口："),
                          Expanded(child: Text(receivedPort)),
                        ],
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                            flex: 2,
                            child: Container(
                                margin: const EdgeInsets.only(top: 10),
                                child: TextField(
                                  controller: commandC,
                                  keyboardType: TextInputType.text,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                      contentPadding: EdgeInsets.all(10),
                                      border: OutlineInputBorder()),
                                ))),
                        Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: OutlinedButton(
                                  style: ButtonStyle(
                                      backgroundColor:
                                          MaterialStateProperty.all(
                                              Colors.orangeAccent)),
                                  onPressed: () {
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => MyHomePage(
                                          listenHost: listenHostC.text.trim(),
                                          listenPort: listenPortC.text.trim(),
                                        ),
                                      ),
                                      (route) => false,
                                    );
                                  },
                                  child: const Text(
                                    "监听",
                                    style: TextStyle(color: Colors.white),
                                  )),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: OutlinedButton(
                                  style: ButtonStyle(
                                      backgroundColor:
                                          MaterialStateProperty.all(
                                              Colors.green)),
                                  onPressed: sendUDPPacket,
                                  child: const Text(
                                    "发送",
                                    style: TextStyle(color: Colors.white),
                                  )),
                            ),
                          ],
                        )
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PopupMenuButton<String>(
                          onSelected: (v) {
                            setState(() {
                              commandC.text = v.trim();
                            });
                          },
                          child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: Colors.lightBlueAccent,
                                  border: Border.all()),
                              child: const Text("现有命令",
                                  style: TextStyle(color: Colors.white))),
                          itemBuilder: (context) {
                            return commandList
                                .map((v) {
                                  return CheckedPopupMenuItem(
                                    value: v,
                                    checked: commandC.text.trim() == v,
                                    child: Text(v),
                                  );
                                })
                                .toList()
                                .cast();
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: OutlinedButton(
                              style: ButtonStyle(
                                  backgroundColor:
                                      MaterialStateProperty.all(Colors.red)),
                              onPressed: () {
                                setState(() {
                                  dataList.clear();
                                });
                              },
                              child: const Text(
                                "清空",
                                style: TextStyle(color: Colors.white),
                              )),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
