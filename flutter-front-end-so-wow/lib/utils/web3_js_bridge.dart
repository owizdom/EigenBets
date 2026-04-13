import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';

// JS interop bindings for window-level functions
@JS('eval')
external JSAny? _eval(JSString code);

@JS('window.hasMetaMask')
external JSBoolean? get _hasMetaMask;

@JS('window.hasCoinbaseWallet')
external JSBoolean? get _hasCoinbaseWallet;

@JS('window.walletConnected')
external JSBoolean? get _walletConnected;

@JS('window.walletAddress')
external JSString? get _walletAddress;

@JS('window.walletChainId')
external JSString? get _walletChainId;

@JS('window.connectMetaMask')
external JSPromise<JSObject?> _connectMetaMask();

@JS('window.connectCoinbaseWallet')
external JSPromise<JSObject?> _connectCoinbaseWallet();

@JS('window.switchNetwork')
external JSPromise<JSObject?> _switchNetwork(JSString chainId);

@JS('window.disconnectWallet')
external JSPromise<JSObject?> _disconnectWallet();

@JS('window.signMessage')
external JSPromise<JSObject?> _signMessage(JSString message);

@JS('window.sendTransaction')
external JSPromise<JSObject?> _sendTransaction(JSString to, JSString value, JSString data);

@JS('window.getTokenBalance')
external JSPromise<JSObject?> _getTokenBalance(JSString tokenAddr, JSString ownerAddr);

@JS('window.isWalletConnected')
external JSBoolean? _isWalletConnectedFn();

@JS('window.getWalletAddress')
external JSString? _getWalletAddressFn();

@JS('window.getChainId')
external JSString? _getChainIdFn();

/// Convert a JSObject result from a Promise into a Dart Map
Map<String, dynamic> _jsResultToMap(JSObject? result) {
  if (result == null) return {'success': false, 'error': 'Null result'};
  try {
    final dart = result.dartify();
    return dart is Map ? Map<String, dynamic>.from(dart) : {'success': false, 'error': 'Unexpected type'};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

Future<Map<String, dynamic>> _callPromise(JSPromise<JSObject?> Function() fn) async {
  if (!kIsWeb) return {'success': false, 'error': 'Not web'};
  try {
    final result = await fn().toDart;
    return _jsResultToMap(result);
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

/// A utility class to bridge Flutter and JavaScript for Web3 wallet interactions
class Web3JsBridge {
  static bool get isSupported => kIsWeb;

  static const String _web3JsInjectScript = '''
    (function() {
      console.log("Web3JsBridge script loaded");
      window.walletConnected = false;
      window.walletAddress = null;
      window.walletChainId = null;
      window.walletType = null;
      window.hasMetaMask = (typeof window.ethereum !== 'undefined');
      window.hasCoinbaseWallet = (typeof window.coinbaseWalletExtension !== 'undefined');

      window.isWalletConnected = function() { return window.walletConnected; };
      window.getWalletAddress = function() { return window.walletAddress; };
      window.getChainId = function() { return window.walletChainId; };

      window.connectMetaMask = async function() {
        if (!window.hasMetaMask) return { success: false, error: 'MetaMask not installed' };
        try {
          var accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
          if (accounts && accounts.length > 0) {
            window.walletConnected = true;
            window.walletAddress = accounts[0];
            window.walletType = 'metamask';
            window.walletChainId = await window.ethereum.request({ method: 'eth_chainId' });
            return { success: true, address: accounts[0], chainId: window.walletChainId };
          }
          return { success: false, error: 'No accounts' };
        } catch (e) { return { success: false, error: e.message }; }
      };

      window.connectCoinbaseWallet = async function() {
        if (!window.hasCoinbaseWallet) return { success: false, error: 'Coinbase Wallet not installed' };
        try {
          var accounts = await window.coinbaseWalletExtension.request({ method: 'eth_requestAccounts' });
          if (accounts && accounts.length > 0) {
            window.walletConnected = true; window.walletAddress = accounts[0]; window.walletType = 'coinbase';
            window.walletChainId = await window.coinbaseWalletExtension.request({ method: 'eth_chainId' });
            return { success: true, address: accounts[0], chainId: window.walletChainId };
          }
          return { success: false, error: 'No accounts' };
        } catch (e) { return { success: false, error: e.message }; }
      };

      window.switchNetwork = async function(chainId) {
        if (!window.walletConnected) return { success: false, error: 'No wallet' };
        var p = window.walletType==='metamask' ? window.ethereum : window.coinbaseWalletExtension;
        try { await p.request({ method: 'wallet_switchEthereumChain', params: [{ chainId: chainId }] }); window.walletChainId = chainId; return { success: true }; }
        catch (e) { return { success: false, error: e.message }; }
      };

      window.disconnectWallet = async function() {
        window.walletConnected = false; window.walletAddress = null; window.walletChainId = null; window.walletType = null;
        return { success: true };
      };

      window.signMessage = async function(msg) {
        if (!window.walletConnected) return { success: false, error: 'No wallet' };
        var p = window.walletType==='metamask' ? window.ethereum : window.coinbaseWalletExtension;
        try { var s = await p.request({ method: 'personal_sign', params: [msg, window.walletAddress] }); return { success: true, signature: s }; }
        catch (e) { return { success: false, error: e.message }; }
      };

      window.sendTransaction = async function(to, value, data) {
        if (!window.walletConnected) return { success: false, error: 'No wallet' };
        var p = window.walletType==='metamask' ? window.ethereum : window.coinbaseWalletExtension;
        try { var h = await p.request({ method: 'eth_sendTransaction', params: [{ from: window.walletAddress, to: to, value: value, data: data }] }); return { success: true, txHash: h }; }
        catch (e) { return { success: false, error: e.message }; }
      };

      window.getTokenBalance = async function(tokenAddr, ownerAddr) {
        if (!window.walletConnected) return { success: false, error: 'No wallet' };
        var p = window.walletType==='metamask' ? window.ethereum : window.coinbaseWalletExtension;
        try {
          var data = "0x70a08231000000000000000000000000" + ownerAddr.replace(/^0x/,'');
          var r = await p.request({ method: 'eth_call', params: [{ to: tokenAddr, data: data }, 'latest'] });
          return { success: true, balance: parseInt(r,16) };
        } catch (e) { return { success: false, error: e.message }; }
      };
    })();
  ''';

  static Future<void> initialize() async {
    if (!isSupported) return;
    try {
      _eval(_web3JsInjectScript.toJS);
      await Future.delayed(const Duration(milliseconds: 500));
      debugPrint('Web3JsBridge initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize Web3JsBridge: \$e');
    }
  }

  static Future<bool> hasMetaMask() async {
    if (!isSupported) return false;
    try { return _hasMetaMask?.toDart ?? false; } catch (_) { return false; }
  }

  static Future<bool> hasCoinbaseWallet() async {
    if (!isSupported) return false;
    try { return _hasCoinbaseWallet?.toDart ?? false; } catch (_) { return false; }
  }

  static Future<Map<String, dynamic>> connectMetaMask() async => _callPromise(() => _connectMetaMask());
  static Future<Map<String, dynamic>> connectCoinbaseWallet() async => _callPromise(() => _connectCoinbaseWallet());
  static Future<Map<String, dynamic>> switchNetwork(String chainId) async => _callPromise(() => _switchNetwork(chainId.toJS));
  static Future<Map<String, dynamic>> addNetwork(Map<String, dynamic> config) async => {'success': false, 'error': 'Use switchNetwork'};
  static Future<Map<String, dynamic>> getTokenBalance(String tokenAddr, String ownerAddr) async => _callPromise(() => _getTokenBalance(tokenAddr.toJS, ownerAddr.toJS));
  static Future<Map<String, dynamic>> getNativeBalance(String address) async => {'success': false, 'error': 'Not implemented'};
  static Future<Map<String, dynamic>> signMessage(String message) async => _callPromise(() => _signMessage(message.toJS));
  static Future<Map<String, dynamic>> sendTransaction(String to, String value, String data) async => _callPromise(() => _sendTransaction(to.toJS, value.toJS, data.toJS));
  static Future<Map<String, dynamic>> disconnectWallet() async => _callPromise(() => _disconnectWallet());

  static Future<bool> isWalletConnected() async {
    if (!isSupported) return false;
    try { return _isWalletConnectedFn()?.toDart ?? false; } catch (_) { return false; }
  }

  static Future<String?> getWalletAddress() async {
    if (!isSupported) return null;
    try { return _getWalletAddressFn()?.toDart; } catch (_) { return null; }
  }

  static Future<String?> getChainId() async {
    if (!isSupported) return null;
    try { return _getChainIdFn()?.toDart; } catch (_) { return null; }
  }
}
