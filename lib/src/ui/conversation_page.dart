import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../chat/chat_service.dart';
import '../data/database.dart';
import 'image_viewer.dart';
import 'theme.dart';

const List<String> _quickReactions = ['❤️', '👍', '😂', '😮', '😢', '🙏'];

class ConversationPage extends StatefulWidget {
  const ConversationPage({
    super.key,
    required this.service,
    required this.db,
    required this.peer,
  });

  final ChatService service;
  final AppDatabase db;
  final Peer peer;

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;
  Message? _replyingTo;
  StreamSubscription<List<Message>>? _readSub;

  String get _peerId => widget.peer.id;

  @override
  void initState() {
    super.initState();
    unawaited(widget.service.markConversationRead(_peerId));
    _readSub = widget.db.watchConversation(_peerId).listen((_) {
      unawaited(widget.service.markConversationRead(_peerId));
    });
  }

  @override
  void dispose() {
    _readSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    final replyTo = _replyingTo?.messageId;
    setState(() => _sending = true);
    try {
      await widget.service.sendText(_peerId, text, replyTo: replyTo);
      _controller.clear();
      setState(() => _replyingTo = null);
    } catch (error) {
      _toast('Could not send: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendImage() async {
    if (_sending) return;
    final replyTo = _replyingTo?.messageId;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 768,
        maxHeight: 768,
        imageQuality: 30,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => _sending = true);
      await widget.service.sendImage(_peerId, bytes, replyTo: replyTo);
      setState(() => _replyingTo = null);
    } catch (error) {
      _toast('Could not send photo: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _toast(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _react(Message m, String emoji) {
    // Toggle: tapping the same reaction again clears it.
    final mine = _myReaction;
    final next = (mine != null && mine[m.messageId] == emoji) ? '' : emoji;
    unawaited(widget.service.sendReaction(_peerId, m.messageId, next));
    HapticFeedback.lightImpact();
  }

  Map<String, String>? _myReaction; // messageId -> my emoji, filled per build.

  void _openActions(Message m) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MessageActions(
        message: m,
        onReact: (e) {
          Navigator.of(ctx).pop();
          _react(m, e);
        },
        onReply: () {
          Navigator.of(ctx).pop();
          setState(() => _replyingTo = m);
        },
        onCopy: m.kind == MessageKind.text
            ? () {
                Navigator.of(ctx).pop();
                Clipboard.setData(ClipboardData(text: m.body));
                _toast('Copied');
              }
            : null,
        onOpenImage: m.kind == MessageKind.image && m.mediaBytes != null
            ? () {
                Navigator.of(ctx).pop();
                _openImage(m);
              }
            : null,
      ),
    );
  }

  void _openImage(Message m) {
    if (m.mediaBytes == null) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, _, _) =>
            ImageViewerPage(bytes: m.mediaBytes!, heroTag: m.messageId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 4,
        title: StreamBuilder<Peer?>(
          stream: widget.db.watchPeer(_peerId),
          initialData: widget.peer,
          builder: (context, peerSnap) {
            final peer = peerSnap.data ?? widget.peer;
            return Row(
              children: [
                _Avatar(label: peerLabelFor(peer, _peerId), size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        peerLabelFor(peer, _peerId),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                      _ChannelLine(service: widget.service, peerId: _peerId),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Set nickname',
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () async {
              final peer = await widget.db.peerById(_peerId);
              if (peer != null && mounted) await _rename(peer);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: widget.db.watchConversation(_peerId),
              builder: (context, msgSnap) {
                final messages = msgSnap.data ?? const [];
                if (messages.isEmpty) return const _EmptyConversation();
                final byId = {for (final m in messages) m.messageId: m};
                return StreamBuilder<List<Reaction>>(
                  stream: widget.db.watchReactions(_peerId),
                  builder: (context, reactSnap) {
                    final reactions = reactSnap.data ?? const [];
                    final byMessage = <String, List<Reaction>>{};
                    _myReaction = {};
                    for (final r in reactions) {
                      byMessage.putIfAbsent(r.messageId, () => []).add(r);
                      if (r.fromMe) _myReaction![r.messageId] = r.emoji;
                    }
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      itemCount: messages.length,
                      itemBuilder: (context, i) {
                        final m = messages[messages.length - 1 - i];
                        return _MessageBubble(
                          message: m,
                          repliedTo:
                              m.replyToMessageId == null ? null : byId[m.replyToMessageId],
                          reactions: byMessage[m.messageId] ?? const [],
                          onLongPress: () => _openActions(m),
                          onTapImage: () => _openImage(m),
                          onReply: () => setState(() => _replyingTo = m),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          if (_replyingTo != null)
            _ReplyBanner(
              message: _replyingTo!,
              onCancel: () => setState(() => _replyingTo = null),
            ),
          _Composer(
            controller: _controller,
            sending: _sending,
            onSend: _send,
            onAttach: _sendImage,
          ),
        ],
      ),
    );
  }

  Future<void> _rename(Peer peer) async {
    final controller = TextEditingController(text: peer.nickname ?? '');
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nickname'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'A name just for you'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    await widget.db.setPeerNickname(_peerId, result.isEmpty ? null : result);
    await widget.service.refreshPeerName(_peerId);
  }
}

/// A round monogram avatar derived from the peer's label.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.label, this.size = 40});
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial =
        label.trim().isEmpty ? '?' : label.trim().characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2F3A), Color(0xFF1B1F28)],
        ),
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: Stone.accent,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.repliedTo,
    required this.reactions,
    required this.onLongPress,
    required this.onTapImage,
    required this.onReply,
  });

  final Message message;
  final Message? repliedTo;
  final List<Reaction> reactions;
  final VoidCallback onLongPress;
  final VoidCallback onTapImage;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final isMine = message.direction == MessageDirection.outbound;
    final isImage = message.kind == MessageKind.image && message.mediaBytes != null;

    final bubble = GestureDetector(
      onLongPress: onLongPress,
      onTap: isImage ? onTapImage : null,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 286),
        padding: isImage
            ? const EdgeInsets.all(4)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isMine ? Stone.sent : Stone.surfaceHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(Stone.rBubble),
            topRight: const Radius.circular(Stone.rBubble),
            bottomLeft: Radius.circular(isMine ? Stone.rBubble : 6),
            bottomRight: Radius.circular(isMine ? 6 : Stone.rBubble),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (repliedTo != null) _ReplyQuote(message: repliedTo!, onTint: isMine),
            if (isImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(Stone.rBubble - 6),
                child: Hero(
                  tag: message.messageId,
                  child: Image.memory(message.mediaBytes!, fit: BoxFit.cover),
                ),
              )
            else
              Text(
                message.body,
                style: TextStyle(
                  color: isMine ? Stone.accentInk : Stone.ink,
                  fontSize: 15.5,
                  height: 1.3,
                ),
              ),
          ],
        ),
      ),
    );

    return Dismissible(
      key: ValueKey('swipe-${message.messageId}'),
      direction: DismissDirection.startToEnd,
      dismissThresholds: const {DismissDirection.startToEnd: 0.26},
      movementDuration: const Duration(milliseconds: 180),
      confirmDismiss: (_) async {
        HapticFeedback.lightImpact();
        onReply();
        return false; // snap back; we only use the gesture to start a reply.
      },
      background: const Padding(
        padding: EdgeInsets.only(left: 28),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Icon(Icons.reply_rounded, color: Stone.accent),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Align(
              alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
              child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: reactions.isEmpty ? 0 : 12),
                  child: bubble,
                ),
                if (reactions.isNotEmpty)
                  Positioned(
                    bottom: -2,
                    right: isMine ? 8 : null,
                    left: isMine ? null : 8,
                    child: _ReactionChips(reactions: reactions),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              isMine ? 0 : 6,
              2,
              isMine ? 6 : 0,
              reactions.isEmpty ? 0 : 10,
            ),
            child: _MetaLine(message: message, isMine: isMine),
          ),
          ],
        ),
      ),
    );
  }
}

/// A quoted preview of the message being replied to, shown inside a bubble.
class _ReplyQuote extends StatelessWidget {
  const _ReplyQuote({required this.message, required this.onTint});
  final Message message;
  final bool onTint;

  @override
  Widget build(BuildContext context) {
    final fg = onTint ? Stone.accentInk : Stone.ink;
    final preview = message.kind == MessageKind.image ? 'Photo' : message.body;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
      decoration: BoxDecoration(
        color: (onTint ? Stone.accentInk : Stone.accent).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: (onTint ? Stone.accentInk : Stone.accent).withValues(alpha: 0.5),
            width: 3,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.kind == MessageKind.image && message.mediaBytes != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.memory(message.mediaBytes!,
                    width: 26, height: 26, fit: BoxFit.cover),
              ),
            ),
          Flexible(
            child: Text(
              preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: fg.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionChips extends StatelessWidget {
  const _ReactionChips({required this.reactions});
  final List<Reaction> reactions;

  @override
  Widget build(BuildContext context) {
    // Group identical emojis with a count.
    final counts = <String, int>{};
    for (final r in reactions) {
      counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Stone.surface,
        borderRadius: BorderRadius.circular(Stone.rPill),
        border: Border.all(color: Stone.bg, width: 2),
      ),
      child: Text(
        counts.entries
            .map((e) => e.value > 1 ? '${e.key}${e.value}' : e.key)
            .join(' '),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.message, required this.isMine});
  final Message message;
  final bool isMine;

  static String _formatTime(int ms) {
    final t = DateTime.fromMillisecondsSinceEpoch(ms);
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final time = _formatTime(message.timestampMs);
    final children = <Widget>[
      Text(time, style: const TextStyle(fontSize: 11, color: Stone.inkFaint)),
    ];
    if (isMine) {
      final (icon, color) = _stateIcon(message.state);
      if (icon != null) {
        children
          ..add(const SizedBox(width: 4))
          ..add(Icon(icon, size: 13, color: color));
      }
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  (IconData?, Color) _stateIcon(MessageDeliveryState s) => switch (s) {
        MessageDeliveryState.queued => (Icons.schedule, Stone.inkFaint),
        MessageDeliveryState.sent => (Icons.check, Stone.inkFaint),
        MessageDeliveryState.acked => (Icons.done_all, Stone.inkFaint),
        MessageDeliveryState.seen => (Icons.done_all, Stone.accent),
        MessageDeliveryState.failed => (Icons.error_outline, Color(0xFFF87171)),
        MessageDeliveryState.received => (null, Stone.inkFaint),
      };
}

/// The long-press sheet: a quick-react row + actions.
class _MessageActions extends StatelessWidget {
  const _MessageActions({
    required this.message,
    required this.onReact,
    required this.onReply,
    this.onCopy,
    this.onOpenImage,
  });

  final Message message;
  final ValueChanged<String> onReact;
  final VoidCallback onReply;
  final VoidCallback? onCopy;
  final VoidCallback? onOpenImage;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: Stone.surfaceHigh,
                borderRadius: BorderRadius.circular(Stone.rPill),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (final e in _quickReactions)
                    InkWell(
                      borderRadius: BorderRadius.circular(Stone.rPill),
                      onTap: () => onReact(e),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(e, style: const TextStyle(fontSize: 26)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Stone.surfaceHigh,
                borderRadius: BorderRadius.circular(Stone.rCard),
              ),
              child: Column(
                children: [
                  _action(Icons.reply_rounded, 'Reply', onReply),
                  if (onOpenImage != null) ...[
                    const Divider(),
                    _action(Icons.fullscreen_rounded, 'View photo', onOpenImage!),
                  ],
                  if (onCopy != null) ...[
                    const Divider(),
                    _action(Icons.copy_rounded, 'Copy', onCopy!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Stone.ink),
      title: Text(label, style: const TextStyle(color: Stone.ink)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Stone.rCard)),
    );
  }
}

class _ReplyBanner extends StatelessWidget {
  const _ReplyBanner({required this.message, required this.onCancel});
  final Message message;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final preview = message.kind == MessageKind.image ? 'Photo' : message.body;
    return Container(
      color: Stone.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Container(width: 3, height: 34, color: Stone.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Replying to',
                    style: TextStyle(fontSize: 11, color: Stone.accent)),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Stone.inkDim),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, size: 38, color: Stone.inkFaint),
            const SizedBox(height: 14),
            const Text(
              'Say hello',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: Stone.ink),
            ),
            const SizedBox(height: 6),
            const Text(
              'Messages are end-to-end encrypted and stay between the two of you.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, height: 1.4, color: Stone.inkDim),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController controller;
  final bool sending;
  final Future<void> Function() onSend;
  final Future<void> Function() onAttach;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Stone.bg,
        border: Border(top: BorderSide(color: Stone.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Send a photo',
                onPressed: sending ? null : onAttach,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                color: Stone.inkDim,
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  minLines: 1,
                  maxLines: 5,
                  style: const TextStyle(fontSize: 15.5, color: Stone.ink),
                  decoration: const InputDecoration(
                    hintText: 'Message',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SendButton(sending: sending, onSend: onSend),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.sending, required this.onSend});
  final bool sending;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: sending ? null : onSend,
      child: AnimatedScale(
        scale: sending ? 0.92 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: Stone.accent,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_upward_rounded, color: Stone.accentInk),
        ),
      ),
    );
  }
}

/// The "how am I reaching this peer" line under the name.
class _ChannelLine extends StatelessWidget {
  const _ChannelLine({required this.service, required this.peerId});

  final ChatService service;
  final String peerId;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: service.onlineIdentities,
      builder: (context, _, _) => ValueListenableBuilder<bool>(
        valueListenable: service.relayReachable,
        builder: (context, _, _) {
          final (icon, color, label) = switch (service.channelFor(peerId)) {
            PeerChannel.bluetooth => (
                Icons.bluetooth_connected,
                Stone.online,
                'Bluetooth',
              ),
            PeerChannel.web => (
                Icons.cloud_done_outlined,
                Stone.accent,
                'Online · web',
              ),
            PeerChannel.offline => (
                Icons.cloud_off_outlined,
                Stone.inkFaint,
                'Offline · queued',
              ),
          };
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 11.5, color: color)),
            ],
          );
        },
      ),
    );
  }
}
