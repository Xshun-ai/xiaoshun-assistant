import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/api_urls.dart';
import '../constants/app_colors.dart';
import '../models/portal_announcement.dart';
import '../services/campus_access_service.dart';
import '../services/log_service.dart';
import '../services/portal_announcement_service.dart';
import '../utils/loadable_state.dart';
import '../ui/components/app_meta_line.dart';
import '../ui/components/app_page_app_bar.dart';
import '../ui/components/status_chip.dart';
import '../ui/components/custom_toast.dart';
import '../ui/patterns/app_article_header.dart';
import '../ui/patterns/app_detail_section_card.dart';

/// 融合门户公告详细页面
class PortalAnnouncementDetailPage extends StatefulWidget {
  final PortalAnnouncement announcement;

  const PortalAnnouncementDetailPage({super.key, required this.announcement});

  @override
  State<PortalAnnouncementDetailPage> createState() =>
      _PortalAnnouncementDetailPageState();
}

class _PortalAnnouncementDetailPageState
    extends State<PortalAnnouncementDetailPage>
    with LoadableStateMixin {
  static const String _campusUnavailableMessage = '校园网服务暂不可用，请稍后重试';
  final _service = PortalAnnouncementService();
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _logView();
  }

  Future<void> _loadDetail() async {
    await loadData<Map<String, dynamic>>(
      key: 'detailData',
      loader: () async {
        await _service.init();
        final detail = await _service.fetchAnnouncementDetail(
          widget.announcement.id,
        );

        if (detail == null) {
          throw Exception('无法加载公告内容');
        }

        return detail;
      },
    );
  }

  Future<void> _handleAttachmentClick(String attUrl, String fileName) async {
    try {
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
      });

      await LogService().log('融合门户公告', '点击附件: $fileName');

      final downloadUrl = attUrl.startsWith('http')
          ? attUrl
          : '${ApiUrls.eipBaseUrl}/EIP/$attUrl';

      final tempDir = await getTemporaryDirectory();
      final attachmentDirectory = Directory(
        '${tempDir.path}/announcement_attachments',
      );
      await attachmentDirectory.create(recursive: true);
      final filePath = '${attachmentDirectory.path}/$fileName';

      final dio = Dio();
      await dio.download(
        downloadUrl,
        filePath,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      setState(() {
        _isDownloading = false;
      });

      if (!mounted) {
        return;
      }

      final action = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  fileName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.open_in_new_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: const Text('选择应用打开'),
                  subtitle: const Text('系统将弹出应用选择器'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, 'choose'),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.visibility_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  title: const Text('默认应用打开'),
                  subtitle: const Text('使用系统默认应用预览'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, 'default'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );

      if (action == null) {
        return;
      }

      if (action == 'choose') {
        final result = await OpenFile.open(
          filePath,
          type: _getMimeType(fileName),
        );
        if (result.type != ResultType.done) {
          throw '打开文件失败: ${result.message}';
        }
      } else if (action == 'default') {
        final result = await OpenFile.open(filePath);
        if (result.type != ResultType.done) {
          throw '打开文件失败: ${result.message}';
        }
      }

      await LogService().log('融合门户公告', '附件预览成功: $fileName');
    } catch (e) {
      setState(() {
        _isDownloading = false;
      });

      if (mounted) {
        CustomToast.error(context, message: '附件预览失败，请稍后重试');
      }

      await LogService().log('融合门户公告', '附件预览失败: $e');
    }
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  String? _getMimeType(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/x-rar-compressed';
      case 'txt':
        return 'text/plain';
      default:
        return null;
    }
  }

  Future<void> _logView() async {
    await LogService().log(
      '融合门户公告',
      '查看公告: ${widget.announcement.title}',
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          appBar: const AppPageAppBar(title: '公告详情'),
          body: _buildBody(),
        ),
        if (_isDownloading)
          Positioned.fill(child: _buildDownloadOverlay(context)),
      ],
    );
  }

  Widget _buildDownloadOverlay(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 280,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          value: _downloadProgress,
                          strokeWidth: 4,
                          backgroundColor: AppColors.borderLight,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            primaryColor,
                          ),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Icon(
                        Icons.download_rounded,
                        size: 30,
                        color: primaryColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '正在下载',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '附件下载中，请稍候...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: _downloadProgress,
                    minHeight: 6,
                    backgroundColor: AppColors.borderLight,
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return buildLoadable<Map<String, dynamic>>(
      key: 'detailData',
      errorBuilder: (error) {
        final message = _resolveErrorMessage(error);
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 72,
                  color: Colors.orange[300],
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '下拉或点击重试后会重新请求最新数据',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: _loadDetail,
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        );
      },
      builder: (detailData) {
        final content = (detailData['content'] ?? '无内容').toString();
        final List<dynamic> attachments = detailData['attachments'] ?? [];

        return RefreshIndicator(
          onRefresh: _loadDetail,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              _buildArticleHeader(),
              if (content.trim().isNotEmpty && content != '无内容') ...[
                const SizedBox(height: 20),
                _buildContentSection(content),
              ],
              if (attachments.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildAttachmentSection(attachments),
              ],
            ],
          ),
        );
      },
    );
  }

  String _resolveErrorMessage(String error) {
    if (CampusAccessService.isCampusNetworkUnavailableError(error) ||
        error.contains('CampusServiceUnavailableException') ||
        error.contains('融合门户公告暂不可用')) {
      return _campusUnavailableMessage;
    }
    return '加载失败，请稍后重试';
  }

  Widget _buildArticleHeader() {
    return AppArticleHeader(
      badge: StatusChip(
        label: widget.announcement.category,
        backgroundColor: AppColors.primarySoft,
        foregroundColor: AppColors.primary,
        borderColor: AppColors.primarySoftBorder,
      ),
      title: widget.announcement.title,
      meta: [
        _buildMetaItem(Icons.business_outlined, widget.announcement.department),
        _buildMetaItem(
          Icons.access_time_rounded,
          widget.announcement.publishDate,
        ),
        _buildMetaItem(
          Icons.visibility_outlined,
          '${widget.announcement.viewCount} 次浏览',
        ),
      ],
      metaRunSpacing: 10,
      footer: const Divider(height: 1, color: AppColors.articleDivider),
    );
  }

  Widget _buildMetaItem(IconData icon, String value) {
    return AppMetaLine(
      icon: icon,
      text: value,
      iconSize: 15,
      iconColor: AppColors.textSecondary,
      spacing: 6,
      textStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      expanded: false,
    );
  }

  Widget _buildContentSection(String content) {
    return AppDetailSectionCard(
      title: '正文',
      child: Text(
        content,
        style: const TextStyle(
          fontSize: 15,
          height: 1.85,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildAttachmentSection(List<dynamic> attachments) {
    return AppDetailSectionCard(
      title: '附件',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: attachments.asMap().entries.map((entry) {
          final index = entry.key;
          final attachment = entry.value;
          final attUrl = attachment['atturl'] ?? '';
          final attName = attachment['attname'] ?? '未命名附件';
          final attType = attachment['atttype'] ?? '';
          final attSize = attachment['attsize'] ?? 0;
          final fileName = attType.isNotEmpty ? '$attName.$attType' : attName;

          return Padding(
            padding: EdgeInsets.only(
              bottom: index == attachments.length - 1 ? 0 : 10,
            ),
            child: _buildAttachmentTile(
              attUrl: attUrl,
              attName: attName,
              attType: attType,
              attSize: attSize,
              fileName: fileName,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAttachmentTile({
    required String attUrl,
    required String attName,
    required String attType,
    required int attSize,
    required String fileName,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleAttachmentClick(attUrl, fileName),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _getFileIcon(fileName),
                  size: 24,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (attType.isNotEmpty)
                          StatusChip(
                            label: attType.toUpperCase(),
                            backgroundColor: AppColors.primarySoft,
                            foregroundColor: AppColors.primary,
                            fontSize: 10,
                          ),
                        Text(
                          _formatFileSize(attSize),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
