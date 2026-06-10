import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import '../../core/models/chat_message.dart';

class RescuerGroupChatScreen extends StatefulWidget {
  final String groupChatId;

  const RescuerGroupChatScreen({super.key, required this.groupChatId});

  @override
  State<RescuerGroupChatScreen> createState() => _RescuerGroupChatScreenState();
}

class _RescuerGroupChatScreenState extends State<RescuerGroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser;
  final ImagePicker _picker = ImagePicker();
  String? _cachedSenderName;

  Future<String> _senderDisplayName() async {
    if (_cachedSenderName != null && _cachedSenderName!.isNotEmpty) {
      return _cachedSenderName!;
    }

    if (currentUser == null) return 'Rescuer';

    final profileSnap = await FirebaseFirestore.instance
        .collection('Users')
        .doc(currentUser!.uid)
        .get();

    final profile = profileSnap.data();
    if (profile != null) {
      final role = (profile['roles'] ?? '').toString().toLowerCase();
      if (role == 'rescuer') {
        final first = (profile['firstName'] ?? '').toString().trim();
        final last = (profile['lastName'] ?? '').toString().trim();
        final fullName = [first, last].where((part) => part.isNotEmpty).join(' ').trim();

        if (fullName.isNotEmpty) {
          _cachedSenderName = fullName;
          return fullName;
        }
      }
    }

    final displayName = currentUser?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      _cachedSenderName = displayName;
      return displayName;
    }

    final emailPrefix = currentUser?.email?.split('@').first;
    if (emailPrefix != null && emailPrefix.isNotEmpty) {
      _cachedSenderName = emailPrefix;
      return emailPrefix;
    }

    _cachedSenderName = 'Rescuer';
    return 'Rescuer';
  }

  CollectionReference<Map<String, dynamic>> get messagesRef => FirebaseFirestore
      .instance
      .collection('group_chats')
      .doc(widget.groupChatId)
      .collection('messages');

  Future<void> _ensureParentDocumentExists() async {
    final parentRef = FirebaseFirestore.instance.collection('group_chats').doc(widget.groupChatId);
    final snap = await parentRef.get();
    if (!snap.exists) {
      await parentRef.set({
        'createdAt': Timestamp.now(),
        'createdBy': currentUser?.uid,
        'status': 'active',
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || currentUser == null) return;

    await _ensureParentDocumentExists();
    final senderName = await _senderDisplayName();

    final message = ChatMessage(
      senderId: currentUser!.uid,
      senderName: senderName,
      message: text,
      type: 'text',
      sentAt: Timestamp.now(),
    );

    await messagesRef.add(message.toMap());
    _messageController.clear();
  }

  Future<void> _pickImageAndSend(ImageSource source) async {
    final picked = await _picker.pickImage(source: source);
    if (picked == null || currentUser == null) return;

    await _ensureParentDocumentExists();
    final senderName = await _senderDisplayName();

    final file = File(picked.path);
    final id = const Uuid().v4();

    final ref = FirebaseStorage.instance.ref('group_chats/${widget.groupChatId}/images/$id.jpg');

    await ref.putFile(file);
    final url = await ref.getDownloadURL();

    final message = ChatMessage(
      senderId: currentUser!.uid,
      senderName: senderName,
      message: '',
      type: 'image',
      mediaUrl: url,
      sentAt: Timestamp.now(),
    );

    await messagesRef.add(message.toMap());
  }

  Future<void> _pickVideoAndSend(ImageSource source) async {
    final picked = await _picker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 5),
    );

    if (picked == null || currentUser == null) return;

    await _ensureParentDocumentExists();
    final senderName = await _senderDisplayName();

    final file = File(picked.path);
    final id = const Uuid().v4();

    final ref = FirebaseStorage.instance.ref('group_chats/${widget.groupChatId}/videos/$id.mp4');

    await ref.putFile(file);
    final url = await ref.getDownloadURL();

    final message = ChatMessage(
      senderId: currentUser!.uid,
      senderName: senderName,
      message: '',
      type: 'video',
      mediaUrl: url,
      sentAt: Timestamp.now(),
    );

    await messagesRef.add(message.toMap());
  }

  String _formatTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rescuer Group Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Incident info',
            onPressed: _showIncidentInfo,
          ),
        ],
        backgroundColor: Colors.green.shade700,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: messagesRef.orderBy('sentAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs.map((e) => ChatMessage.fromSnapshot(e)).toList();

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMine = msg.senderId == currentUser?.uid;
                    final senderLabel = msg.senderName.trim().isNotEmpty ? msg.senderName : 'Rescuer';

                    return Align(
                      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.all(6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMine ? Colors.green.shade700 : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMine)
                              Text(
                                senderLabel,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            if (msg.type == 'text')
                              Text(
                                msg.message,
                                style: TextStyle(
                                  color: isMine ? Colors.white : Colors.black,
                                ),
                              ),
                            if (msg.type == 'image' && msg.mediaUrl != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  msg.mediaUrl!,
                                  width: 220,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            if (msg.type == 'video' && msg.mediaUrl != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 240,
                                    maxHeight: 180,
                                  ),
                                  child: _VideoBubble(url: msg.mediaUrl!),
                                ),
                              ),
                            if (msg.type == 'audio')
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Audio message (playback disabled)',
                                  style: TextStyle(
                                    color: isMine ? Colors.white : Colors.black54,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            Text(
                              _formatTime(msg.sentAt),
                              style: const TextStyle(fontSize: 10),
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
          SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image),
                  onPressed: _showImageOptions,
                ),
                IconButton(
                  icon: const Icon(Icons.videocam),
                  onPressed: _showVideoOptions,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(hintText: 'Message'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showIncidentInfo() async {
    final reportDoc = await FirebaseFirestore.instance
        .collection('sos_reports')
        .doc(widget.groupChatId)
        .get();

    if (!reportDoc.exists) {
      await _showSimpleDialog('No incident info available.');
      return;
    }

    final data = reportDoc.data() ?? {};
    final type = (data['disasterType'] ?? data['type'] ?? 'Incident').toString();
    final details = (data['details'] ?? '').toString();
    final location = (data['location'] ?? '').toString();
    final status = (data['status'] ?? 'unknown').toString();
    final imagePath = (data['imagePath'] ?? '').toString();

    String when = '';
    final ts = data['createdAt'];
    if (ts is Timestamp) {
      final date = ts.toDate();
      when = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${_formatTime(ts)}';
    } else {
      final timeStr = (data['time'] ?? '').toString();
      if (timeStr.isNotEmpty) when = timeStr;
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(type),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (details.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(details),
                  ),
                if (location.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('Location: $location'),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('Status: $status'),
                ),
                if (when.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('When: $when'),
                  ),
                if (imagePath.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(imagePath, width: 260, fit: BoxFit.cover),
                  ),
              ],
            ),
          ),
          actions: [
            if (location.isNotEmpty)
              TextButton(
                onPressed: () => _openMaps(location),
                child: const Text('Get direction'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSimpleDialog(String message) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openMaps(String location) async {
    final trimmed = location.replaceAll('"', '').trim();
    if (trimmed.isEmpty) {
      await _showSimpleDialog('No location available.');
      return;
    }

    String query = trimmed;
    final parts = trimmed.split(',');
    if (parts.length == 2) {
      final lat = double.tryParse(parts[0].trim());
      final lng = double.tryParse(parts[1].trim());
      if (lat != null && lng != null) {
        query = '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
      }
    }

    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      final fallback = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!fallback) {
        await _showSimpleDialog('Could not open Maps.');
      }
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImageAndSend(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImageAndSend(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Record video'),
              onTap: () {
                Navigator.pop(context);
                _pickVideoAndSend(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickVideoAndSend(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoBubble extends StatefulWidget {
  final String url;

  const _VideoBubble({required this.url});

  @override
  State<_VideoBubble> createState() => _VideoBubbleState();
}

class _VideoBubbleState extends State<_VideoBubble> {
  late final VideoPlayerController _controller;
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _initFuture = _controller.initialize().then((_) {
      _controller.setLooping(true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Container(
            width: 220,
            height: 124,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final aspect = _controller.value.aspectRatio == 0 ? 16 / 9 : _controller.value.aspectRatio;

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: aspect,
                child: VideoPlayer(_controller),
              ),
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(40),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                    color: Colors.white,
                    size: 42,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
