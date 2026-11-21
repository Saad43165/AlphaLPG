import 'package:material_ui/material_ui.dart';

import 'brand.dart';

/// One message as the chat screen draws it.
class ChatMsg {
  const ChatMsg({
    required this.text,
    required this.name,
    required this.mine,
    this.at,
    this.seen = false,
  });
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
  });

  final String title;
  final String subtitle;
  final List<ChatMsg> messages;
  final Future<void> Function(String text) onSend;
  final List<String> quickReplies;

  /// Called when the page opens and whenever new messages arrive while it is
  /// open (the apps use it to mark messages as read).
  final VoidCallback? onOpened;

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
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not send. Check your internet.');
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
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No messages yet. Say hello, or tap a quick reply below.',
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
                            if (!m.mine)
                              Text(
                                m.name,
                                style: const TextStyle(
                                  color: Brand.blueDark,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
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
          if (widget.quickReplies.isNotEmpty)
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
                        label: Text(q),
                        onPressed: _sending ? null : () => _send(q),
                      ),
                    ),
                ],
              ),
            ),
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
                      decoration: const InputDecoration(
                        hintText: 'Type a message',
                        counterText: '',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                    tooltip: 'Send',
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
