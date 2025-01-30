import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final WebviewService webviewService;

  @override
  void initState() {
    super.initState();
    webviewService = WebviewService()..init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 0.5,
              height: 0.5,
              child: webviewService.webview,
            )
          ],
        ),
      ),
    );
  }
}

class WebviewService {
  late final WebViewController _webViewController;
  late final WebViewWidget _webview;

  WebviewService() {
    _webViewController = WebViewController();
    _webview = WebViewWidget(controller: _webViewController);
  }

  Future<void> init() async {
    await _init();
  }

  WebViewWidget get webview => _webview;

  Future<void> _init() async {
    await _webViewController.setBackgroundColor(Colors.transparent);
    await _webViewController.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _webViewController.enableZoom(false);
    await _webViewController.addJavaScriptChannel(
      'w3mWebview',
      onMessageReceived: _onFrameMessage,
    );
    await _webViewController.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (NavigationRequest request) async {
          print(request.url);
          return NavigationDecision.navigate;
        },
        onWebResourceError: _onWebResourceError,
        onPageFinished: (String url) async {
          print(url);
          await _runJavascript();
          await _fitToScreen();
          Future.delayed(const Duration(seconds: 1), () {
            _webViewController.runJavaScript(
              'sendMessage({type: "@w3m-app/IS_CONNECTED"})',
            );
          });
        },
      ),
    );
    await _setDebugMode();
    await _loadRequest();
  }

  Future<void> _loadRequest() async {
    try {
      const url = 'https://secure-mobile.walletconnect.com/mobile-sdk';
      final uri = Uri.parse(url);
      final queryParams = {
        'projectId': 'cad4956f31a5e40a00b62865b030c6f8',
        'bundleId': 'com.walletconnect.flutterdapp',
      };
      final requestUri = uri.replace(queryParameters: queryParams);
      await _webViewController.loadRequest(requestUri);
      // in case connection message or even the request itself hangs there's no other way to continue the flow than timing it out.
    } catch (e) {
      print(e);
    }
  }

  void _onFrameMessage(JavaScriptMessage jsMessage) async {
    print(jsMessage.message);
  }

  Future<void> _fitToScreen() async {
    return await _webViewController.runJavaScript('''
      if (document.querySelector('meta[name="viewport"]') === null) {
        var meta = document.createElement('meta');
        meta.name = 'viewport';
        meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
        document.head.appendChild(meta);
      } else {
        document.querySelector('meta[name="viewport"]').setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no');
      }
    ''');
  }

  Future<void> _runJavascript() async {
    return await _webViewController.runJavaScript('''
      window.addEventListener('message', ({ data, origin }) => {
        console.log('eventListener ' + JSON.stringify({data,origin}))
        window.w3mWebview.postMessage(JSON.stringify({data,origin}))
      })

      const sendMessage = async (message) => {
        const iframeFL = document.getElementById('frame-mobile-sdk')
        console.log('postMessage(' + JSON.stringify(message) + ')')
        iframeFL.contentWindow.postMessage(message, '*')
      }
    ''');
  }

  void _onWebResourceError(WebResourceError error) {
    print('''
              [$runtimeType] Page resource error:
              code: ${error.errorCode}
              description: ${error.description}
              errorType: ${error.errorType}
              isForMainFrame: ${error.isForMainFrame}
              url: ${error.url}
            ''');
  }

  void _onDebugConsoleReceived(JavaScriptConsoleMessage message) {
    print(message.message);
  }

  Future<void> _setDebugMode() async {
    if (kDebugMode) {
      try {
        if (Platform.isIOS) {
          await _webViewController.setOnConsoleMessage(
            _onDebugConsoleReceived,
          );
          final webkitCtrl =
              _webViewController.platform as WebKitWebViewController;
          webkitCtrl.setInspectable(true);
        }
      } catch (_) {}
    }
  }
}
