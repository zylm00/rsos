import 'dart:async';
import 'dart:convert';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:provider/provider.dart';

class DesktopHomePage extends StatefulWidget {
  const DesktopHomePage({Key? key}) : super(key: key);

  @override
  State<DesktopHomePage> createState() => _DesktopHomePageState();
}

class _DesktopHomePageState extends State<DesktopHomePage>
    with WidgetsBindingObserver {
  Timer? _updateTimer;
  final GlobalKey _childKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    // 每秒刷新 ID / 密码 / 网络状态
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        await gFFI.serverModel.fetchID();
      } catch (_) {}
      setState(() {});
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Container(
        key: _childKey,
        width: double.infinity,
        height: double.infinity,
        child: Row(
          children: [
            // ⚠️ 左侧已完全移除
            Expanded(child: buildRightPane(context)),
          ],
        ),
      ),
    );
  }

  // ================================
  // 右侧主界面（ID / 密码 / 网络状态）
  // ================================
  Widget buildRightPane(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      color: Theme.of(context).colorScheme.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildTip(context),
          SizedBox(height: 20),

          buildIDBoard(context),
          SizedBox(height: 20),

          buildPasswordBoard(context),
          SizedBox(height: 20),

          Spacer(),

          // ⭐ 保留网络状态
          OnlineStatusWidget(
            onSvcStatusChanged: () {},
          ),
        ],
      ),
    );
  }

  // 顶部标题 + 小字
  Widget buildTip(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          translate("Your Desktop"),
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),
        SizedBox(height: 10),
        Text(
          translate("Share this ID to allow connection"),
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  // ID 展示区
  Widget buildIDBoard(BuildContext context) {
    return Consumer<ServerModel>(
      builder: (context, model, _) {
        final id = model.id.isEmpty ? "---- ----" : model.id;

        return Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                blurRadius: 20,
                spreadRadius: 2,
                color: Colors.black.withOpacity(0.05),
              )
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: AutoSizeText(
                  id,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              SizedBox(width: 20),

              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: id));
                  showToast("Copied");
                },
                child: Icon(Icons.copy, size: 32),
              ),
            ],
          ),
        );
      },
    );
  }

  // 密码展示区
  Widget buildPasswordBoard(BuildContext context) {
    return FutureBuilder(
      future: bind.mainGetMainPassword(),
      builder: (context, snapshot) {
        final pwd = snapshot.data?.toString() ?? "--------";

        return Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                blurRadius: 20,
                spreadRadius: 2,
                color: Colors.black.withOpacity(0.05),
              )
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: AutoSizeText(
                  pwd,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              SizedBox(width: 20),

              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: pwd));
                  showToast("Copied");
                },
                child: Icon(Icons.copy, size: 32),
              ),
            ],
          ),
        );
      },
    );
  }
}

// =====================
// 工具：Toast
// =====================
void showToast(String msg) {
  Fluttertoast.showToast(
    msg: msg,
    gravity: ToastGravity.BOTTOM,
    toastLength: Toast.LENGTH_SHORT,
  );
}
