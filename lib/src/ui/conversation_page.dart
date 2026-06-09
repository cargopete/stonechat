import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../chat/chat_service.dart';
import '../data/database.dart';

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
  StreamSubscription<List<Message>>? _readSub;

  @override
  void initState() {
    super.initState();
    // Send a read receipt now, and again whenever new messages land while the
    // thread is open (so the peer sees "seen" in near-real-time).
    unawaited(widget.service.markConversationRead(widget.peer.id));
    _readSub = widget.db.watchConversation(widget.peer.id).listen((_) {
      unawaited(widget.service.markConversationRead(widget.peer.id));
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
    setState(() => _sending = true);
    try {
      await widget.service.sendText(widget.peer.id, text);
      _controller.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendImage() async {
    if (_sending) return;
    try {
      // Compress hard — Bluetooth throughput is low, so keep photos small. At
      // ~768px / quality 30 a typical photo is ~20–35 KB, which crosses the link
      // in a few seconds rather than tens, while still looking fine on a phone.
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
      await widget.service.sendImage(widget.peer.id, bytes);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send photo: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
          decoration: const InputDecoration(
            hintText: 'A name just for you',
          ),
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
    await widget.db.setPeerNickname(peer.id, result.isEmpty ? null : result);
    await widget.service.refreshPeerName(peer.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<Peer?>(
          stream: widget.db.watchPeer(widget.peer.id),
          initialData: widget.peer,
          builder: (context, peerSnap) {
            final peer = peerSnap.data ?? widget.peer;
            return ValueListenableBuilder<Set<String>>(
              valueListenable: widget.service.onlineIdentities,
              builder: (context, online, _) {
                final isOnline = online.contains(widget.peer.id);
                return Row(
                  children: [
                    Icon(Icons.circle,
                        size: 12, color: isOnline ? Colors.green : Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        peerLabelFor(peer, widget.peer.id),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Set nickname',
            icon: const Icon(Icons.drive_file_rename_outline),
            onPressed: () async {
              final peer = await widget.db.peerById(widget.peer.id);
              if (peer != null) await _rename(peer);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: widget.db.watchConversation(widget.peer.id),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? const [];
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    // reverse: newest at the bottom.
                    final message = messages[messages.length - 1 - i];
                    return _MessageBubble(message: message);
                  },
                );
              },
            ),
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
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final isMine = message.direction == MessageDirection.outbound;
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isMine ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (message.kind == MessageKind.image && message.mediaBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(message.mediaBytes!, fit: BoxFit.cover),
              )
            else if (message.kind == MessageKind.image)
              // Inbound image still arriving (frames not all reassembled yet).
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                child: Icon(Icons.image_outlined),
              )
            else
              Text(message.body),
            if (isMine && _stateLabel(message.state).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _stateLabel(message.state),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _stateLabel(MessageDeliveryState state) => switch (state) {
        MessageDeliveryState.queued => 'queued',
        MessageDeliveryState.sent => 'sent',
        MessageDeliveryState.acked => 'delivered',
        MessageDeliveryState.seen => 'seen',
        MessageDeliveryState.failed => 'failed',
        MessageDeliveryState.received => '',
      };
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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Send a photo',
              onPressed: sending ? null : onAttach,
              icon: const Icon(Icons.photo_outlined),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'Message',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: sending ? null : onSend,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
