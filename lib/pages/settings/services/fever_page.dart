import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fluent_reader_lite/components/list_tile_group.dart';
import 'package:fluent_reader_lite/components/my_list_tile.dart';
import 'package:fluent_reader_lite/generated/l10n.dart';
import 'package:fluent_reader_lite/models/services/fever.dart';
import 'package:fluent_reader_lite/models/services/service_import.dart';
import 'package:fluent_reader_lite/models/sync_model.dart';
import 'package:fluent_reader_lite/pages/settings/text_editor_page.dart';
import 'package:fluent_reader_lite/utils/colors.dart';
import 'package:fluent_reader_lite/utils/global.dart';
import 'package:fluent_reader_lite/utils/store.dart';
import 'package:fluent_reader_lite/utils/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:overlay_dialog/overlay_dialog.dart';
import 'package:provider/provider.dart';

class FeverPage extends StatefulWidget {
  @override
  _FeverPageState createState() => _FeverPageState();
}

class _FeverPageState extends State<FeverPage> {
  String _endpoint = Store.sp.getString(StoreKeys.ENDPOINT) ?? "";
  String _username = Store.sp.getString(StoreKeys.USERNAME) ?? "";
  String _apiKey = Store.sp.getString(StoreKeys.API_KEY);
  String _password = Store.sp.getString(StoreKeys.PASSWORD) ?? "";
  int _fetchLimit = Store.sp.getInt(StoreKeys.FETCH_LIMIT) ?? 250;
  bool _validating = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      ServiceImport import = ModalRoute.of(context).settings.arguments;
      if (import == null) return;
      if (Utils.testUrl(import.endpoint)) {
        setState(() { _endpoint = import.endpoint; });
      }
      if (Utils.notEmpty(import.username)) {
        setState(() { _username = import.username; });
      }
      if (Utils.notEmpty(import.apiKey)) {
        setState(() { _apiKey = import.apiKey; });
      }
    });
  }

  void _editEndpoint() async {
    final String endpoint = await Navigator.of(context).push(CupertinoPageRoute(
      builder: (context) => TextEditorPage(
        S.of(context).endpoint, 
        Utils.testUrl,
        initialValue: _endpoint,
        inputType: TextInputType.url,
      ),
    ));
    if (endpoint == null) return;
    setState(() { _endpoint = endpoint; });
  }

  void _editUsername() async {
    final String username = await Navigator.of(context).push(CupertinoPageRoute(
      builder: (context) => TextEditorPage(
        S.of(context).username, 
        Utils.notEmpty,
        initialValue: _username,
      ),
    ));
    if (username == null) return;
    setState(() {
      _username = username;
      _apiKey = null;
    });
  }

  void _editPassword() async {
    final String password = await Navigator.of(context).push(CupertinoPageRoute(
      builder: (context) => TextEditorPage(
        S.of(context).password, 
        Utils.notEmpty,
        inputType: TextInputType.visiblePassword,
      ),
    ));
    if (password == null) return;
    setState(() {
      _password = password;
      _apiKey = null;
    });
  }

  bool _canSave() {
    if (_validating) return false;
    return _endpoint.length > 0 &&
      ((_username.length > 0 && _password.length > 0) || _apiKey != null);
  }

  void _save() async {
    final apiKey = _apiKey
      ?? md5.convert(utf8.encode("$_username:$_password")).toString();
    final handler = FeverServiceHandler.fromValues(
      _endpoint,
      apiKey,
      _fetchLimit
    );
    setState(() { _validating = true; });
    DialogHelper().show(
      context,
      DialogWidget.progress(style: DialogStyle.cupertino),
    );
    final isValid = await handler.validate();
    if (!mounted) return;
    if (isValid) {
      handler.persist(_username, _password);
      await Global.syncModel.syncWithService();
      Global.syncModel.checkHasService();
      _validating = false;
      DialogHelper().hide(context);
      if (mounted) Navigator.of(context).pop();
    } else {
      setState(() { _validating = false; });
      DialogHelper().hide(context);
      Utils.showServiceFailureDialog(context);
    }
  }

  void _logOut() async {
    final bool confirmed = await showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(S.of(context).logOutWarning),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(S.of(context).cancel),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text(S.of(context).confirm),
            onPressed: () {
              Navigator.of(context).pop(true);
            },
          ),
        ],
      ),
    );
    if (confirmed != null) {
      setState(() { _validating = true; });
      DialogHelper().show(
        context,
        DialogWidget.progress(style: DialogStyle.cupertino),
      );
      await Global.syncModel.removeService();
      _validating = false;
      DialogHelper().hide(context);
      final navigator = Navigator.of(context);
      while (navigator.canPop()) navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputs = ListTileGroup([
      MyListTile(
        title: Text(S.of(context).endpoint),
        trailing: Text(_endpoint.length == 0
          ? S.of(context).enter
          : S.of(context).entered),
        onTap: _editEndpoint,
      ),
      MyListTile(
        title: Text(S.of(context).username),
        trailing: Text(_username.length == 0
          ? S.of(context).enter
          : S.of(context).entered),
        onTap: _editUsername,
      ),
      MyListTile(
        title: Text(S.of(context).password),
        trailing: Text(_password.length == 0 && _apiKey == null
          ? S.of(context).enter
          : S.of(context).entered),
        onTap: _editPassword,
        withDivider: false,
      ),
    ], title: S.of(context).credentials);
    final syncItems = ListTileGroup([
      MyListTile(
        title: Text(S.of(context).fetchLimit),
        trailing: Text(_fetchLimit.toString()),
        trailingChevron: false,
        withDivider: false,
      ),
      MyListTile(
        title: Expanded(child: CupertinoSlider(
          min: 250,
          max: 1500,
          divisions: 5,
          value: _fetchLimit.toDouble(),
          onChanged: (v) { setState(() { _fetchLimit = v.toInt(); }); },
        )),
        trailingChevron: false,
        withDivider: false,
      ),
    ], title: S.of(context).sync);
    final saveButton = Selector<SyncModel, bool>(
      selector: (context, syncModel) => syncModel.syncing,
      builder: (context, syncing, child) {
        var canSave = !syncing && _canSave();
        final saveStyle = TextStyle(
          color: canSave
            ? CupertinoColors.activeBlue.resolveFrom(context)
            : CupertinoColors.secondaryLabel.resolveFrom(context),
        );
        return ListTileGroup([
          MyListTile(
            title: Expanded(child: Center(
              child: Text(
                S.of(context).save,
                style: saveStyle,
              )
            )),
            onTap: canSave ? _save : null,
            trailingChevron: false,
            withDivider: false,
          ),
        ], title: "");
      },
    );
    final logOutButton = Selector<SyncModel, bool>(
      selector: (context, syncModel) => syncModel.syncing,
      builder: (context, syncing, child) {
        return ListTileGroup([
          MyListTile(
            title: Expanded(child: Center(
              child: Text(
                S.of(context).logOut,
                style: TextStyle(
                  color: (_validating || syncing)
                    ? CupertinoColors.secondaryLabel.resolveFrom(context)
                    : CupertinoColors.destructiveRed,
                ),
              )
            )),
            onTap: (_validating || syncing) ? null : _logOut,
            trailingChevron: false,
            withDivider: false,
          ),
        ], title: "");
      },
    );
    final page = CupertinoPageScaffold(
      backgroundColor: MyColors.background,
      navigationBar: CupertinoNavigationBar(
        middle: Text("Fever API"),
      ),
      child: ListView(children: [
        inputs,
        syncItems,
        saveButton,
        if (Global.service != null) logOutButton,
      ]),
    );
    if (Platform.isAndroid) {
      return WillPopScope(child: page, onWillPop: () async => !_validating);
    } else {
      return page;
    }
  }
}
