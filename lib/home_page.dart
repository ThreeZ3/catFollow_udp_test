import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final TextEditingController hostC;
  late final TextEditingController portC;
  late final TextEditingController commandC;
  late final RawDatagramSocket udpSocket;
  late final StreamSubscription subscription;
  List<String> dataList = [];
  List<String> commandList = [
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

  @override
  void initState() {
    hostC = TextEditingController(text: '255.255.255.255');
    portC = TextEditingController(text: '8080');
    commandC = TextEditingController(text: 'AT+GMR?');
    rawDatagramSocketListener();
    super.initState();
  }

  void rawDatagramSocketListener() async {
    // InternetAddress address = InternetAddress.tryParse('255.255.255.255') ?? InternetAddress.anyIPv4;
    udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 8080);
    udpSocket.broadcastEnabled = true;

    subscription = udpSocket.listen((e) {
      Datagram? dg = udpSocket.receive();
      if (dg != null) {
        String receivedData = String.fromCharCodes(dg.data);
        if (kDebugMode) {
          print(
              "接收--> address: ${dg.address} , port: ${dg.port} , receivedData: $receivedData , CharCodes: ${dg.data}");
        }
        if (!receivedData.contains("AT") || receivedData.length > 100) {
          setState(() {
            dataList.add(receivedData);
          });
        }
      }
    });
  }

  void sendUDPPacket() {
    String myAddress = hostC.text.trim();
    int myPort = int.tryParse(portC.text) ?? 8080;
    String command = commandC.text.trim();
    List<int> data = utf8.encode(command);
    InternetAddress internetAddress =
        InternetAddress.tryParse(myAddress) ?? InternetAddress.anyIPv4;
    udpSocket.send(data, internetAddress, myPort);
    if (kDebugMode) {
      print(
          "发送--> address: ${udpSocket.address.address} , port: ${udpSocket.port} , command: $command");
    }
  }

  @override
  void dispose() {
    hostC.dispose();
    portC.dispose();
    commandC.dispose();
    subscription.cancel();
    udpSocket.close();
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
              flex: 2,
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
              child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 5.0),
                      child: Text("目标主机："),
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
                    const Padding(
                      padding: EdgeInsets.only(top: 5.0),
                      child: Text("端口："),
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
                                      MaterialStateProperty.all(Colors.green)),
                              onPressed: sendUDPPacket,
                              child: const Text(
                                "发送",
                                style: TextStyle(color: Colors.white),
                              )),
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
                    )
                  ],
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    setState(() {
                      commandC.text = v.trim();
                    });
                  },
                  child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.lightBlueAccent, border: Border.all()),
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
              ],
            ),
          )),
        ],
      ),
    );
  }
}
