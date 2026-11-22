import 'package:material_ui/material_ui.dart';

import 'brand.dart';

/// Lets an app translate the few words the shared chat screen shows itself.
/// The default leaves text as it is.
class UiText {
  UiText._();
  static String Function(String) tr = (s) => s;
}

/// One message as the chat screen draws it.
class ChatMsg {
  const ChatMsg({
    required this.text,
    required this.name,
    required this.mine,
    this.at,
    this.seen = false,
    this.badge = '',
  });

  /// Who sent it, as a small label: "SHOP", "RIDER" or "CUSTOMER".
  final String badge;
  final String text;
  final String name;
  final bool mine;
  final DateTime? at;

  /// For my own messages: has the other side opened the chat since?
  final bool seen;
}

/// A full chat screen: bubbles, quick replies and a message box. The apps
/// feed it a stream of messages and a send function.
class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.title,
    this.subtitle = '',
    required this.messages,
    required this.onSend,
    this.quickReplies = const [],
    this.onOpened,
    this.loadError,
    this.onRetry,
    this.closedNote,
  });

  final String title;
  final String subtitle;
  final List<ChatMsg> messages;
  final Future<void> Function(String text) onSend;
  final List<String> quickReplies;

  /// Called when the page opens and whenever new messages arrive while it is
  /// open (the apps use it to mark messages as read).
  final VoidCallback? onOpened;

  /// Set when the messages could not be loaded: shown instead of the
  /// "no messages" text, with a Try again button.
  final String? loadError;
  final VoidCallback? onRetry;

  /// Set when the order is finished (delivered or cancelled): the chat is
  /// read-only and this text is shown instead of the message box.
  final String? closedNote;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  String? _error;
  int _seen = -1;

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final t = (preset ?? _text.text).trim();
    if (t.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSend(t);
      if (preset == null) _text.clear();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = '$e'.contains('permission-denied')
              ? UiText.tr(
                  'This chat is closed or not switched on yet. If the order is still open, ask Alpha LPG to publish the latest database rules.',
                )
              : UiText.tr('Could not send. Check your internet.'),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _clock(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            if (widget.subtitle.isNotEmpty)
              Text(
                widget.subtitle,
                style: TextStyle(
                  color: pal.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Builder(
              builder: (context) {
                final list = widget.messages;
                if (list.length != _seen) {
                  _seen = list.length;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    widget.onOpened?.call();
                    if (_scroll.hasClients) {
                      _scroll.animateTo(
                        0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                }
                if (list.isEmpty && widget.loadError != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            size: 40,
                            color: Brand.danger,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.loadError!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: pal.ink, height: 1.4),
                          ),
                          if (widget.onRetry != null) ...[
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: widget.onRetry,
                              child: Text(UiText.tr('Try again')),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        UiText.tr(
                          'No messages yet. Say hello, or tap a quick reply below.',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: pal.muted, height: 1.4),
                      ),
                    ),
                  );
                }
                final rev = list.reversed.toList();
                return ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  itemCount: rev.length,
                  itemBuilder: (_, i) {
                    final m = rev[i];
                    return Align(
                      alignment: m.mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                        ),
                        decoration: BoxDecoration(
                          color: m.mine ? Brand.blueDark : pal.card,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(m.mine ? 16 : 4),
                            bottomRight: Radius.circular(m.mine ? 4 : 16),
                          ),
                          border: m.mine ? null : Border.all(color: pal.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!m.mine || m.badge.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!m.mine)
                                    Flexible(
                                      child: Text(
                                        m.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Brand.blueDark,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  if (m.badge.isNotEmpty) ...[
                                    if (!m.mine) const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _badgeColor(m.badge),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        UiText.tr(m.badge),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            Text(
                              m.text,
                              style: TextStyle(
                                color: m.mine ? Colors.white : pal.ink,
                                height: 1.35,
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (m.at != null)
                                    Text(
                                      _clock(m.at!),
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: m.mine
                                            ? Colors.white70
                                            : pal.muted,
                                      ),
                                    ),
                                  if (m.mine) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      m.seen
                                          ? Icons.done_all_rounded
                                          : Icons.done_rounded,
                                      size: 15,
                                      color: m.seen
                                          ? const Color(0xFF8FE3FF)
                                          : Colors.white70,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                _error!,
                style: const TextStyle(color: Brand.danger, fontSize: 13),
              ),
            ),
          if (widget.closedNote == null && widget.quickReplies.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  for (final q in widget.quickReplies)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ActionChip(
                        label: Text(UiText.tr(q)),
                        onPressed: _sending ? null : () => _send(q),
                      ),
                    ),
                ],
              ),
            ),
          if (widget.closedNote != null)
            SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: pal.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: pal.line),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, color: pal.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.closedNote!,
                        style: TextStyle(color: pal.muted, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 500,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: UiText.tr('Type a message'),
                          counterText: '',
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      icon: const Icon(Icons.send_rounded),
                      tooltip: UiText.tr('Send'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Color _badgeColor(String badge) => switch (badge) {
  'RIDER' => const Color(0xFF1E8E4E),
  'CUSTOMER' => const Color(0xFFE8710A),
  _ => const Color(0xFF14427B),
};
