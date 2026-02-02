import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:xmpp_stone/xmpp_stone.dart';
import 'package:xmpp_stone/src/elements/nonzas/Nonza.dart';

import '../models/chat_message.dart';
import '../models/contact_entry.dart';

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
  StreamSubscription<PresenceData>? _presenceSubscription;
  StreamSubscription<Nonza>? _smNonzaSubscription;
  StreamSubscription<AbstractStanza?>? _pingSubscription;
  Timer? _pingTimer;
  final Map<String, DateTime> _pendingPings = {};
  DateTime? _pendingSmAckAt;
  String? _carbonsRequestId;
  final Map<String, StreamSubscription<Message>> _chatMessageSubscriptions = {};
  final Map<String, StreamSubscription<ChatState?>> _chatStateSubscriptions = {};

  XmppStatus _status = XmppStatus.disconnected;
  String? _errorMessage;
  String? _currentUserBareJid;
  XmppConnectionState? _lastConnectionState;
  final Map<String, List<ChatMessage>> _messages = {};
  final List<ContactEntry> _contacts = [];
  final Map<String, PresenceData> _presenceByBareJid = {};
  final Map<String, ChatState?> _chatStates = {};
  String? _activeChatBareJid;
  void Function(List<ContactEntry> roster)? _rosterPersistor;
  void Function(String bareJid, List<ChatMessage> messages)? _messagePersistor;
  PresenceData _selfPresence = PresenceData(PresenceShowElement.CHAT, 'Online', null);
  Duration? _lastPingLatency;
  DateTime? _lastPingAt;
  bool _carbonsEnabled = false;

  XmppStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String? get currentUserBareJid => _currentUserBareJid;
  XmppConnectionState? get lastConnectionState => _lastConnectionState;
  List<ContactEntry> get contacts => List.unmodifiable(_contacts);
  String? get activeChatBareJid => _activeChatBareJid;
  Duration? get lastPingLatency => _lastPingLatency;
  DateTime? get lastPingAt => _lastPingAt;
  bool get carbonsEnabled => _carbonsEnabled;

  List<ChatMessage> messagesFor(String bareJid) {
    return List.unmodifiable(_messages[bareJid] ?? const []);
  }

  PresenceData? presenceFor(String bareJid) {
    return _presenceByBareJid[_bareJid(bareJid)];
  }

  String presenceLabelFor(String bareJid) {
    final presence = presenceFor(bareJid);
    if (presence == null) {
      return 'offline';
    }
    final show = presence.showElement;
    if (show == null) {
      return 'online';
    }
    switch (show) {
      case PresenceShowElement.CHAT:
        return 'online';
      case PresenceShowElement.AWAY:
        return 'away';
      case PresenceShowElement.DND:
        return 'do not disturb';
      case PresenceShowElement.XA:
        return 'extended away';
      default:
        return 'online';
    }
  }

  ChatState? chatStateFor(String bareJid) {
    return _chatStates[_bareJid(bareJid)];
  }

  String chatStateLabelFor(String bareJid) {
    final state = chatStateFor(bareJid);
    switch (state) {
      case ChatState.COMPOSING:
        return 'typing...';
      case ChatState.PAUSED:
        return 'paused';
      case ChatState.ACTIVE:
        return 'active';
      case ChatState.INACTIVE:
        return 'inactive';
      case ChatState.GONE:
        return 'gone';
      default:
        return '';
    }
  }

  PresenceData get selfPresence => _selfPresence;

  void setSelfPresence({required PresenceShowElement show, String? status}) {
    _selfPresence = PresenceData(show, status, null);
    _sendPresence(_selfPresence);
    notifyListeners();
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

    await _safeClose(preserveCache: true);

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
          _setupPresence();
          _setupKeepalive();
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
      await _safeClose(preserveCache: true);
      if (_status != XmppStatus.error) {
        _setError('Connection failed: $error');
      }
    }
  }

  Future<void> disconnect() async {
    await _safeClose(preserveCache: true);
    _status = XmppStatus.disconnected;
    _errorMessage = null;
    notifyListeners();
  }

  void clearCache() {
    _contacts.clear();
    _messages.clear();
    _presenceByBareJid.clear();
    _chatStates.clear();
    _messagePersistor?.call('', const []);
    _rosterPersistor?.call(const []);
    notifyListeners();
  }

  void selectChat(String? bareJid) {
    _activeChatBareJid = bareJid;
    if (bareJid != null) {
      setMyChatState(bareJid, ChatState.ACTIVE);
    }
    notifyListeners();
  }

  void setRosterPersistor(void Function(List<ContactEntry> roster)? persistor) {
    _rosterPersistor = persistor;
  }

  void setMessagePersistor(
      void Function(String bareJid, List<ChatMessage> messages)? persistor) {
    _messagePersistor = persistor;
  }

  void seedRoster(List<ContactEntry> roster) {
    for (final entry in roster) {
      _ensureContact(entry.jid, name: entry.name, groups: entry.groups);
    }
  }

  void seedMessages(Map<String, List<ChatMessage>> messages) {
    for (final entry in messages.entries) {
      final bareJid = _bareJid(entry.key);
      _messages[bareJid] = List<ChatMessage>.from(entry.value);
      _ensureContact(bareJid);
    }
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
    chat.myState = ChatState.ACTIVE;
  }

  void setMyChatState(String bareJid, ChatState state) {
    final chatManager = _chatManager;
    if (chatManager == null) {
      return;
    }
    final chat = chatManager.getChat(Jid.fromFullJid(bareJid));
    chat.myState = state;
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
          _ensureContact(jid, name: buddy.name, groups: buddy.groups);
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

  void _setupPresence() {
    final connection = _connection;
    if (connection == null) {
      return;
    }
    final presenceManager = PresenceManager.getInstance(connection);
    _presenceSubscription?.cancel();
    _presenceSubscription = presenceManager.presenceStream.listen((presence) {
      final jid = presence.jid?.userAtDomain;
      if (jid == null || jid.isEmpty) {
        return;
      }
      _presenceByBareJid[_bareJid(jid)] = presence;
      notifyListeners();
    });
  }

  void _setupKeepalive() {
    final connection = _connection;
    if (connection == null) {
      return;
    }
    _smNonzaSubscription?.cancel();
    _smNonzaSubscription = connection.inNonzasStream.listen((nonza) {
      final xmlns = nonza.getAttribute('xmlns')?.value;
      if (nonza.name == 'a' && xmlns == 'urn:xmpp:sm:3') {
        final startedAt = _pendingSmAckAt;
        if (startedAt != null) {
          _pendingSmAckAt = null;
          _lastPingLatency = DateTime.now().difference(startedAt);
          _lastPingAt = DateTime.now();
          notifyListeners();
        }
      }
    });

    _pingSubscription?.cancel();
    _pingSubscription = connection.inStanzasStream.listen((stanza) {
      if (stanza is IqStanza) {
        final carbonsId = _carbonsRequestId;
        if (carbonsId != null && stanza.id == carbonsId) {
          _carbonsEnabled = stanza.type == IqStanzaType.RESULT;
          _carbonsRequestId = null;
          notifyListeners();
          return;
        }
        final id = stanza.id;
        if (id == null || !_pendingPings.containsKey(id)) {
          return;
        }
        if (stanza.type == IqStanzaType.RESULT || stanza.type == IqStanzaType.ERROR) {
          final startedAt = _pendingPings.remove(id);
          if (startedAt != null) {
            _lastPingLatency = DateTime.now().difference(startedAt);
            _lastPingAt = DateTime.now();
            notifyListeners();
          }
        }
      }
    });

    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isStreamManagementEnabled()) {
        _sendSmAckRequest();
      } else {
        if (_pendingPings.isNotEmpty) {
          _expireOldPing();
          return;
        }
        _sendPing();
      }
    });
    if (_isStreamManagementEnabled()) {
      _sendSmAckRequest();
    } else {
      _sendPing();
    }
    _requestCarbons();
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

    _chatStateSubscriptions[buddyJid]?.cancel();
    _chatStateSubscriptions[buddyJid] =
        chat.remoteStateStream.listen((state) {
      _chatStates[buddyJid] = state;
      notifyListeners();
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
    _messagePersistor?.call(normalized, List.unmodifiable(list));
  }

  void _ensureContact(String bareJid, {String? name, List<String>? groups}) {
    final normalized = _bareJid(bareJid);
    final index = _contacts.indexWhere((entry) => entry.jid == normalized);
    if (index == -1) {
      final entry = ContactEntry(jid: normalized, name: name, groups: groups ?? const []);
      _contacts.add(entry);
      _contacts.sort((a, b) => a.displayName.compareTo(b.displayName));
      notifyListeners();
      _rosterPersistor?.call(List.unmodifiable(_contacts));
      return;
    }
    final existing = _contacts[index];
    final nextName = (name != null && name.trim().isNotEmpty) ? name : existing.name;
    final nextGroups = (groups != null && groups.isNotEmpty) ? groups : existing.groups;
    if (nextName != existing.name || !_listEquals(nextGroups, existing.groups)) {
      _contacts[index] = existing.copyWith(name: nextName, groups: nextGroups);
      _contacts.sort((a, b) => a.displayName.compareTo(b.displayName));
      notifyListeners();
      _rosterPersistor?.call(List.unmodifiable(_contacts));
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  void _setError(String message) {
    _status = XmppStatus.error;
    _errorMessage = message;
    notifyListeners();
  }

  Future<void> _safeClose({required bool preserveCache}) async {
    _pingTimer?.cancel();
    _pingTimer = null;
    _smNonzaSubscription?.cancel();
    _smNonzaSubscription = null;
    _pingSubscription?.cancel();
    _pingSubscription = null;
    _pendingPings.clear();
    _pendingSmAckAt = null;
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    _rosterSubscription?.cancel();
    _rosterSubscription = null;
    _chatListSubscription?.cancel();
    _chatListSubscription = null;
    _presenceSubscription?.cancel();
    _presenceSubscription = null;
    for (final subscription in _chatMessageSubscriptions.values) {
      subscription.cancel();
    }
    _chatMessageSubscriptions.clear();
    for (final subscription in _chatStateSubscriptions.values) {
      subscription.cancel();
    }
    _chatStateSubscriptions.clear();

    _activeChatBareJid = null;
    _currentUserBareJid = null;
    _lastConnectionState = null;
    _rosterManager = null;
    _chatManager = null;
    if (!preserveCache) {
      _contacts.clear();
      _messages.clear();
    }
    _presenceByBareJid.clear();
    _chatStates.clear();
    _lastPingLatency = null;
    _lastPingAt = null;
    _carbonsEnabled = false;
    _carbonsRequestId = null;

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
    _sendPresence(_selfPresence);
  }

  void _sendPresence(PresenceData presence) {
    final connection = _connection;
    if (connection == null) {
      return;
    }
    debugPrint('XMPP sending presence ${presence.showElement} ${presence.status ?? ''}');
    final presenceManager = PresenceManager.getInstance(connection);
    presenceManager.sendPresence(presence);
  }

  void _requestCarbons() {
    final connection = _connection;
    if (connection == null || _carbonsRequestId != null) {
      return;
    }
    final id = AbstractStanza.getRandomId();
    final iqStanza = IqStanza(id, IqStanzaType.SET);
    iqStanza.addAttribute(XmppAttribute('xmlns', 'jabber:client'));
    final enable = XmppElement();
    enable.name = 'enable';
    enable.addAttribute(XmppAttribute('xmlns', 'urn:xmpp:carbons:2'));
    iqStanza.addChild(enable);
    _carbonsRequestId = id;
    connection.writeStanza(iqStanza);
  }

  void _sendPing() {
    final connection = _connection;
    if (connection == null || _currentUserBareJid == null) {
      return;
    }
    final domain = _domainFromBareJid(_currentUserBareJid!);
    if (domain.isEmpty) {
      return;
    }
    final id = AbstractStanza.getRandomId();
    final stanza = IqStanza(id, IqStanzaType.GET);
    stanza.toJid = Jid.fromFullJid(domain);
    final ping = XmppElement()..name = 'ping';
    ping.addAttribute(XmppAttribute('xmlns', 'urn:xmpp:ping'));
    stanza.addChild(ping);
    _pendingPings[id] = DateTime.now();
    connection.writeStanza(stanza);
  }

  void _sendSmAckRequest() {
    final connection = _connection;
    if (connection == null || !_isStreamManagementEnabled()) {
      return;
    }
    if (_pendingSmAckAt != null) {
      _expireSmAck();
      if (_pendingSmAckAt != null) {
        return;
      }
    }
    _pendingSmAckAt = DateTime.now();
    connection.streamManagementModule?.sendAckRequest();
  }

  void _expireSmAck() {
    final startedAt = _pendingSmAckAt;
    if (startedAt == null) {
      return;
    }
    if (DateTime.now().difference(startedAt).inSeconds > 10) {
      _pendingSmAckAt = null;
      _lastPingLatency = null;
      _lastPingAt = DateTime.now();
      notifyListeners();
    }
  }

  bool _isStreamManagementEnabled() {
    return _connection?.streamManagementModule?.streamState.streamManagementEnabled == true;
  }

  void _expireOldPing() {
    final now = DateTime.now();
    final expired = _pendingPings.entries
        .where((entry) => now.difference(entry.value).inSeconds > 10)
        .map((entry) => entry.key)
        .toList();
    for (final id in expired) {
      _pendingPings.remove(id);
    }
    if (expired.isNotEmpty) {
      _lastPingLatency = null;
      _lastPingAt = now;
      notifyListeners();
    }
  }
}
