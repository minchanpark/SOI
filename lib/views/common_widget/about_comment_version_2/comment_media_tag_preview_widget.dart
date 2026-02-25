import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../api/controller/media_controller.dart';
import '../../../api/models/comment.dart';

class CommentMediaTagPreviewWidget extends StatefulWidget {
  final Comment comment;
  final double size;
  final bool autoplayVideo;
  final bool playWithSound;

  const CommentMediaTagPreviewWidget({
    super.key,
    required this.comment,
    required this.size,
    this.autoplayVideo = true,
    this.playWithSound = true,
  });

  @override
  State<CommentMediaTagPreviewWidget> createState() =>
      _CommentMediaTagPreviewWidgetState();
}

enum _PreviewPhase { loading, ready, failed }

class _CommentMediaTagPreviewWidgetState
    extends State<CommentMediaTagPreviewWidget> {
  String? _resolvedSource;
  bool _isVideo = false;
  _PreviewPhase _phase = _PreviewPhase.loading;

  VideoPlayerController? _videoController;
  Future<void>? _videoInitialization;

  @override
  void initState() {
    super.initState();
    _prepareSource();
  }

  @override
  void didUpdateWidget(covariant CommentMediaTagPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sourceChanged =
        oldWidget.comment.fileKey != widget.comment.fileKey ||
        oldWidget.comment.fileUrl != widget.comment.fileUrl;
    if (sourceChanged) {
      _prepareSource();
      return;
    }

    if (oldWidget.playWithSound != widget.playWithSound) {
      final volume = widget.playWithSound ? 1.0 : 0.0;
      _videoController?.setVolume(volume);
    }
  }

  @override
  void dispose() {
    _disposeVideoController();
    super.dispose();
  }

  Future<void> _prepareSource() async {
    _disposeVideoController();
    if (!mounted) return;

    setState(() {
      _phase = _PreviewPhase.loading;
      _resolvedSource = null;
      _isVideo = false;
    });

    try {
      final source = await _resolveMediaSource(widget.comment);
      if (!mounted) return;

      if (source == null || source.isEmpty) {
        setState(() {
          _phase = _PreviewPhase.failed;
        });
        return;
      }

      final isVideo = _isVideoMediaSource(source);
      if (!isVideo) {
        setState(() {
          _resolvedSource = source;
          _isVideo = false;
          _phase = _PreviewPhase.ready;
        });
        return;
      }

      setState(() {
        _resolvedSource = source;
        _isVideo = true;
        _phase = _PreviewPhase.loading;
      });
      await _initializeVideoController(source);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _PreviewPhase.failed;
      });
    }
  }

  Future<String?> _resolveMediaSource(Comment comment) async {
    final fileUrl = (comment.fileUrl ?? '').trim();
    if (fileUrl.isNotEmpty) {
      return fileUrl;
    }

    final fileKey = (comment.fileKey ?? '').trim();
    if (fileKey.isEmpty) {
      return null;
    }

    final keyUri = Uri.tryParse(fileKey);
    if (keyUri != null && keyUri.hasScheme) {
      return fileKey;
    }

    try {
      final mediaController = context.read<MediaController>();
      return await mediaController.getPresignedUrl(fileKey) ?? fileKey;
    } catch (_) {
      return fileKey;
    }
  }

  bool _isVideoMediaSource(String source) {
    final normalized = source.split('?').first.split('#').first.toLowerCase();
    const videoExtensions = <String>[
      '.mp4',
      '.mov',
      '.m4v',
      '.avi',
      '.mkv',
      '.webm',
    ];
    return videoExtensions.any(normalized.endsWith);
  }

  bool _isLocalFile(String source) {
    final uri = Uri.tryParse(source);
    if (uri == null) {
      return false;
    }
    if (uri.hasScheme) {
      return uri.scheme == 'file';
    }
    return true;
  }

  Future<void> _initializeVideoController(String source) async {
    _disposeVideoController();

    VideoPlayerController? controller;
    try {
      if (_isLocalFile(source)) {
        final file = File(source);
        if (!await file.exists()) {
          if (!mounted) return;
          setState(() {
            _phase = _PreviewPhase.failed;
          });
          return;
        }
        controller = VideoPlayerController.file(file);
      } else {
        controller = VideoPlayerController.networkUrl(Uri.parse(source));
      }

      _videoController = controller;
      _videoInitialization = controller.initialize();
      await _videoInitialization;

      if (!mounted || _videoController != controller) {
        return;
      }

      await controller.setLooping(true);
      await controller.setVolume(widget.playWithSound ? 1.0 : 0.0);
      if (widget.autoplayVideo) {
        await controller.play();
      }

      if (!mounted || _videoController != controller) {
        return;
      }

      setState(() {
        _phase = _PreviewPhase.ready;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _PreviewPhase.failed;
      });
    }
  }

  void _disposeVideoController() {
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
    _videoInitialization = null;
  }

  Widget _buildPlaceholder({IconData icon = Icons.image_not_supported}) {
    return Container(
      color: const Color(0xFF4A4A4A),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white70, size: widget.size * 0.28),
    );
  }

  Widget _buildProfileFallback() {
    final profileUrl = (widget.comment.userProfileUrl ?? '').trim();
    if (profileUrl.isEmpty) {
      return Container(
        color: const Color(0xffd9d9d9),
        alignment: Alignment.center,
        child: Icon(
          Icons.person,
          color: Colors.white,
          size: widget.size * 0.28,
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: profileUrl,
      fit: BoxFit.cover,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      memCacheWidth: (widget.size * MediaQuery.of(context).devicePixelRatio)
          .round(),
      placeholder: (_, __) => Container(
        color: const Color(0xffd9d9d9),
        alignment: Alignment.center,
        child: Icon(
          Icons.person,
          color: Colors.white,
          size: widget.size * 0.28,
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        color: const Color(0xffd9d9d9),
        alignment: Alignment.center,
        child: Icon(
          Icons.person,
          color: Colors.white,
          size: widget.size * 0.28,
        ),
      ),
    );
  }

  Widget _buildImagePreview(String source) {
    final isLocal = _isLocalFile(source);
    if (isLocal) {
      final file = File(source);
      if (!file.existsSync()) {
        return _buildPlaceholder();
      }
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }

    final cacheKey = (widget.comment.fileKey ?? '').trim();
    return CachedNetworkImage(
      imageUrl: source,
      cacheKey: cacheKey.isEmpty ? null : cacheKey,
      useOldImageOnUrlChange: true,
      fit: BoxFit.cover,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (_, __) => _buildProfileFallback(),
      errorWidget: (_, __, ___) => _buildPlaceholder(),
    );
  }

  Widget _buildVideoPreview() {
    final controller = _videoController;
    final initialization = _videoInitialization;

    if (controller == null || initialization == null) {
      return _buildProfileFallback();
    }

    return FutureBuilder<void>(
      future: initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            !controller.value.isInitialized) {
          return _buildProfileFallback();
        }

        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        );
      },
    );
  }

  Widget _buildPreviewContent() {
    switch (_phase) {
      case _PreviewPhase.loading:
        return _buildProfileFallback();
      case _PreviewPhase.failed:
        return _isVideo
            ? _buildPlaceholder(icon: Icons.videocam_off)
            : _buildPlaceholder();
      case _PreviewPhase.ready:
        final source = _resolvedSource;
        if (source == null || source.isEmpty) {
          return _buildPlaceholder();
        }
        if (_isVideo) {
          return _buildVideoPreview();
        }
        return _buildImagePreview(source);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildPreviewContent();

    return ClipOval(
      child: SizedBox(width: widget.size, height: widget.size, child: content),
    );
  }
}
