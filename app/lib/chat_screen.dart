// Developed by Codesoftwares
import 'dart:async';
import 'package:flutter/material.dart';
import 'api.dart';
import 'theme.dart';
import 'widgets.dart';

/// Simple polling chat (every 4 s while the screen is open). Fine for an MVP; switch to WebSocket later.
class ChatScreen extends StatefulWidget {
  final String interestId, name;
  final String? memberId;
  const ChatScreen({super.key, required this.interestId, required this.name, this.memberId});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController(), _scroll = ScrollController();
  final List<Map<String, dynamic>> _msgs = [];
  Timer? _timer;
  String? _error;
  bool _loading = true, _sending = false;

  int get _last => _msgs.isEmpty ? 0 : _msgs.last['id'] as int;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final items = await Api.list('/chats/${widget.interestId}/messages?after=$_last');
      if (!mounted) return;
      setState(() { _error = null; _loading = false; _msgs.addAll(items); });
      if (items.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) { if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut); });
    } on ApiError catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    await guarded(context, () async {
      await Api.call('POST', '/chats/${widget.interestId}/messages', body: {'text': text});
      _input.clear();
      await _poll();
      return null;
    });
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent, title: Text(widget.name, style: const TextStyle(fontWeight: FontWeight.w800, color: Palette.plum)),
            actions: [if (widget.memberId != null) IconButton(tooltip: 'Report or block', icon: const Icon(Icons.more_vert), onPressed: () => showSafety(context, widget.memberId!, widget.name))]),
        body: Column(children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _msgs.isEmpty
                    ? EmptyState(Icons.lock_outline, _error!)
                    : _msgs.isEmpty
                        ? const EmptyState(Icons.waving_hand_outlined, 'Say hello. Be kind and respectful.')
                        : ListView.builder(controller: _scroll, padding: const EdgeInsets.all(16), itemCount: _msgs.length, itemBuilder: (_, i) => _Bubble(_msgs[i])),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(children: [
                Expanded(child: TextField(controller: _input, minLines: 1, maxLines: 4, maxLength: 1000, textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'Type a message', counterText: ''))),
                const SizedBox(width: 10),
                Tooltip(message: 'Send', child: InkWell(
                  onTap: _send, borderRadius: BorderRadius.circular(28),
                  child: Container(width: 56, height: 56, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Palette.plum, Palette.plumDeep])),
                      child: _sending ? const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Icon(Icons.send_rounded, color: Colors.white)),
                )),
              ]),
            ),
          ),
        ]),
      );
}

class _Bubble extends StatelessWidget {
  final Map<String, dynamic> m;
  const _Bubble(this.m);
  @override
  Widget build(BuildContext context) {
    final mine = m['mine'] == true;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
        decoration: BoxDecoration(color: mine ? Palette.plum : Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Text('${m['body']}', style: TextStyle(color: mine ? Colors.white : Palette.ink, fontSize: 16)),
      ),
    );
  }
}
