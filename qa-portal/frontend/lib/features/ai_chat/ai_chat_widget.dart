import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'ai_chat_controller.dart';

const _kPrimary = Color(0xFF6C63FF);
const _kBg = Color(0xFF1E1E2E);
const _kSurface = Color(0xFF2A2A3E);

class AiChatWidget extends StatelessWidget {
  const AiChatWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = AiChatController.to;

    return Obx(() {
      if (!ctrl.isOpen.value) {
        return Positioned(
          right: 20,
          bottom: 90,
          child: FloatingActionButton(
            backgroundColor: _kPrimary,
            onPressed: ctrl.toggle,
            tooltip: 'Asistente IA',
            child: const Icon(Icons.smart_toy_outlined, color: Colors.white),
          ),
        );
      }

      return Positioned(
        right: 20,
        bottom: 20,
        child: Material(
          elevation: 12,
          borderRadius: BorderRadius.circular(16),
          color: _kSurface,
          child: SizedBox(
            width: 380,
            height: 520,
            child: Column(
              children: [
                _ChatHeader(ctrl: ctrl),
                Expanded(child: _ChatMessages(ctrl: ctrl)),
                _ChatInput(ctrl: ctrl),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _ChatHeader extends StatelessWidget {
  final AiChatController ctrl;
  const _ChatHeader({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: _kPrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Asistente QA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _HeaderButton(
            icon: Icons.delete_outline,
            tooltip: 'Limpiar chat',
            onTap: ctrl.clearChat,
          ),
          const SizedBox(width: 4),
          _HeaderButton(
            icon: Icons.close,
            tooltip: 'Cerrar',
            onTap: ctrl.toggle,
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _HeaderButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Tooltip(
        message: tooltip,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, color: Colors.white70, size: 18),
        ),
      ),
    );
  }
}

// ── Messages list ────────────────────────────────────────────────────────────

class _ChatMessages extends StatelessWidget {
  final AiChatController ctrl;
  const _ChatMessages({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final msgs = ctrl.messages;

      if (msgs.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline, size: 48, color: Colors.white24),
                SizedBox(height: 12),
                Text(
                  '¿En qué puedo ayudarte?',
                  style: TextStyle(color: Colors.white54, fontSize: 15),
                ),
                SizedBox(height: 8),
                Text(
                  'Pregunta sobre test cases, ejecuciones,\nbugs, reportes o cualquier tema de QA.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white30, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: msgs.length + (ctrl.isLoading.value ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == msgs.length) return const _TypingIndicator();
          return _MessageBubble(message: msgs[i]);
        },
      );
    });
  }
}

class _MessageBubble extends StatelessWidget {
  final dynamic message; // ChatMessage
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isUser ? _kPrimary : _kBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUser ? 14 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              message.content,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.white.withValues(alpha: 0.9),
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    color: isUser ? Colors.white54 : Colors.white30,
                    fontSize: 10,
                  ),
                ),
                if (!isUser) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: message.content));
                      Get.snackbar('Copiado', 'Respuesta copiada al portapapeles',
                          backgroundColor: _kSurface,
                          colorText: Colors.white,
                          duration: const Duration(seconds: 1));
                    },
                    child: const Icon(Icons.copy, size: 12, color: Colors.white30),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2, color: _kPrimary,
              ),
            ),
            SizedBox(width: 10),
            Text('Pensando...', style: TextStyle(color: Colors.white38, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ── Input field ──────────────────────────────────────────────────────────────

class _ChatInput extends StatefulWidget {
  final AiChatController ctrl;
  const _ChatInput({required this.ctrl});

  @override
  State<_ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<_ChatInput> {
  final _textCtrl = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || widget.ctrl.isLoading.value) return;
    widget.ctrl.sendMessage(text);
    _textCtrl.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      decoration: const BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textCtrl,
              focusNode: _focusNode,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Escribe tu pregunta...',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: _kBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Obx(() => IconButton(
                onPressed: widget.ctrl.isLoading.value ? null : _send,
                icon: Icon(
                  Icons.send_rounded,
                  color: widget.ctrl.isLoading.value ? Colors.white24 : _kPrimary,
                ),
                tooltip: 'Enviar',
              )),
        ],
      ),
    );
  }
}
