import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../api_firebase/controllers/auth_controller.dart';
import '../../../api_firebase/controllers/audio_controller.dart';
import '../../../api_firebase/models/photo_data_model.dart';
import '../screens/archive_detail/photo_detail_screen.dart';
import 'wave_form_widget/custom_waveform_widget.dart';

class PhotoGridItem extends StatefulWidget {
  final MediaDataModel photo;
  final List<MediaDataModel> allPhotos;
  final int currentIndex;
  final String categoryName;
  final String categoryId;

  const PhotoGridItem({
    super.key,
    required this.photo,
    required this.allPhotos,
    required this.currentIndex,
    required this.categoryName,
    required this.categoryId,
  });

  @override
  _PhotoGridItemState createState() => _PhotoGridItemState();
}

class _PhotoGridItemState extends State<PhotoGridItem> {
  // AuthController 참조 저장용
  AuthController? _authController;

  // 오디오 관련 상태
  bool _hasAudio = false;
  List<double>? _waveformData;

  @override
  void initState() {
    super.initState();

    // 파형 데이터 초기화
    _initializeWaveformData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // AuthController 참조 저장
    _authController ??= Provider.of<AuthController>(context, listen: false);
  }

  void _initializeWaveformData() {
    // 실제 오디오 URL 확인
    final audioUrl = widget.photo.audioUrl;

    // 오디오 URL 유효성 검사
    if (audioUrl.isEmpty) {
      setState(() {
        _hasAudio = false;
      });
      return;
    }

    // Firestore에서 파형 데이터 가져오기
    final waveformData = widget.photo.waveformData;

    if (waveformData != null && waveformData.isNotEmpty) {
      setState(() {
        _hasAudio = true;
        _waveformData = waveformData;
      });
    } else {
      setState(() {
        _hasAudio = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PhotoDetailScreen(
              photos: widget.allPhotos,
              initialIndex: widget.currentIndex,
              categoryName: widget.categoryName,
              categoryId: widget.categoryId,
            ),
          ),
        );
      },
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          SizedBox(
            width: 175,
            height: 232,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: widget.photo.imageUrl,
                memCacheWidth: (175 * 2).round(),
                maxWidthDiskCache: (175 * 2).round(),
                fit: BoxFit.cover,
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: Colors.grey.shade800,
                  highlightColor: Colors.grey.shade700,
                  period: const Duration(milliseconds: 1500),
                  child: Container(color: Colors.grey.shade800),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey.shade800,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.image,
                    color: Colors.grey.shade600,
                    size: 32.sp,
                  ),
                ),
              ),
            ),
          ),

          // 하단 왼쪽에 프로필 이미지 표시
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                children: [
                  SizedBox(width: 8.w),
                  Container(
                    width: 28.w,
                    height: 28.h,
                    decoration: BoxDecoration(shape: BoxShape.circle),
                    child: StreamBuilder<String>(
                      stream: _authController?.getUserProfileImageUrlStream(
                        widget.photo.userID,
                      ),
                      builder: (context, snapshot) {
                        // 로딩 중이거나 데이터가 없을 때
                        if (!snapshot.hasData) {
                          return Shimmer.fromColors(
                            baseColor: Colors.grey.shade800,
                            highlightColor: Colors.grey.shade700,
                            period: const Duration(milliseconds: 1500),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade800,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  width: 1,
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        }

                        final imageUrl = snapshot.data!;

                        // URL이 비어있으면 기본 아이콘
                        if (imageUrl.isEmpty) {
                          return CircleAvatar(
                            radius: 14,
                            backgroundColor: Color(0xffd9d9d9),
                            child: Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 18.sp,
                            ),
                          );
                        }

                        // 프로필 이미지 표시
                        return CachedNetworkImage(
                          key: ValueKey(
                            'profile_${widget.photo.userID}_${imageUrl.hashCode}',
                          ),
                          imageUrl: imageUrl,
                          memCacheWidth: (28 * 5).round(),
                          maxWidthDiskCache: (28 * 5).round(),
                          imageBuilder: (context, imageProvider) =>
                              CircleAvatar(
                                radius: 14,
                                backgroundImage: imageProvider,
                              ),
                          placeholder: (context, url) => Shimmer.fromColors(
                            baseColor: Colors.grey.shade800,
                            highlightColor: Colors.grey.shade700,
                            period: const Duration(milliseconds: 1500),
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.grey.shade800,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 60,
                            height: 60,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFd9d9d9),
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(width: 7.w), // 반응형 간격
                  Expanded(
                    child:
                        (!_hasAudio ||
                            _waveformData == null ||
                            _waveformData!.isEmpty)
                        ? Container()
                        : GestureDetector(
                            onTap: () => _toggleAudioPlayback(),
                            child: Container(
                              width: 140.w,
                              height: 21.h,
                              decoration: BoxDecoration(
                                color: Color(0xff171717).withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: _buildWaveformWidget(),
                            ),
                          ),
                  ),
                  SizedBox(width: 5.w),
                ],
              ),
              SizedBox(height: 5.h),
            ],
          ),
        ],
      ),
    );
  }

  /// 오디오 재생/일시정지 토글 메서드
  void _toggleAudioPlayback() async {
    if (!_hasAudio || widget.photo.audioUrl.isEmpty) return;

    final audioController = Provider.of<AudioController>(
      context,
      listen: false,
    );

    audioController.toggleAudio(widget.photo.audioUrl);
  }

  /// 커스텀 파형 위젯을 빌드하는 메서드
  Widget _buildWaveformWidget() {
    return Consumer<AudioController>(
      builder: (context, audioController, child) {
        final isCurrentAudio =
            audioController.isPlaying &&
            audioController.currentPlayingAudioUrl == widget.photo.audioUrl;

        double progress = 0.0;
        if (isCurrentAudio &&
            audioController.currentDuration.inMilliseconds > 0) {
          progress =
              (audioController.currentPosition.inMilliseconds /
                      audioController.currentDuration.inMilliseconds)
                  .clamp(0.0, 1.0);
        }

        return Container(
          height: 21,
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          child: CustomWaveformWidget(
            waveformData: _waveformData!,
            color: (isCurrentAudio) ? Color(0xff5a5a5a) : Color(0xffffffff),
            activeColor: Colors.white,
            progress: progress,
          ),
        );
      },
    );
  }
}
