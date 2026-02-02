import 'package:flutter/material.dart';
import 'package:xmpp_stone/xmpp_stone.dart';

import 'models/chat_message.dart';
import 'xmpp/xmpp_service.dart';

void main() {
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

  @override
  void dispose() {
    _service.dispose();
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
      home: ZimpyHome(service: _service),
    );
  }
}

class ZimpyHome extends StatefulWidget {
  const ZimpyHome({super.key, required this.service});

  final XmppService service;

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

  @override
  void dispose() {
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
                        final jid = contacts[index];
                        final latest = service.messagesFor(jid).lastOrNull;
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
                                Text(jid, style: theme.textTheme.titleMedium),
                                if (latest != null) ...[
                                  const SizedBox(height: 6),
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
                        'Secure connection active',
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
    widget.service.connect(
      jid: _jidController.text,
      password: _passwordController.text,
      resource: _resourceController.text.trim().isEmpty ? 'zimpy' : _resourceController.text.trim(),
      host: _hostController.text,
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
