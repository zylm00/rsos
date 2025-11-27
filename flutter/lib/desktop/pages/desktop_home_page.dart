import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/animated_rotation_widget.dart';
import 'package:flutter_hbb/common/widgets/custom_password.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/pages/connection_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_tab_page.dart';
import 'package:flutter_hbb/desktop/widgets/update_progress.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:flutter_hbb/plugin/ui_manager.dart';
import 'package:flutter_hbb/utils/multi_window_manager.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';
import 'package:window_size/window_size.dart' as window_size;
import '../widgets/button.dart';

class DesktopHomePage extends StatefulWidget {
  const DesktopHomePage({Key? key}) : super(key: key);

  @override
  State<DesktopHomePage> createState() => _DesktopHomePageState();
}

const borderColor = Color(0xFF2F65BA);

class _DesktopHomePageState extends State<DesktopHomePage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final _leftPaneScrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;
  var systemError = '';
  StreamSubscription? _uniLinksSubscription;
  var svcStopped = false.obs;
  var watchIsCanScreenRecording = false;
  var watchIsProcessTrust = false;
  var watchIsInputMonitoring = false;
  var watchIsCanRecordAudio = false;
  Timer? _updateTimer;
  bool isCardClosed = false;

  final RxBool _editHover = false.obs;
  final RxBool _block = false.obs;

  final GlobalKey _childKey = GlobalKey();

  /// 缩小版控制
  final bool isMiniVersion = true; // true = 缩小版, false = 官方版
  final Size miniSize = const Size(260, 360);
  final Size officialSize = const Size(780, 580);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _buildBlock(
        child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: buildRightPane(context)), // 右侧全屏显示
      ],
    ));
  }

  Widget _buildBlock({required Widget child}) {
    return buildRemoteBlock(
        block: _block, mask: true, use: canBeBlocked, child: child);
  }

  @override
  void initState() {
    super.initState();

    // 缩小版窗口尺寸
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (isMiniVersion) {
        await windowManager.setSize(miniSize);
        await windowManager.setMinimumSize(miniSize);
        await windowManager.setMaximumSize(miniSize);
      } else {
        await windowManager.setSize(officialSize);
      }
    });

    _updateTimer = periodic_immediate(const Duration(seconds: 1), () async {
      await gFFI.serverModel.fetchID();
      final error = await bind.mainGetError();
      if (systemError != error) {
        systemError = error;
        setState(() {});
      }
      final v = await mainGetBoolOption(kOptionStopService);
      if (v != svcStopped.value) {
        svcStopped.value = v;
        setState(() {});
      }
    });

    Get.put<RxBool>(svcStopped, tag: 'stop-service');
    rustDeskWinManager.registerActiveWindowListener(onActiveWindowChanged);
    _uniLinksSubscription = listenUniLinks();

    if (bind.isIncomingOnly()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateWindowSize();
      });
    }
    WidgetsBinding.instance.addObserver(this);
  }

  _updateWindowSize() {
    // 缩小版不需要动态调整窗口尺寸
    if (isMiniVersion) return;

    RenderObject? renderObject = _childKey.currentContext?.findRenderObject();
    if (renderObject == null) return;

    if (renderObject is RenderBox) {
      final size = renderObject.size;
      if (size != imcomingOnlyHomeSize) {
        imcomingOnlyHomeSize = size;
        windowManager.setSize(getIncomingOnlyHomeSize());
      }
    }
  }

  buildRightPane(BuildContext context) {
    final isOutgoingOnly = bind.isOutgoingOnly();

    final children = <Widget>[
      if (!isOutgoingOnly) buildPresetPasswordWarning(),
      if (bind.isCustomClient()) Align(alignment: Alignment.center, child: loadPowered(context)),
      Align(alignment: Alignment.center, child: loadLogo()),
      buildTip(context),
      if (!isOutgoingOnly) buildIDBoard(context),
      if (!isOutgoingOnly) buildPasswordBoard(context),
      FutureBuilder<Widget>(
        future: Future.value(Obx(() => buildHelpCards(stateGlobal.updateUrl.value))),
        builder: (_, data) {
          if (data.hasData) {
            return data.data!;
          } else {
            return const Offstage();
          }
        },
      ),
      buildPluginEntry(),
    ];

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                key: _childKey,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
          // 底部网络状态
          Divider(),
          OnlineStatusWidget().marginOnly(bottom: 6, right: 6),
        ],
      ),
    );
  }

  buildIDBoard(BuildContext context) {
    final model = gFFI.serverModel;
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 11),
      height: 57,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Container(width: 2, decoration: const BoxDecoration(color: MyTheme.accent)).marginOnly(top: 5),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 25,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          translate("ID"),
                          style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.color
                                  ?.withOpacity(0.5)),
                        ).marginOnly(top: 5),
                      ],
                    ),
                  ),
                  Flexible(
                    child: TextFormField(
                      controller: model.serverId,
                      readOnly: true,
                      decoration: InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.only(top: 10, bottom: 10)),
                      style: TextStyle(fontSize: 22),
                    ).workaroundFreezeLinuxMint(),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  buildPasswordBoard(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: gFFI.serverModel,
      child: Consumer<ServerModel>(
        builder: (context, model, child) => buildPasswordBoard2(context, model),
      ),
    );
  }

  buildPasswordBoard2(BuildContext context, ServerModel model) {
    RxBool refreshHover = false.obs;
    final showOneTime = model.approveMode != 'click' && model.verificationMethod != kUsePermanentPassword;

    return Container(
      margin: EdgeInsets.only(left: 20, right: 16, top: 13, bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: model.serverPasswd,
                  readOnly: true,
                  decoration: InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.only(top: 14, bottom: 10)),
                  style: TextStyle(fontSize: 15),
                ).workaroundFreezeLinuxMint(),
              ),
              if (showOneTime)
                AnimatedRotationWidget(
                  onPressed: () => bind.mainUpdateTemporaryPassword(),
                  child: Tooltip(
                    message: translate('Refresh Password'),
                    child: Obx(() => RotatedBox(
                        quarterTurns: 2,
                        child: Icon(
                          Icons.refresh,
                          color: refreshHover.value ? Colors.black : Color(0xFFDDDDDD),
                          size: 22,
                        ))),
                  ),
                  onHover: (value) => refreshHover.value = value,
                ).marginOnly(right: 8, top: 4),
            ],
          ),
          if (showOneTime)
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: model.serverPasswd.text));
                  showToast(translate("Copied"));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Color(0xFF2576E3), borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    translate("复制"),
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  buildTip(BuildContext context) {
    final isOutgoingOnly = bind.isOutgoingOnly();
    return Padding(
      padding: const EdgeInsets.only(left: 20.0, right: 16, top: 16.0, bottom: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isOutgoingOnly)
            Text(translate("Your Desktop"), style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: 10),
          if (!isOutgoingOnly)
            Text(translate("点击复制发给小伙伴"), overflow: TextOverflow.clip, style: Theme.of(context).textTheme.bodySmall),
          if (isOutgoingOnly)
            Text(translate("outgoing_only_desk_tip"), overflow: TextOverflow.clip, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget buildHelpCards(String updateUrl) => Container();

  Widget buildPluginEntry() {
    final entries = PluginUiManager.instance.entries.entries;
    return Offstage(
      offstage: entries.isEmpty,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: entries.map((entry) => entry.value).toList(),
      ),
    );
  }

  @override
  void dispose() {
    _uniLinksSubscription?.cancel();
    Get.delete<RxBool>(tag: 'stop-service');
    _updateTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
