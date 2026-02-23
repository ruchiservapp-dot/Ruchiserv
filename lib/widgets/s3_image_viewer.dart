// lib/widgets/s3_image_viewer.dart
// Reusable widget for displaying images from S3 or local paths.
// Handles: S3 keys, local file paths, pending uploads, and caching.

import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/file_storage_helper.dart';

/// Displays an image from an S3 key or local path.
/// Used across ledger detail screens, transaction lists, etc.
class S3ImageViewer extends StatefulWidget {
  final String? imageUrl;  // S3 key, local path, or pending path
  final double? height;
  final double? width;
  final BoxFit fit;

  const S3ImageViewer({
    super.key,
    required this.imageUrl,
    this.height,
    this.width,
    this.fit = BoxFit.contain,
  });

  @override
  State<S3ImageViewer> createState() => _S3ImageViewerState();
}

class _S3ImageViewerState extends State<S3ImageViewer> {
  String? _resolvedPath;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  @override
  void didUpdateWidget(S3ImageViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _resolveImage();
    }
  }

  Future<void> _resolveImage() async {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Try local path first (cache or legacy)
      final localPath = FileStorageHelper.getLocalPath(widget.imageUrl);
      if (localPath != null && File(localPath).existsSync()) {
        if (mounted) {
          setState(() {
            _resolvedPath = localPath;
            _isLoading = false;
          });
        }
        return;
      }

      // If S3 key, download and cache
      if (FileStorageHelper.isS3Key(widget.imageUrl)) {
        final viewablePath = await FileStorageHelper.getViewableUrl(widget.imageUrl);
        if (mounted) {
          setState(() {
            _resolvedPath = viewablePath;
            _isLoading = false;
            _hasError = viewablePath == null;
          });
        }
      } else {
        // Legacy path that doesn't exist
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        height: widget.height ?? 200,
        width: widget.width,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_hasError || _resolvedPath == null) {
      return SizedBox(
        height: widget.height ?? 200,
        width: widget.width,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text('Image not available', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    // Display from local file
    if (_resolvedPath!.startsWith('/')) {
      return Image.file(
        File(_resolvedPath!),
        height: widget.height,
        width: widget.width,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
        ),
      );
    }

    // Fallback: presigned URL (if cache download failed)
    return Image.network(
      _resolvedPath!,
      height: widget.height,
      width: widget.width,
      fit: widget.fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return SizedBox(
          height: widget.height ?? 200,
          width: widget.width,
          child: Center(
            child: CircularProgressIndicator(
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
      ),
    );
  }
}

/// Shows a fullscreen image dialog with an S3ImageViewer.
/// Use this for viewing invoice/bill images from transaction tiles.
void showS3ImageDialog(BuildContext context, String? imageUrl, {String title = 'Image'}) {
  if (imageUrl == null || imageUrl.isEmpty) return;

  final isPending = imageUrl.startsWith('pending:');

  showDialog(
    context: context,
    builder: (context) => Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            title: Text(title),
            leading: const CloseButton(),
            actions: [
              if (isPending)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Chip(
                    label: Text('Pending Upload', style: TextStyle(fontSize: 11)),
                    backgroundColor: Colors.orange,
                    labelStyle: TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: S3ImageViewer(imageUrl: imageUrl),
            ),
          ),
        ],
      ),
    ),
  );
}
