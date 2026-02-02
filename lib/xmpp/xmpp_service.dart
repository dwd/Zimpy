import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:xmpp_stone/xmpp_stone.dart';

import '../models/chat_message.dart';

enum XmppStatus {
  disconnected,
  connecting,
  connected,
  error,
}

class XmppService extends ChangeNotifier {
  Connection? _connection;
  RosterManager? _rosterManager;
  ChatManager? _chatManager;
  StreamSubscription<XmppConnectionState>? _connectionStateSubscription;
  StreamSubscription<List<Buddy>>? _rosterSubscription;
  StreamSubscription<List<Chat>>? _chatListSubscription;
  final Map<String, StreamSubscription<Message>> _chatMessageSubscriptions = {};

  XmppStatus _status = XmppStatus.disconnected;
  String? _errorMessage;
  String? _currentUserBareJid;
  XmppConnectionState? _lastConnectionState;
  final Map<String, List<ChatMessage>> _messages = {};
  final List<String> _contacts = [];
  String? _activeChatBareJid;

  XmppStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String? get currentUserBareJid => _currentUserBareJid;
  XmppConnectionState? get lastConnectionState => _lastConnectionState;
  List<String> get contacts => List.unmodifiable(_contacts);
  String? get activeChatBareJid => _activeChatBareJid;

  List<ChatMessage> messagesFor(String bareJid) {
    return List.unmodifiable(_messages[bareJid] ?? const []);
  }

  bool get isConnected => _status == XmppStatus.connected;
  bool get isConnecting => _status == XmppStatus.connecting;

  Future<void> connect({
    required String jid,
    required String password,
    required String resource,
    String? host,
    required int port,
  }) async {
    if (kIsWeb) {
      _setError('Web builds are not supported by the current XMPP transport.');
      return;
    }

    final normalized = jid.trim();
    if (!_looksLikeJid(normalized)) {
      _setError('Enter a full JID like user@domain.');
      return;
    }

    final bareJid = _bareJid(normalized);
    final domain = _domainFromBareJid(bareJid);
    final fullJid = normalized.contains('/') ? normalized : '$bareJid/$resource';

    await _safeClose();

    _status = XmppStatus.connecting;
    _errorMessage = null;
    _currentUserBareJid = bareJid;
    notifyListeners();

    try {
      final normalizedHost =
          host?.trim().isNotEmpty == true ? host!.trim() : 'auto';
      debugPrint('XMPP connect: bareJid=$bareJid host=$normalizedHost port=$port resource=$resource');
      final account = XmppAccountSettings.fromJid(fullJid, password);
      account.host = host?.trim().isNotEmpty == true ? host!.trim() : null;
      account.port = port;
      account.resource = resource;

      final connection = Connection.getInstance(account);
      _connection = connection;

      final completer = Completer<void>();
      _connectionStateSubscription =
          connection.connectionStateStream.listen((state) {
        debugPrint('XMPP state: $state');
        _lastConnectionState = state;
        if (state == XmppConnectionState.Ready) {
          if (!completer.isCompleted) {
            completer.complete();
          }
          _status = XmppStatus.connected;
          _errorMessage = null;
          notifyListeners();
          _setupRoster();
          _setupChatManager();
          _sendInitialPresence();
        } else if (_isTerminalError(state)) {
          final message = _connectionErrorMessage(state);
          debugPrint('XMPP error: $message');
          if (!completer.isCompleted) {
            completer.completeError(message);
          }
          _setError(message);
        } else if (_status == XmppStatus.connecting) {
          notifyListeners();
        }
      });

      connection.connect();

      await completer.future.timeout(const Duration(seconds: 20));
    } catch (error) {
      await _safeClose();
      if (_status != XmppStatus.error) {
        _setError('Connection failed: $error');
      }
    }
  }

  Future<void> disconnect() async {
    await _safeClose();
    _status = XmppStatus.disconnected;
    _errorMessage = null;
    notifyListeners();
  }

  void selectChat(String? bareJid) {
    _activeChatBareJid = bareJid;
    notifyListeners();
  }

  void sendMessage({
    required String toBareJid,
    required String text,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final chatManager = _chatManager;
    if (chatManager == null) {
      _setError('Not connected.');
      return;
    }

    final jid = Jid.fromFullJid(toBareJid);
    final chat = chatManager.getChat(jid);
    _ensureChatSubscription(chat);
    chat.sendMessage(trimmed);
  }

  void addManualContact(String bareJid) {
    final normalized = _bareJid(bareJid);
    if (normalized.isEmpty) {
      return;
    }
    _ensureContact(normalized);
    selectChat(normalized);
  }

  void _setupRoster() {
    final connection = _connection;
    if (connection == null) {
      return;
    }

    final rosterManager = RosterManager.getInstance(connection);
    _rosterManager = rosterManager;

    _rosterSubscription?.cancel();
    _rosterSubscription = rosterManager.rosterStream.listen((buddies) {
      for (final buddy in buddies) {
        final jid = buddy.jid?.userAtDomain;
        if (jid != null && jid.isNotEmpty) {
          _ensureContact(jid);
        }
      }
    });

    rosterManager.queryForRoster();
  }

  void _setupChatManager() {
    final connection = _connection;
    if (connection == null) {
      return;
    }

    final chatManager = ChatManager.getInstance(connection);
    _chatManager = chatManager;

    _chatListSubscription?.cancel();
    _chatListSubscription = chatManager.chatListStream.listen((chats) {
      for (final chat in chats) {
        _ensureChatSubscription(chat);
      }
    });
  }

  void _ensureChatSubscription(Chat chat) {
    final buddyJid = chat.jid.userAtDomain;
    if (_chatMessageSubscriptions.containsKey(buddyJid)) {
      return;
    }
    _ensureContact(buddyJid);
    final existing = _messages[buddyJid];
    if (existing == null || existing.isEmpty) {
      for (final message in chat.messages ?? const <Message>[]) {
        final from = message.from?.userAtDomain ?? 'unknown';
        final to = message.to?.userAtDomain ?? '';
        final body = message.text ?? '';
        if (body.trim().isEmpty) {
          continue;
        }
        final outgoing = from == (_currentUserBareJid ?? '');
        _addMessage(
          bareJid: outgoing ? to : from,
          from: from,
          to: to,
          body: body,
          outgoing: outgoing,
          timestamp: message.time,
        );
      }
    }
    _chatMessageSubscriptions[buddyJid] =
        chat.newMessageStream.listen((message) {
      final from = message.from?.userAtDomain ?? 'unknown';
      final to = message.to?.userAtDomain ?? '';
      final body = message.text ?? '';
      if (body.trim().isEmpty) {
        return;
      }
      final outgoing = from == (_currentUserBareJid ?? '');
      _addMessage(
        bareJid: outgoing ? to : from,
        from: from,
        to: to,
        body: body,
        outgoing: outgoing,
        timestamp: message.time,
      );
    });
  }

  void _addMessage({
    required String bareJid,
    required String from,
    required String to,
    required String body,
    required bool outgoing,
    required DateTime timestamp,
  }) {
    final normalized = _bareJid(bareJid);
    _ensureContact(normalized);

    final list = _messages.putIfAbsent(normalized, () => <ChatMessage>[]);
    list.add(ChatMessage(
      from: from,
      to: to,
      body: body,
      outgoing: outgoing,
      timestamp: timestamp,
    ));
    notifyListeners();
  }

  void _ensureContact(String bareJid) {
    if (!_contacts.contains(bareJid)) {
      _contacts.add(bareJid);
      _contacts.sort();
      notifyListeners();
    }
  }

  void _setError(String message) {
    _status = XmppStatus.error;
    _errorMessage = message;
    notifyListeners();
  }

  Future<void> _safeClose() async {
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    _rosterSubscription?.cancel();
    _rosterSubscription = null;
    _chatListSubscription?.cancel();
    _chatListSubscription = null;
    for (final subscription in _chatMessageSubscriptions.values) {
      subscription.cancel();
    }
    _chatMessageSubscriptions.clear();

    _activeChatBareJid = null;
    _currentUserBareJid = null;
    _lastConnectionState = null;
    _rosterManager = null;
    _chatManager = null;
    _contacts.clear();
    _messages.clear();

    try {
      _connection?.close();
    } catch (_) {
      // Ignore close errors to keep disconnect resilient.
    } finally {
      _connection = null;
    }
  }

  bool _looksLikeJid(String jid) {
    final parsed = Jid.fromFullJid(jid);
    return parsed.isValid();
  }

  String _domainFromBareJid(String bareJid) {
    final parts = bareJid.split('@');
    return parts.length == 2 ? parts[1] : '';
  }

  String _bareJid(String jid) {
    final trimmed = jid.trim();
    final slashIndex = trimmed.indexOf('/');
    if (slashIndex == -1) {
      return trimmed;
    }
    return trimmed.substring(0, slashIndex);
  }

  bool _isTerminalError(XmppConnectionState state) {
    return state == XmppConnectionState.AuthenticationFailure ||
        state == XmppConnectionState.AuthenticationNotSupported ||
        state == XmppConnectionState.StartTlsFailed ||
        state == XmppConnectionState.ForcefullyClosed ||
        state == XmppConnectionState.Closed;
  }

  String _connectionErrorMessage(XmppConnectionState state) {
    switch (state) {
      case XmppConnectionState.AuthenticationFailure:
        return 'Authentication failed.';
      case XmppConnectionState.AuthenticationNotSupported:
        return 'Authentication not supported.';
      case XmppConnectionState.StartTlsFailed:
        return 'StartTLS failed.';
      case XmppConnectionState.ForcefullyClosed:
      case XmppConnectionState.Closed:
        return 'Connection closed.';
      default:
        return 'Connection error.';
    }
  }

  void _sendInitialPresence() {
    final connection = _connection;
    if (connection == null) {
      return;
    }
    debugPrint('XMPP sending initial presence');
    final presenceManager = PresenceManager.getInstance(connection);
    presenceManager.sendPresence(PresenceData(PresenceShowElement.CHAT, 'Online', null));
  }
}
