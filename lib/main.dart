import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmpp_stone/xmpp_stone.dart';

import 'models/chat_message.dart';
import 'storage/account_record.dart';
import 'storage/storage_service.dart';
import 'xmpp/xmpp_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Log.logLevel = LogLevel.VERBOSE;
  Log.logXmpp = true;
  runApp(const ZimpyApp());
}

class ZimpyApp extends StatefulWidget {
  const ZimpyApp({super.key});

  @override
  State<ZimpyApp> createState() => _ZimpyAppState();
}

class _ZimpyAppState extends State<ZimpyApp> {
  final XmppService _service = XmppService();
  final StorageService _storage = StorageService();
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _storage.initialize();
  }

  @override
  void dispose() {
    _service.dispose();
    _storage.lock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF1F6F8B),
      onPrimary: Color(0xFFFDFCF8),
      secondary: Color(0xFFEE6C4D),
      onSecondary: Color(0xFFFDFCF8),
      surface: Color(0xFFF7F2E7),
      onSurface: Color(0xFF1B1A17),
      background: Color(0xFFF1EADF),
      onBackground: Color(0xFF1B1A17),
      error: Color(0xFFB00020),
      onError: Color(0xFFFDFCF8),
    );

    return MaterialApp(
      title: 'Zimpy',
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: colorScheme.background,
        fontFamily: 'Georgia',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFDFBF6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      home: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _SplashScreen();
          }
          return _Gatekeeper(service: _service, storage: _storage);
        },
      ),
    );
  }
}

class _Gatekeeper extends StatefulWidget {
  const _Gatekeeper({required this.service, required this.storage});

  final XmppService service;
  final StorageService storage;

  @override
  State<_Gatekeeper> createState() => _GatekeeperState();
}

class _GatekeeperState extends State<_Gatekeeper> {
  bool _checkingPin = true;
  bool _hasPin = false;

  @override
  void initState() {
    super.initState();
    _loadPinState();
  }

  Future<void> _loadPinState() async {
    final hasPin = await widget.storage.hasPin();
    if (!mounted) {
      return;
    }
    setState(() {
      _hasPin = hasPin;
      _checkingPin = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingPin) {
      return const _SplashScreen();
    }
    if (!_hasPin) {
      return _PinSetupScreen(
        onPinSet: (pin) async {
          await widget.storage.setupPin(pin);
          if (!mounted) {
            return;
          }
          setState(() {
            _hasPin = true;
          });
        },
      );
    }
    if (!widget.storage.isUnlocked) {
      return _PinUnlockScreen(
        onUnlocked: (pin) async {
          await widget.storage.unlock(pin);
          if (!mounted) {
            return;
          }
          setState(() {});
        },
      );
    }
    return ZimpyHome(service: widget.service, storage: widget.storage);
  }
}

class ZimpyHome extends StatefulWidget {
  const ZimpyHome({super.key, required this.service, required this.storage});

  final XmppService service;
  final StorageService storage;

  @override
  State<ZimpyHome> createState() => _ZimpyHomeState();
}

class _ZimpyHomeState extends State<ZimpyHome> {
  final TextEditingController _jidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController(text: '5222');
  final TextEditingController _resourceController = TextEditingController(text: 'zimpy');
  final TextEditingController _manualContactController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _loadedAccount = false;
  bool _clearingCache = false;
  Timer? _typingDebounce;
  Timer? _idleTimer;
  ChatState? _lastSentChatState;

  @override
  void initState() {
    super.initState();
    widget.service.setRosterPersistor((roster) => widget.storage.storeRoster(roster));
    widget.service.setMessagePersistor(
      (bareJid, messages) => widget.storage.storeMessagesForJid(bareJid, messages),
    );
    _seedRoster();
    _seedMessages();
    _loadAccount();
  }

  Future<void> _seedRoster() async {
    final roster = widget.storage.loadRoster();
    widget.service.seedRoster(roster);
  }

  Future<void> _seedMessages() async {
    final messages = widget.storage.loadMessages();
    widget.service.seedMessages(messages);
  }

  Future<void> _loadAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJid = prefs.getString('zimpy_last_jid');
    final account = AccountRecord.fromMap(widget.storage.loadAccount());
    if (!mounted) {
      return;
    }
    setState(() {
      if (cachedJid != null && cachedJid.isNotEmpty) {
        _jidController.text = cachedJid;
      }
      if (account != null) {
        _jidController.text = account.jid;
        _passwordController.text = account.password;
        _hostController.text = account.host;
        _portController.text = account.port.toString();
        _resourceController.text = account.resource;
      }
      _loadedAccount = true;
    });
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _idleTimer?.cancel();
    _jidController.dispose();
    _passwordController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _resourceController.dispose();
    _manualContactController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.service,
      builder: (context, _) {
        final service = widget.service;
        if (!service.isConnected) {
          return _buildLogin(context, service);
        }
        return _buildClient(context, service);
      },
    );
  }

  Widget _buildLogin(BuildContext context, XmppService service) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final stateLabel = service.lastConnectionState?.name ?? 'Idle';

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7E7CE), Color(0xFFE3F0F1), Color(0xFFFDFBF7)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: size.width > 640 ? 520 : double.infinity),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Zimpy',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A modern XMPP client built for secure servers.',
                    style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Connect', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _jidController,
                          enabled: !service.isConnecting,
                          decoration: const InputDecoration(
                            labelText: 'JID',
                            hintText: 'user@domain',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          enabled: !service.isConnecting,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _hostController,
                                enabled: !service.isConnecting,
                                decoration: const InputDecoration(
                                  labelText: 'Host (optional)',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _portController,
                                enabled: !service.isConnecting,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Port',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _resourceController,
                          enabled: !service.isConnecting,
                          decoration: const InputDecoration(
                            labelText: 'Resource',
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: service.isConnecting ? null : _handleConnect,
                                child: Text(service.isConnecting ? 'Connecting...' : 'Connect'),
                              ),
                            ),
                          ],
                        ),
                        if (!_loadedAccount) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Unlocking storage...',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          'Status: ${service.status.name} · $stateLabel',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (service.errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            service.errorMessage!,
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                          ),
                        ]
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClient(BuildContext context, XmppService service) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        final activeChat = service.activeChatBareJid;

        return Scaffold(
          appBar: AppBar(
            title: Text('Signed in as ${service.currentUserBareJid ?? ''}'),
            actions: [
              _PresenceMenu(service: service),
              TextButton(
                onPressed: _clearingCache ? null : _confirmClearCache,
                child: const Text('Clear cache'),
              ),
              TextButton(
                onPressed: service.disconnect,
                child: const Text('Disconnect'),
              ),
              const SizedBox(width: 12),
            ],
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFDFBF7), Color(0xFFE8F1F2)],
              ),
            ),
            child: isWide
                ? Row(
                    children: [
                      SizedBox(
                        width: 320,
                        child: _buildRosterPane(context, service, isWide: true),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: _buildChatPane(
                          context,
                          service,
                          activeChat,
                          showBack: false,
                        ),
                      ),
                    ],
                  )
                : activeChat == null
                    ? _buildRosterPane(context, service, isWide: false)
                    : _buildChatPane(
                        context,
                        service,
                        activeChat,
                        showBack: true,
                      ),
          ),
        );
      },
    );
  }

  Widget _buildRosterPane(BuildContext context, XmppService service, {required bool isWide}) {
    final theme = Theme.of(context);
    final contacts = service.contacts;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chats', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualContactController,
                    decoration: const InputDecoration(
                      labelText: 'Start chat with JID',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    service.addManualContact(_manualContactController.text);
                    _manualContactController.clear();
                  },
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: contacts.isEmpty
                  ? Center(
                      child: Text(
                        'No contacts yet. Add one above.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.separated(
                      itemCount: contacts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final contact = contacts[index];
                        final jid = contact.jid;
                        final latest = service.messagesFor(jid).lastOrNull;
                        final presence = service.presenceLabelFor(jid);
                        final groups = contact.groups;
                        final groupsLabel = groups.isEmpty ? null : groups.join(', ');
                        return InkWell(
                          onTap: () => service.selectChat(jid),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: theme.colorScheme.outlineVariant),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(contact.displayName, style: theme.textTheme.titleMedium),
                                if (contact.displayName != jid) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    jid,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  presence,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                if (groupsLabel != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    groupsLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                                if (latest != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    latest.body,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (!isWide && service.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                service.errorMessage!,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildChatPane(
    BuildContext context,
    XmppService service,
    String? activeChat,
    {
    required bool showBack,
  }) {
    final theme = Theme.of(context);
    final messages = activeChat == null ? const <ChatMessage>[] : service.messagesFor(activeChat);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                if (showBack)
                  IconButton(
                    onPressed: () => service.selectChat(null),
                    icon: const Icon(Icons.arrow_back),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeChat ?? 'Select a chat',
                        style: theme.textTheme.titleLarge,
                      ),
                      Text(
                        activeChat == null
                            ? 'Secure connection active'
                            : service.chatStateLabelFor(activeChat).isNotEmpty
                                ? service.chatStateLabelFor(activeChat)
                                : 'Secure connection active',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: activeChat == null
                ? Center(
                    child: Text(
                      'Pick a contact to start messaging.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      return _MessageBubble(message: message);
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: activeChat != null,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                    ),
                    onChanged: (value) {
                      if (activeChat == null) {
                        return;
                      }
                      _handleTypingState(service, activeChat, value);
                    },
                    onSubmitted: (_) => _sendMessage(activeChat),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: activeChat == null ? null : () => _sendMessage(activeChat),
                  child: const Text('Send'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleConnect() {
    final port = int.tryParse(_portController.text.trim()) ?? 5222;
    final account = AccountRecord(
      jid: _jidController.text.trim(),
      password: _passwordController.text,
      host: _hostController.text.trim(),
      port: port,
      resource: _resourceController.text.trim().isEmpty ? 'zimpy' : _resourceController.text.trim(),
    );
    widget.storage.storeAccount(account.toMap());
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('zimpy_last_jid', account.jid);
    });
    widget.service.connect(
      jid: account.jid,
      password: account.password,
      resource: account.resource,
      host: account.host,
      port: port,
    );
  }

  void _sendMessage(String? activeChat) {
    if (activeChat == null) {
      return;
    }
    final text = _messageController.text;
    _messageController.clear();
    widget.service.sendMessage(toBareJid: activeChat, text: text);
    _setChatState(activeChat, ChatState.ACTIVE);
  }

  void _handleTypingState(XmppService service, String activeChat, String value) {
    _typingDebounce?.cancel();
    _idleTimer?.cancel();

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _setChatState(activeChat, ChatState.PAUSED);
    } else {
      _typingDebounce = Timer(const Duration(milliseconds: 350), () {
        _setChatState(activeChat, ChatState.COMPOSING);
      });
    }

    _idleTimer = Timer(const Duration(seconds: 5), () {
      if (_messageController.text.trim().isEmpty) {
        _setChatState(activeChat, ChatState.INACTIVE);
      }
    });
  }

  void _setChatState(String bareJid, ChatState state) {
    if (_lastSentChatState == state) {
      return;
    }
    _lastSentChatState = state;
    widget.service.setMyChatState(bareJid, state);
  }

  Future<void> _confirmClearCache() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear cached data?'),
          content: const Text('This removes cached roster and messages from this device.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );
    if (shouldClear != true) {
      return;
    }
    setState(() => _clearingCache = true);
    await widget.storage.clearRoster();
    await widget.storage.storeMessagesForJid('', const []);
    widget.service.clearCache();
    if (mounted) {
      setState(() => _clearingCache = false);
    }
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOutgoing = message.outgoing == true;
    final alignment = isOutgoing ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = isOutgoing ? theme.colorScheme.primary : theme.colorScheme.surface;
    final textColor = isOutgoing ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16),
          border: isOutgoing ? null : Border.all(color: theme.colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          message.body,
          style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
        ),
      ),
    );
  }
}

extension ListLastOrNull<T> on List<T> {
  T? get lastOrNull => isEmpty ? null : last;
}

class _PresenceMenu extends StatelessWidget {
  const _PresenceMenu({required this.service});

  final XmppService service;

  @override
  Widget build(BuildContext context) {
    final isOnline = service.isConnected;
    final latencyMs = service.lastPingLatency?.inMilliseconds;
    final latencyLabel = latencyMs == null ? '--' : '$latencyMs ms';
    return PopupMenuButton<_PresenceAction>(
      tooltip: 'Set presence',
      icon: const Icon(Icons.circle_outlined),
      onSelected: (action) async {
        switch (action) {
          case _PresenceAction.online:
            service.setSelfPresence(show: PresenceShowElement.CHAT, status: service.selfPresence.status);
            break;
          case _PresenceAction.away:
            service.setSelfPresence(show: PresenceShowElement.AWAY, status: service.selfPresence.status);
            break;
          case _PresenceAction.dnd:
            service.setSelfPresence(show: PresenceShowElement.DND, status: service.selfPresence.status);
            break;
          case _PresenceAction.xa:
            service.setSelfPresence(show: PresenceShowElement.XA, status: service.selfPresence.status);
            break;
          case _PresenceAction.setStatus:
            final status = await _promptStatus(context, service.selfPresence.status ?? '');
            if (status != null) {
              service.setSelfPresence(show: service.selfPresence.showElement ?? PresenceShowElement.CHAT, status: status);
            }
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Text('Session: ${isOnline ? 'online' : 'offline'}'),
        ),
        PopupMenuItem(
          enabled: false,
          child: Text('Latency: $latencyLabel'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: _PresenceAction.online, child: Text('Online')),
        const PopupMenuItem(value: _PresenceAction.away, child: Text('Away')),
        const PopupMenuItem(value: _PresenceAction.dnd, child: Text('Do not disturb')),
        const PopupMenuItem(value: _PresenceAction.xa, child: Text('Extended away')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: _PresenceAction.setStatus, child: Text('Set status message...')),
      ],
    );
  }
}

enum _PresenceAction { online, away, dnd, xa, setStatus }

Future<String?> _promptStatus(BuildContext context, String current) async {
  final controller = TextEditingController(text: current);
  String? result;
  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Status message'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Message'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              result = controller.text.trim();
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
  controller.dispose();
  return result;
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _PinSetupScreen extends StatefulWidget {
  const _PinSetupScreen({required this.onPinSet});

  final Future<void> Function(String pin) onPinSet;

  @override
  State<_PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<_PinSetupScreen> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Set a PIN', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 12),
                TextField(
                  controller: _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'PIN'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Confirm PIN'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: Text(_submitting ? 'Setting...' : 'Set PIN'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final pin = _pinController.text.trim();
    final confirm = _confirmController.text.trim();
    if (pin.isEmpty || pin.length < 4) {
      setState(() => _error = 'Choose a PIN with at least 4 digits.');
      return;
    }
    if (pin != confirm) {
      setState(() => _error = 'PIN entries do not match.');
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      await widget.onPinSet(pin);
    } catch (error) {
      setState(() => _error = 'Failed to set PIN: $error');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

class _PinUnlockScreen extends StatefulWidget {
  const _PinUnlockScreen({required this.onUnlocked});

  final Future<void> Function(String pin) onUnlocked;

  @override
  State<_PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<_PinUnlockScreen> {
  final TextEditingController _pinController = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Unlock', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 12),
                TextField(
                  controller: _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'PIN'),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: Text(_submitting ? 'Unlocking...' : 'Unlock'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      setState(() => _error = 'Enter your PIN.');
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      await widget.onUnlocked(pin);
    } catch (_) {
      setState(() => _error = 'Incorrect PIN.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}
