# Firebase 버전 댓글 태그 시스템 플로우 분석

## 📋 목차
1. [개요](#개요)
2. [시스템 아키텍처](#시스템-아키텍처)
3. [핵심 데이터 구조](#핵심-데이터-구조)
4. [상세 플로우](#상세-플로우)
5. [API 버전 적용 가이드](#api-버전-적용-가이드)

---

## 개요

### 시스템 목적
사용자가 사진에 음성 또는 텍스트 댓글을 달고, 댓글 작성자의 프로필 이미지를 사진 위의 원하는 위치에 태그로 배치하는 시스템입니다.

### 주요 특징
- ✅ **음성 댓글** + **텍스트 댓글** 모두 지원
- ✅ **다중 댓글**: 한 사진에 여러 댓글 가능
- ✅ **드래그 앤 드롭**: 프로필 이미지를 원하는 위치에 배치
- ✅ **실시간 동기화**: Firestore 스트림으로 다중 사용자 댓글 실시간 반영
- ✅ **상대 좌표 시스템**: 다양한 화면 크기 대응 (0.0 ~ 1.0 범위)

---

## 시스템 아키텍처

### 계층 구조
```
┌─────────────────────────────────────────────────────────────┐
│                     Presentation Layer                       │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  PhotoCardWidgetCommon (사진 카드 컨테이너)          │   │
│  │    ├─ PhotoDisplayWidget (사진 + 댓글 아바타 표시)   │   │
│  │    └─ VoiceRecordingWidget (녹음/입력 영역)         │   │
│  │         ├─ VoiceCommentTextWidget (텍스트 입력)      │   │
│  │         └─ VoiceCommentActiveWidget                 │   │
│  │              └─ VoiceCommentWidget (상태 머신)       │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            ↕
┌─────────────────────────────────────────────────────────────┐
│                    State Management Layer                    │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  VoiceCommentStateManager                           │   │
│  │    - 상태 관리 (_voiceCommentActiveStates 등)       │   │
│  │    - Pending 데이터 관리 (_pendingVoiceComments)    │   │
│  │    - 실시간 스트림 관리 (_commentStreams)           │   │
│  │    - 최종 저장 로직 (saveVoiceComment)              │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            ↕
┌─────────────────────────────────────────────────────────────┐
│                       Data Layer                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  CommentRecordController                            │   │
│  │    - Firebase Storage (음성 파일 업로드)             │   │
│  │    - Firestore (댓글 메타데이터 저장)                │   │
│  │    - 실시간 스트림 (getCommentRecordsStream)         │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### 파일별 역할

| 파일 | 역할 | 위치 |
|------|------|------|
| `photo_card_widget_common.dart` | 사진 카드 전체 레이아웃 관리 | [lib/views/common_widget/abput_photo/photo_card_widget_common.dart:12](lib/views/common_widget/abput_photo/photo_card_widget_common.dart#L12) |
| `photo_display_widget.dart` | 사진 표시 + 댓글 아바타 배치 | [lib/views/common_widget/abput_photo/photo_display_widget.dart:24](lib/views/common_widget/abput_photo/photo_display_widget.dart#L24) |
| `voice_comment_widget.dart` | 댓글 녹음/배치 상태 머신 | [lib/views/common_widget/about_voice_comment/voice_comment_widget.dart:22](lib/views/common_widget/about_voice_comment/voice_comment_widget.dart#L22) |
| `voice_comment_text_widget.dart` | 텍스트 댓글 입력 UI | [lib/views/common_widget/about_voice_comment/voice_comment_text_widget.dart:7](lib/views/common_widget/about_voice_comment/voice_comment_text_widget.dart#L7) |
| `voice_comment_active_widget.dart` | 음성 댓글 활성화 래퍼 | [lib/views/common_widget/about_voice_comment/voice_comment_active_widget.dart:11](lib/views/common_widget/about_voice_comment/voice_comment_active_widget.dart#L11) |
| `voice_comment_state_manager.dart` | 전역 상태 관리 + 저장 로직 | [lib/views/about_feed/manager/voice_comment_state_manager.dart:46](lib/views/about_feed/manager/voice_comment_state_manager.dart#L46) |

---

## 핵심 데이터 구조

### 1. PendingVoiceComment (임시 데이터 객체)
```dart
class PendingVoiceComment {
  final String? audioPath;          // 녹음 파일 경로 (음성 댓글용)
  final List<double>? waveformData; // 파형 데이터 (음성 댓글용)
  final int? duration;              // 녹음 길이 ms (음성 댓글용)
  final String? text;               // 텍스트 내용 (텍스트 댓글용)
  final bool isTextComment;         // 텍스트 댓글 여부
  final Offset? relativePosition;   // 상대 위치 (0.0 ~ 1.0)
  final String? recorderUserId;     // 작성자 ID
  final String? profileImageUrl;    // 프로필 이미지 URL
}
```
**역할**: 사용자가 프로필 위치를 지정하기 전까지 임시로 댓글 데이터를 보관합니다.
**위치**: [lib/views/about_feed/manager/voice_comment_state_manager.dart:11](lib/views/about_feed/manager/voice_comment_state_manager.dart#L11)

### 2. VoiceCommentState (위젯 상태)
```dart
enum VoiceCommentState {
  idle,       // 초기 상태 (녹음 버튼 표시)
  recording,  // 녹음 중
  recorded,   // 녹음 완료 (재생 가능)
  placing,    // 프로필 배치 중 (드래그 가능)
  saved,      // 저장 완료 (프로필 이미지 표시)
}
```
**역할**: `VoiceCommentWidget`의 UI 상태를 관리합니다.
**위치**: [lib/views/common_widget/about_voice_comment/voice_comment_widget.dart:14](lib/views/common_widget/about_voice_comment/voice_comment_widget.dart#L14)

### 3. VoiceCommentStateManager 핵심 맵
```dart
// 음성 댓글 활성화 여부 (photoId → isActive)
Map<String, bool> _voiceCommentActiveStates;

// 음성 댓글 저장 완료 여부 (photoId → isSaved)
Map<String, bool> _voiceCommentSavedStates;

// 저장된 댓글 ID 목록 (photoId → List<commentId>)
Map<String, List<String>> _savedCommentIds;

// 임시 댓글 데이터 (photoId → PendingVoiceComment)
Map<String, PendingVoiceComment> _pendingVoiceComments;

// 실시간 댓글 데이터 (photoId → List<CommentRecordModel>)
Map<String, List<CommentRecordModel>> _photoComments;

// Firestore 스트림 구독 (photoId → StreamSubscription)
Map<String, StreamSubscription<List<CommentRecordModel>>> _commentStreams;
```
**위치**: [lib/views/about_feed/manager/voice_comment_state_manager.dart:48-60](lib/views/about_feed/manager/voice_comment_state_manager.dart#L48-L60)

---

## 상세 플로우

## 📝 플로우 A: 텍스트 댓글 생성

### A1. 사용자 텍스트 입력
**파일**: [voice_comment_text_widget.dart:49](lib/views/common_widget/about_voice_comment/voice_comment_text_widget.dart#L49)

```dart
Future<void> _sendTextComment() async {
  final text = _textController.text.trim();
  if (text.isEmpty || _isSending) return;

  // 텍스트를 임시로 저장하고 콜백 호출
  _textController.clear();
  FocusScope.of(context).unfocus();

  // 콜백을 통해 pending 상태로 전환
  widget.onTextCommentCreated?.call(text);
}
```

**동작**:
1. 사용자가 TextField에 댓글 입력 후 전송 버튼 클릭
2. 텍스트 검증 (empty 체크)
3. `onTextCommentCreated(text)` 콜백 호출

---

### A2. PhotoCardWidgetCommon에서 처리
**파일**: [photo_card_widget_common.dart:81](lib/views/common_widget/abput_photo/photo_card_widget_common.dart#L81)

```dart
void _handleTextCommentCreated(String text) async {
  debugPrint('[PhotoCard] 텍스트 댓글 생성: photoId=${widget.photo.id}, text=$text');

  // 텍스트 댓글을 임시 저장하고 음성 댓글 active 상태로 전환
  await widget.onTextCommentCompleted(widget.photo.id, text);

  // 음성 댓글 active 상태로 전환하여 프로필 드래그 가능하게 함
  widget.onToggleVoiceComment(widget.photo.id);
}
```

**동작**:
1. `onTextCommentCompleted(photoId, text)` 호출 → StateManager로 전달
2. `onToggleVoiceComment(photoId)` 호출 → placing 모드 활성화

---

### A3. StateManager에서 Pending 저장
**파일**: [voice_comment_state_manager.dart:134](lib/views/about_feed/manager/voice_comment_state_manager.dart#L134)

```dart
Future<void> onTextCommentCompleted(
  String photoId,
  String text, {
  String? recorderUserId,
  String? profileImageUrl,
}) async {
  if (text.isEmpty) {
    debugPrint('⚠️ [StateManager] 텍스트가 비어있음');
    return;
  }

  // 임시 저장 (프로필 위치 지정 후 실제 저장)
  _pendingVoiceComments[photoId] = PendingVoiceComment(
    text: text,
    isTextComment: true,
    recorderUserId: recorderUserId,
    profileImageUrl: profileImageUrl,
  );

  _notifyStateChanged();
}
```

**동작**:
1. `PendingVoiceComment` 객체 생성 (`isTextComment: true`)
2. `_pendingVoiceComments[photoId]`에 저장
3. UI 갱신 (`_notifyStateChanged()`)

---

### A4. VoiceCommentWidget이 Placing 모드로 시작
**파일**: [voice_comment_active_widget.dart:64](lib/views/common_widget/about_voice_comment/voice_comment_active_widget.dart#L64)

```dart
// Pending 텍스트 댓글이 있는 경우 자동 녹음 시작하지 않음
final hasPendingTextComment = pendingTextComments?[photo.id] ?? false;

return VoiceCommentWidget(
  autoStart: !shouldStartAsSaved && !hasPendingTextComment,
  startInPlacingMode: hasPendingTextComment, // 텍스트 댓글이 pending 중이면 placing 모드로 시작
  // ...
);
```

**파일**: [voice_comment_widget.dart:94](lib/views/common_widget/about_voice_comment/voice_comment_widget.dart#L94)

```dart
// Placing 모드로 시작해야 하는 경우 (텍스트 댓글용)
if (widget.startInPlacingMode) {
  _currentState = VoiceCommentState.placing;
  _initializeControllers();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _currentState == VoiceCommentState.placing) {
      _holdParentScroll(); // 스크롤 잠금
    }
  });
  return;
}
```

**동작**:
1. `pendingTextComments[photoId] == true`인 경우
2. `VoiceCommentWidget`이 `startInPlacingMode: true`로 생성
3. 초기 상태가 `VoiceCommentState.placing`
4. 프로필 이미지가 드래그 가능한 상태로 표시

---

## 🎙️ 플로우 B: 음성 댓글 생성

### B1. 자동 녹음 시작
**파일**: [voice_comment_widget.dart:112](lib/views/common_widget/about_voice_comment/voice_comment_widget.dart#L112)

```dart
// autoStart는 saved/placing 상태가 아닐 때만 적용
if (widget.autoStart && _currentState != VoiceCommentState.saved) {
  _currentState = VoiceCommentState.recording;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _startRecording();
  });
}
```

**파일**: [voice_comment_widget.dart:312](lib/views/common_widget/about_voice_comment/voice_comment_widget.dart#L312)

```dart
Future<void> _startRecording() async {
  try {
    // 녹음 시작 시간 기록
    _recordingStartTime = DateTime.now();

    await _recorderController.record();
    await _audioController.startRecording();

    setState(() {
      _lastState = _currentState;
      _currentState = VoiceCommentState.recording;
    });
  } catch (e) {
    setState(() {
      _lastState = _currentState;
      _currentState = VoiceCommentState.idle;
    });
  }
}
```

**동작**:
1. `RecorderController.record()` 호출 → 파형 시각화 시작
2. `AudioController.startRecording()` 호출 → 네이티브 녹음 시작
3. `_recordingStartTime` 기록 (duration 계산용)
4. 상태를 `VoiceCommentState.recording`으로 변경

---

### B2. 녹음 중지 및 재생 준비
**파일**: [voice_comment_widget.dart:334](lib/views/common_widget/about_voice_comment/voice_comment_widget.dart#L334)

```dart
Future<void> _stopAndPreparePlayback() async {
  try {
    // 파형 데이터 추출
    List<double> waveformData = List<double>.from(
      _recorderController.waveData,
    );
    if (waveformData.isNotEmpty) {
      waveformData = waveformData.map((value) => value.abs()).toList();
    }

    // 순차적으로 중지: 먼저 waveform controller
    if (_recorderController.isRecording) {
      await _recorderController.stop();
    }

    // 그 다음 native recorder
    await _audioController.stopRecordingSimple();

    final filePath = _audioController.currentRecordingPath;
    if (filePath != null && filePath.isNotEmpty) {
      // 녹음 시간 계산
      final recordingDuration = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
          : 0;

      // 재생 준비
      await _playerController?.preparePlayer(
        path: filePath,
        shouldExtractWaveform: true,
      );

      setState(() {
        _lastState = _currentState;
        _currentState = VoiceCommentState.recorded;
        _waveformData = waveformData;
      });

      // 콜백 호출 (duration 포함)
      widget.onRecordingCompleted?.call(
        filePath,
        waveformData,
        recordingDuration,
      );
    }
  } catch (e) {
    debugPrint('❌ 녹음 중지 오류: $e');
  }
}
```

**동작**:
1. `_recorderController.waveData`에서 파형 데이터 추출
2. 녹음 중지 (`RecorderController.stop()` → `AudioController.stopRecordingSimple()`)
3. 녹음 파일 경로 가져오기 (`currentRecordingPath`)
4. Duration 계산 (`DateTime.now() - _recordingStartTime`)
5. `PlayerController.preparePlayer()` 호출 → 재생 준비
6. 상태를 `VoiceCommentState.recorded`로 변경
7. `onRecordingCompleted(filePath, waveformData, duration)` 콜백 호출

---

### B3. StateManager에서 Pending 저장
**파일**: [voice_comment_state_manager.dart:110](lib/views/about_feed/manager/voice_comment_state_manager.dart#L110)

```dart
Future<void> onVoiceCommentCompleted(
  String photoId,
  String? audioPath,
  List<double>? waveformData,
  int? duration, {
  String? recorderUserId,
  String? profileImageUrl,
}) async {
  if (audioPath == null || waveformData == null || duration == null) {
    return;
  }

  // 임시 저장 (파형 클릭 시 실제 저장)
  _pendingVoiceComments[photoId] = PendingVoiceComment(
    audioPath: audioPath,
    waveformData: waveformData,
    duration: duration,
    isTextComment: false,
    recorderUserId: recorderUserId,
    profileImageUrl: profileImageUrl,
  );
  _notifyStateChanged();
}
```

**동작**:
1. `PendingVoiceComment` 객체 생성 (`isTextComment: false`)
2. `_pendingVoiceComments[photoId]`에 저장
3. UI 갱신

---

### B4. Recorded 상태에서 파형 위 프로필 표시
**파일**: [voice_comment_widget.dart:550](lib/views/common_widget/about_voice_comment/voice_comment_widget.dart#L550)

```dart
// 재생 파형 - 드래그 가능
Expanded(
  child: _buildWaveformDraggable(
    child: _waveformData != null && _waveformData!.isNotEmpty
        ? StreamBuilder<int>(
            stream: _playerController?.onCurrentDurationChanged ?? const Stream.empty(),
            builder: (context, positionSnapshot) {
              // ... 파형 위젯 표시
              return CustomWaveformWidget(
                waveformData: _waveformData!,
                color: Colors.grey,
                activeColor: Colors.white,
                progress: progress,
              );
            },
          )
        : Container(),
  ),
),
```

**파일**: [voice_comment_widget.dart:816](lib/views/common_widget/about_voice_comment/voice_comment_widget.dart#L816)

```dart
Widget _buildWaveformDraggable({required Widget child}) {
  if (widget.onProfileImageDragged == null ||
      _waveformData == null ||
      _waveformData!.isEmpty) {
    return child;
  }

  final profileWidget = _buildProfileAvatar();

  return Draggable<String>(
    key: _profileDraggableKey,
    data: 'profile_image',
    dragAnchorStrategy: pointerDragAnchorStrategy,
    feedback: Transform.scale(
      scale: 1.2,
      child: Opacity(opacity: 0.8, child: profileWidget),
    ),
    childWhenDragging: Opacity(opacity: 0.3, child: profileWidget),
    onDragStarted: _beginPlacementFromWaveform,
    child: child,
  );
}
```

**동작**:
1. 파형 위에 프로필 이미지가 `Draggable` 위젯으로 오버레이
2. 사용자가 프로필을 드래그하면 `onDragStarted` 호출

---

## 📍 플로우 C: 프로필 위치 지정 (공통)

### C1. 드래그 시작
**파일**: [voice_comment_widget.dart:691](lib/views/common_widget/about_voice_comment/voice_comment_widget.dart#L691)

```dart
void _beginPlacementFromWaveform() {
  if (_waveformData == null || _waveformData!.isEmpty) {
    return;
  }
  if (_currentState == VoiceCommentState.placing) {
    return;
  }

  _holdParentScroll(); // 스크롤 잠금
  setState(() {
    _lastState = _currentState;
    _currentState = VoiceCommentState.placing;
  });
}
```

**파일**: [voice_comment_widget.dart:954](lib/views/common_widget/about_voice_comment/voice_comment_widget.dart#L954)

```dart
void _holdParentScroll() {
  if (_scrollHoldController != null) {
    return;
  }
  final scrollable = Scrollable.maybeOf(context);
  final position = scrollable?.position;
  if (position == null) {
    return;
  }
  _scrollHoldController = position.hold(() => _scrollHoldController = null);
}
```

**동작**:
1. 상태를 `VoiceCommentState.placing`으로 변경
2. 부모 스크롤을 잠금 (`ScrollHoldController` 사용)
3. UI에서 프로필이 placing 모드로 표시됨

---

### C2. 사진 위에 드롭
**파일**: [photo_display_widget.dart:637](lib/views/common_widget/abput_photo/photo_display_widget.dart#L637)

```dart
DragTarget<String>(
  onWillAcceptWithDetails: (details) {
    return (details.data).isNotEmpty;
  },
  onAcceptWithDetails: (details) {
    // 드롭된 좌표를 사진 내 상대 좌표로 변환
    final RenderBox renderBox =
        builderContext.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.offset);

    // 프로필 크기(64)의 반지름만큼 보정하여 중심점으로 조정
    final adjustedPosition = Offset(
      localPosition.dx + 32,
      localPosition.dy + 32,
    );

    widget.onProfileImageDragged(
      widget.photo.id,
      adjustedPosition,
    );
  },
  builder: (context, candidateData, rejectedData) {
    // ... 사진 표시
  },
)
```

**동작**:
1. 사용자가 프로필을 사진 위로 드래그하여 드롭
2. `RenderBox.globalToLocal()`로 글로벌 좌표를 로컬 좌표로 변환
3. 프로필 반지름(32px) 만큼 보정하여 중심점 계산
4. `onProfileImageDragged(photoId, adjustedPosition)` 콜백 호출

---

### C3. 절대 좌표를 상대 좌표로 변환
**파일**: [voice_comment_state_manager.dart:264](lib/views/about_feed/manager/voice_comment_state_manager.dart#L264)

```dart
void onProfileImageDragged(String photoId, Offset absolutePosition) {
  // 이미지 크기 (ScreenUtil 기준 - PhotoDisplayWidget과 동일하게)
  final imageSize = Size(354.w, 500.h);

  // 절대 위치를 상대 위치로 변환 (0.0 ~ 1.0 범위)
  final relativePosition = PositionConverter.toRelativePosition(
    absolutePosition,
    imageSize,
  );

  // UI에 즉시 반영 (임시 위치) - stored in pendingComment
  final pendingComment = _pendingVoiceComments[photoId];
  if (pendingComment != null) {
    _pendingVoiceComments[photoId] = pendingComment.withPosition(
      relativePosition,
    );
    _notifyStateChanged();
    // 저장 전 위치만 갱신하고 종료
    return;
  }

  _notifyStateChanged();
}
```

**PositionConverter 유틸리티**:
```dart
// 절대 좌표 (px) → 상대 좌표 (0.0 ~ 1.0)
static Offset toRelativePosition(Offset absolutePosition, Size imageSize) {
  return Offset(
    absolutePosition.dx / imageSize.width,
    absolutePosition.dy / imageSize.height,
  );
}

// 상대 좌표 (0.0 ~ 1.0) → 절대 좌표 (px)
static Offset toAbsolutePosition(Offset relativePosition, Size imageSize) {
  return Offset(
    relativePosition.dx * imageSize.width,
    relativePosition.dy * imageSize.height,
  );
}
```

**동작**:
1. 이미지 크기는 `354.w × 500.h` (ScreenUtil 사용)
2. `PositionConverter.toRelativePosition()` 호출
3. 절대 좌표를 상대 좌표로 변환 (예: `dx=177px` → `dx=0.5`, `dy=250px` → `dy=0.5`)
4. `pendingComment.withPosition(relativePosition)`으로 위치 업데이트
5. UI 갱신

**왜 상대 좌표를 사용하나요?**
- 다양한 화면 크기와 해상도에서 일관된 위치 유지
- Firebase에 저장 시 화면 크기 독립적인 데이터 저장
- 불러올 때 `toAbsolutePosition()`으로 현재 화면 크기에 맞게 변환

---

### C4. Placing 모드 UI 표시
**파일**: [voice_comment_widget.dart:199](lib/views/common_widget/about_voice_comment/voice_comment_widget.dart#L199)

```dart
// 배치 모드 UI
// 프로필 드래그 앤 드롭을 위한 UI
case VoiceCommentState.placing:
  return Container(
    key: ValueKey(widgetKey),
    child: _buildProfileDraggable(isPlacementMode: true),
  );
```

**파일**: [voice_comment_widget.dart:842](lib/views/common_widget/about_voice_comment/voice_comment_widget.dart#L842)

```dart
Widget _buildProfileDraggable({required bool isPlacementMode}) {
  final profileWidget = _buildProfileAvatar();

  if (widget.onProfileImageDragged == null) {
    return profileWidget;
  }

  return Draggable<String>(
    key: isPlacementMode ? _profileDraggableKey : null,
    data: 'profile_image',
    dragAnchorStrategy: pointerDragAnchorStrategy,
    feedback: Transform.scale(
      scale: 1.2,
      child: Opacity(opacity: 0.8, child: profileWidget),
    ),
    childWhenDragging: Opacity(opacity: 0.3, child: profileWidget),
    onDraggableCanceled: (velocity, offset) {
      if (!isPlacementMode) {
        return;
      }
      _cancelPlacement(); // 취소 시 recorded 상태로 복귀
    },
    onDragEnd: (details) {
      if (!isPlacementMode) {
        return;
      }

      if (details.wasAccepted) {
        _finalizePlacement(); // 드롭 성공 시 저장
      }
    },
    child: profileWidget,
  );
}
```

**동작**:
1. Placing 모드에서는 프로필 이미지만 화면 하단에 표시
2. 사용자가 다시 드래그하여 위치 수정 가능
3. 사진 위에 드롭하면 `onDragEnd` 호출
4. 유효하지 않은 영역에 드롭하면 `onDraggableCanceled` 호출

---

## 💾 플로우 D: Firebase 최종 저장

### D1. 저장 확정
**파일**: [voice_comment_widget.dart:708](lib/views/common_widget/about_voice_comment/voice_comment_widget.dart#L708)

```dart
Future<void> _finalizePlacement() async {
  if (_isFinalizingPlacement) {
    return; // 중복 방지
  }

  _releaseParentScroll(); // 스크롤 잠금 해제
  _isFinalizingPlacement = true;

  // 저장이 끝나기 전에 UI에서 미리 프로필을 표시
  if (_currentState != VoiceCommentState.saved) {
    setState(() {
      _lastState = _currentState;
      _currentState = VoiceCommentState.saved;
    });
  }

  try {
    if (widget.onSaveRequested != null) {
      await widget.onSaveRequested!.call();
    }

    if (!mounted) {
      return;
    }

    _markAsSaved();
    widget.onSaveCompleted?.call();
  } catch (e) {
    if (mounted) {
      // 저장 실패 시 다시 파형 모드로 복귀
      setState(() {
        _lastState = _currentState;
        _currentState = VoiceCommentState.recorded;
      });
    }
  } finally {
    _isFinalizingPlacement = false;
  }
}
```

**동작**:
1. 상태를 `VoiceCommentState.saved`로 변경 (UI에 미리 표시)
2. 스크롤 잠금 해제
3. `onSaveRequested()` 콜백 호출 → StateManager로 전달
4. 저장 실패 시 `recorded` 상태로 복귀

---

### D2. Firebase 저장 로직
**파일**: [voice_comment_state_manager.dart:158](lib/views/about_feed/manager/voice_comment_state_manager.dart#L158)

```dart
Future<void> saveVoiceComment(String photoId, BuildContext context) async {
  final pendingComment = _pendingVoiceComments[photoId];
  if (pendingComment == null) {
    throw StateError('임시 음성 댓글 데이터를 찾을 수 없습니다. photoId: $photoId');
  }

  try {
    final authController = Provider.of<AuthController>(
      context,
      listen: false,
    );
    final commentRecordController = CommentRecordController();
    final currentUserId = authController.getUserId;

    if (currentUserId == null || currentUserId.isEmpty) {
      throw Exception('로그인된 사용자를 찾을 수 없습니다.');
    }

    final profileImageUrl = await authController
        .getUserProfileImageUrlWithCache(currentUserId);

    // Pending comment already has the position
    final currentProfilePosition = pendingComment.relativePosition;

    if (currentProfilePosition == null) {
      throw StateError('음성 댓글 저장 위치를 찾을 수 없습니다. photoId: $photoId');
    }

    CommentRecordModel? commentRecord;

    // 텍스트 댓글과 음성 댓글 구분하여 저장
    if (pendingComment.isTextComment) {
      if (pendingComment.text == null || pendingComment.text!.isEmpty) {
        throw Exception('텍스트 댓글 내용이 비어있습니다.');
      }
      commentRecord = await commentRecordController.createTextComment(
        text: pendingComment.text!,
        photoId: photoId,
        recorderUser: currentUserId,
        profileImageUrl: profileImageUrl,
        relativePosition: currentProfilePosition,
      );
    } else {
      if (pendingComment.audioPath == null ||
          pendingComment.waveformData == null ||
          pendingComment.duration == null) {
        throw Exception('음성 댓글 데이터가 유효하지 않습니다.');
      }
      commentRecord = await commentRecordController.createCommentRecord(
        audioFilePath: pendingComment.audioPath!,
        photoId: photoId,
        recorderUser: currentUserId,
        waveformData: pendingComment.waveformData!,
        duration: pendingComment.duration!,
        profileImageUrl: profileImageUrl,
        relativePosition: currentProfilePosition,
      );
    }

    if (commentRecord == null) {
      if (context.mounted) {
        commentRecordController.showErrorToUser(context);
      }
      throw Exception('댓글 저장에 실패했습니다. photoId: $photoId');
    }

    _voiceCommentSavedStates[photoId] = true;

    // 다중 댓글 지원: 기존 댓글 목록에 새 댓글 추가 (중복 방지)
    if (_savedCommentIds[photoId] == null) {
      _savedCommentIds[photoId] = [commentRecord.id];
    } else {
      // 중복 확인 후 추가
      if (!_savedCommentIds[photoId]!.contains(commentRecord.id)) {
        _savedCommentIds[photoId]!.add(commentRecord.id);
      }
    }

    // 임시 데이터 삭제
    _pendingVoiceComments.remove(photoId);

    _notifyStateChanged();
  } catch (e) {
    debugPrint("댓글 저장 중 오류 발생: $e");
    rethrow;
  }
}
```

**동작**:
1. `_pendingVoiceComments[photoId]`에서 임시 데이터 가져오기
2. 현재 사용자 정보 가져오기 (`AuthController`)
3. `relativePosition` 검증 (null이면 에러)
4. **텍스트 댓글**인 경우:
   - `CommentRecordController.createTextComment()` 호출
   - 파라미터: `text`, `photoId`, `recorderUser`, `profileImageUrl`, `relativePosition`
5. **음성 댓글**인 경우:
   - `CommentRecordController.createCommentRecord()` 호출
   - 파라미터: `audioFilePath`, `photoId`, `recorderUser`, `waveformData`, `duration`, `profileImageUrl`, `relativePosition`
6. 저장 성공 시:
   - `_voiceCommentSavedStates[photoId] = true`
   - `_savedCommentIds[photoId]`에 댓글 ID 추가 (다중 댓글 지원)
   - `_pendingVoiceComments.remove(photoId)`로 임시 데이터 삭제
7. UI 갱신

---

### D3. 저장 완료 후 상태 초기화
**파일**: [voice_comment_widget.dart:764](lib/views/common_widget/about_voice_comment/voice_comment_widget.dart#L764)

```dart
void _markAsSaved() {
  _releaseParentScroll();
  // 애니메이션을 위해 _lastState 설정
  setState(() {
    _lastState = _currentState;
    _currentState = VoiceCommentState.saved;
  });

  // 상태 변경 후 컨트롤러들을 정리 (애니메이션 후에)
  Future.delayed(Duration(milliseconds: 400), () {
    if (mounted) {
      _cleanupControllers();
      setState(() {
        // 파형 데이터 정리
        _waveformData = null;
      });
    }
  });

  // 저장 완료 콜백 호출
  widget.onSaved?.call();
}
```

**파일**: [voice_comment_state_manager.dart:254](lib/views/about_feed/manager/voice_comment_state_manager.dart#L254)

```dart
void onSaveCompleted(String photoId) {
  // 저장 완료 후 다시 버튼 상태로 돌아가서 추가 댓글 녹음 가능
  _voiceCommentActiveStates[photoId] = false;

  // 임시 데이터 정리
  _pendingVoiceComments.remove(photoId);
  _notifyStateChanged();
}
```

**동작**:
1. 컨트롤러 정리 (`RecorderController`, `PlayerController` dispose)
2. 파형 데이터 삭제
3. Active 상태를 false로 변경 → 다시 녹음 버튼 표시 (다중 댓글 지원)
4. Pending 데이터 삭제

---

## 🔄 플로우 E: 실시간 동기화

### E1. Firestore 스트림 구독
**파일**: [voice_comment_state_manager.dart:301](lib/views/about_feed/manager/voice_comment_state_manager.dart#L301)

```dart
void subscribeToVoiceCommentsForPhoto(String photoId, String currentUserId) {
  try {
    _commentStreams[photoId]?.cancel(); // 기존 구독 취소

    _commentStreams[photoId] = CommentRecordController()
        .getCommentRecordsStream(photoId)
        .listen(
          (comments) =>
              _handleCommentsUpdate(photoId, currentUserId, comments),
        );

    // 실시간 스트림과 별개로 기존 댓글도 직접 로드
    _loadExistingCommentsForPhoto(photoId, currentUserId);
  } catch (e) {
    debugPrint('Feed - 실시간 댓글 구독 시작 실패 - 사진 $photoId: $e');
  }
}
```

**동작**:
1. `CommentRecordController.getCommentRecordsStream(photoId)` 호출
2. Firestore 컬렉션 `comment_records`에서 `photoId`로 필터링된 실시간 스트림
3. 댓글이 추가/수정/삭제될 때마다 콜백 호출
4. `_loadExistingCommentsForPhoto()`로 기존 댓글도 직접 로드 (스트림 지연 대비)

---

### E2. 댓글 업데이트 처리
**파일**: [voice_comment_state_manager.dart:337](lib/views/about_feed/manager/voice_comment_state_manager.dart#L337)

```dart
void _handleCommentsUpdate(
  String photoId,
  String currentUserId,
  List<CommentRecordModel> comments,
) {
  _photoComments[photoId] = comments;

  // 현재 사용자의 모든 댓글 처리 (다중 댓글 지원)
  final userComments = comments
      .where((comment) => comment.recorderUser == currentUserId)
      .toList();

  if (userComments.isNotEmpty) {
    // 사진별 댓글 ID 목록 업데이트 (중복 방지)
    final mergedIds = <String>[
      ...(_savedCommentIds[photoId] ?? const <String>[]),
      ...userComments.map((c) => c.id),
    ];

    _savedCommentIds[photoId] = mergedIds.toSet().toList();

    // 각 댓글은 자신의 위치를 relativePosition 필드에 저장
    // 별도로 위치를 추출하거나 저장할 필요 없음
  } else {
    // 현재 사용자의 댓글이 없는 경우 상태 초기화
    _voiceCommentSavedStates[photoId] = false;

    // 다른 사용자의 댓글은 유지하되 현재 사용자 관련 상태만 초기화
    if (comments.isEmpty) {
      _photoComments[photoId] = [];
    }
  }

  _notifyStateChanged();
}
```

**동작**:
1. `_photoComments[photoId]` 업데이트
2. 현재 사용자의 댓글 필터링 (`recorderUser == currentUserId`)
3. `_savedCommentIds[photoId]` 업데이트 (중복 제거)
4. UI 갱신

---

### E3. UI에 댓글 아바타 표시
**파일**: [photo_display_widget.dart:311](lib/views/common_widget/abput_photo/photo_display_widget.dart#L311)

```dart
List<Widget> _buildCommentAvatars() {
  if (!_isShowingComments) return [];

  final comments = widget.photoComments[widget.photo.id] ?? [];
  final commentsWithPosition = comments
      .where((comment) => comment.relativePosition != null)
      .toList();

  final actualImageSize = Size(_imageWidth.w, _imageHeight.h);

  return commentsWithPosition.map((comment) {
    // 오버레이 중이면 선택된 댓글 외에는 숨김
    if (_showActionOverlay &&
        _selectedCommentId != null &&
        comment.id != _selectedCommentId) {
      return const SizedBox.shrink();
    }

    final absolutePosition = PositionConverter.toAbsolutePosition(
      comment.relativePosition!,
      actualImageSize,
    );
    final clampedPosition = PositionConverter.clampPosition(
      absolutePosition,
      actualImageSize,
    );

    return Positioned(
      left: clampedPosition.dx - _avatarRadius,
      top: clampedPosition.dy - _avatarRadius,
      child: GestureDetector(
        onLongPress: () {
          setState(() {
            _selectedCommentId = comment.id;
            _selectedCommentPosition = clampedPosition;
            _showActionOverlay = true;
          });
        },
        child: Consumer2<AuthController, CommentAudioController>(
          builder: (context, authController, commentAudioController, child) {
            final isCurrentCommentPlaying = commentAudioController
                .isCommentPlaying(comment.id);
            final isSelected =
                _showActionOverlay && _selectedCommentId == comment.id;

            return InkWell(
              onTap: () async {
                // 댓글 바텀시트 표시
                // ...
              },
              child: Container(
                width: _avatarSize,
                height: _avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: isSelected ? [...] : null,
                  border: Border.all(
                    color: isSelected || isCurrentCommentPlaying
                        ? Colors.white
                        : Colors.transparent,
                    width: isSelected ? 2.2 : 1,
                  ),
                ),
                child: _buildCircleAvatar(
                  imageUrl: comment.profileImageUrl,
                  size: _avatarSize,
                ),
              ),
            );
          },
        ),
      ),
    );
  }).toList();
}
```

**동작**:
1. `_isShowingComments == true`일 때만 표시 (사진 탭하면 토글)
2. `relativePosition != null`인 댓글만 필터링
3. 각 댓글에 대해:
   - `PositionConverter.toAbsolutePosition()`로 상대 좌표를 절대 좌표로 변환
   - `PositionConverter.clampPosition()`로 이미지 범위 내로 제한
   - `Positioned` 위젯으로 아바타 배치 (`left`, `top`)
4. 롱프레스 시 삭제 팝업 표시
5. 탭 시 댓글 바텀시트 표시 (재생 가능)

---

## 🔧 주요 헬퍼 클래스 및 유틸리티

### PositionConverter
**파일**: `lib/utils/position_converter.dart`

```dart
class PositionConverter {
  /// 절대 좌표 → 상대 좌표 (0.0 ~ 1.0)
  static Offset toRelativePosition(Offset absolutePosition, Size imageSize) {
    return Offset(
      (absolutePosition.dx / imageSize.width).clamp(0.0, 1.0),
      (absolutePosition.dy / imageSize.height).clamp(0.0, 1.0),
    );
  }

  /// 상대 좌표 → 절대 좌표 (px)
  static Offset toAbsolutePosition(Offset relativePosition, Size imageSize) {
    return Offset(
      relativePosition.dx * imageSize.width,
      relativePosition.dy * imageSize.height,
    );
  }

  /// 좌표를 이미지 범위 내로 제한
  static Offset clampPosition(Offset position, Size imageSize) {
    return Offset(
      position.dx.clamp(0.0, imageSize.width),
      position.dy.clamp(0.0, imageSize.height),
    );
  }
}
```

### CommentRecordController (Firebase 레이어)
주요 메서드:
- `createTextComment()`: 텍스트 댓글을 Firestore에 저장
- `createCommentRecord()`: 음성 파일을 Storage에 업로드 후 Firestore에 메타데이터 저장
- `getCommentRecordsStream(photoId)`: Firestore 실시간 스트림 구독
- `updateRelativeProfilePosition()`: 댓글 위치 업데이트
- `hardDeleteCommentRecord()`: 댓글 삭제

---

## API 버전 적용 가이드

### 변경 필요 사항

#### 1. 파일 업로드
**Firebase**: Storage에 직접 업로드
```dart
await FirebaseStorage.instance
    .ref('comments/$userId/$filename')
    .putFile(File(audioFilePath));
```

**API 버전**:
```dart
// MediaService 사용
final audioKey = await MediaService.uploadAudio(
  audioFilePath: audioFilePath,
  userId: userId,
);
// audioKey는 서버에서 반환한 파일 키 또는 URL
```

**변경 파일**: `CommentRecordController` → `ApiCommentController`

---

#### 2. 댓글 생성
**Firebase**: Firestore에 직접 저장
```dart
await FirebaseFirestore.instance
    .collection('comment_records')
    .add({
      'photoId': photoId,
      'recorderUser': userId,
      'text': text,
      'audioUrl': audioUrl,
      'waveformData': waveformData,
      'duration': duration,
      'relativePosition': {
        'dx': relativePosition.dx,
        'dy': relativePosition.dy,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
```

**API 버전**: (참고: [comment_controller.dart:48](lib/api/controller/comment_controller.dart#L48))
```dart
Future<bool> createComment({
  required int postId,          // photoId를 postId로 매핑
  required int userId,          // String → int 변환 필요 시
  String? text,                 // 텍스트 댓글
  String? audioKey,             // 음성 파일 키
  String? waveformData,         // JSON 문자열로 변환
  int? duration,                // 밀리초 단위
  double? locationX,            // relativePosition.dx
  double? locationY,            // relativePosition.dy
});
```

**변경 사항**:
- `photoId` → `postId` (서버 모델에 맞게)
- `userId`: String → int 변환 (필요 시)
- `waveformData`: `List<double>` → `String` (JSON 직렬화)
- `relativePosition`: `Offset` → `locationX`, `locationY` (double)

**구현 예시**:
```dart
class ApiCommentController extends CommentController {
  final CommentService _commentService = CommentService();

  @override
  Future<bool> createComment({
    required int postId,
    required int userId,
    String? text,
    String? audioKey,
    String? waveformData,
    int? duration,
    double? locationX,
    double? locationY,
  }) async {
    try {
      final response = await _commentService.createComment(
        postId: postId,
        userId: userId,
        text: text,
        audioKey: audioKey,
        waveformData: waveformData,
        duration: duration,
        locationX: locationX,
        locationY: locationY,
      );

      notifyListeners();
      return response.success;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  @override
  Future<bool> createTextComment({
    required int postId,
    required int userId,
    required String content,
    double? locationX,
    double? locationY,
  }) async {
    return createComment(
      postId: postId,
      userId: userId,
      text: content,
      locationX: locationX,
      locationY: locationY,
    );
  }

  @override
  Future<bool> createAudioComment({
    required int postId,
    required int userId,
    required String audioKey,
    String? waveformData,
    int? duration,
    double? locationX,
    double? locationY,
  }) async {
    return createComment(
      postId: postId,
      userId: userId,
      audioKey: audioKey,
      waveformData: waveformData,
      duration: duration,
      locationX: locationX,
      locationY: locationY,
    );
  }
}
```

---

#### 3. 실시간 동기화
**Firebase**: Firestore 스트림
```dart
Stream<List<CommentRecordModel>> getCommentRecordsStream(String photoId) {
  return FirebaseFirestore.instance
      .collection('comment_records')
      .where('photoId', isEqualTo: photoId)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(...).toList());
}
```

**API 버전 옵션**:

**옵션 A: 폴링 (Polling)**
```dart
class ApiCommentService {
  Timer? _pollingTimer;

  void startPolling(int postId, Function(List<Comment>) onUpdate) {
    _pollingTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      try {
        final comments = await getComments(postId: postId);
        onUpdate(comments);
      } catch (e) {
        debugPrint('Polling error: $e');
      }
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
  }
}
```

**옵션 B: WebSocket / Server-Sent Events (SSE)**
```dart
class ApiCommentService {
  WebSocketChannel? _channel;

  Stream<List<Comment>> getCommentsStream(int postId) {
    _channel = WebSocketChannel.connect(
      Uri.parse('wss://api.example.com/comments/$postId'),
    );

    return _channel!.stream.map((data) {
      final json = jsonDecode(data);
      return (json as List).map((e) => Comment.fromJson(e)).toList();
    });
  }

  void dispose() {
    _channel?.sink.close();
  }
}
```

**권장**: 초기 구현은 폴링, 추후 WebSocket으로 업그레이드

---

#### 4. 인증
**Firebase**: AuthController (Firebase Auth)
```dart
final userId = authController.currentUser?.uid;
```

**API 버전**: 토큰 기반 인증
```dart
class ApiAuthController {
  String? _accessToken;
  User? _currentUser;

  Future<bool> login(String email, String password) async {
    final response = await _authService.login(email, password);
    _accessToken = response.accessToken;
    _currentUser = response.user;
    return true;
  }

  int? get userId => _currentUser?.id;
  String? get token => _accessToken;
}
```

**HTTP 요청 시 헤더 추가**:
```dart
final headers = {
  'Authorization': 'Bearer ${authController.token}',
  'Content-Type': 'application/json',
};
```

---

#### 5. 에러 처리
**Firebase**: FirebaseException
```dart
try {
  await saveComment();
} on FirebaseException catch (e) {
  if (e.code == 'permission-denied') {
    // ...
  }
}
```

**API 버전**: HTTP 상태 코드
```dart
try {
  final response = await dio.post('/comments', data: data);
  if (response.statusCode == 200) {
    return response.data;
  }
} on DioException catch (e) {
  if (e.response?.statusCode == 401) {
    // 인증 만료
    await authController.refreshToken();
  } else if (e.response?.statusCode == 400) {
    // 잘못된 요청
    throw Exception('잘못된 요청입니다.');
  }
}
```

---

### 변경이 필요한 파일 요약

| Firebase 파일 | API 버전 파일 | 주요 변경 사항 |
|--------------|-------------|--------------|
| `voice_comment_state_manager.dart` | `api_voice_comment_state_manager.dart` | - `saveVoiceComment()` 메서드 수정<br>- `CommentRecordController` → `ApiCommentController`<br>- 스트림 구독 → 폴링/WebSocket |
| `CommentRecordController` | `ApiCommentController` | - Firestore → REST API 호출<br>- Storage → `MediaService.uploadAudio()` |
| `photo_display_widget.dart` | (변경 없음) | - UI 로직은 동일 (상대 좌표 시스템 유지) |
| `voice_comment_widget.dart` | (변경 없음) | - 상태 머신 로직 동일 |
| `position_converter.dart` | (변경 없음) | - 유틸리티 동일 |

---

### 상대 좌표 시스템 유지

**중요**: API 버전에서도 **상대 좌표 (0.0 ~ 1.0)** 시스템을 그대로 사용하세요.

**이유**:
- 다양한 화면 크기 대응
- 프론트엔드 독립적인 데이터 저장
- 백엔드는 상대 좌표만 저장하고, 프론트엔드에서 절대 좌표로 변환

**데이터베이스 스키마**:
```sql
CREATE TABLE comments (
  id INT PRIMARY KEY AUTO_INCREMENT,
  post_id INT NOT NULL,
  user_id INT NOT NULL,
  text TEXT,
  audio_key VARCHAR(255),
  waveform_data TEXT,  -- JSON 문자열
  duration INT,        -- 밀리초
  location_x DOUBLE,   -- 상대 좌표 (0.0 ~ 1.0)
  location_y DOUBLE,   -- 상대 좌표 (0.0 ~ 1.0)
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (post_id) REFERENCES posts(id),
  FOREIGN KEY (user_id) REFERENCES users(id)
);
```

---

## 다이어그램 요약

### 전체 플로우 다이어그램
```
┌──────────────────┐
│ 사용자 입력      │ (텍스트 또는 음성 녹음)
└────────┬─────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ Pending 상태로 임시 저장              │
│ (_pendingVoiceComments[photoId])     │
│  - 텍스트: text, isTextComment=true  │
│  - 음성: audioPath, waveformData     │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ Placing 모드 활성화                   │
│ (VoiceCommentState.placing)          │
│  - 프로필 이미지 드래그 가능          │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ 사진 위에 드롭                        │
│ (DragTarget.onAcceptWithDetails)     │
│  - 글로벌 좌표 → 로컬 좌표 변환       │
│  - 프로필 반지름 보정                 │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ 절대 좌표 → 상대 좌표 변환             │
│ (PositionConverter.toRelativePosition)│
│  - 이미지 크기: 354.w × 500.h         │
│  - 결과: Offset(dx: 0.0~1.0, dy: 0.0~1.0) │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ Pending 데이터에 위치 저장             │
│ (pendingComment.withPosition)         │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ Firebase 최종 저장                     │
│ (VoiceCommentStateManager.saveVoiceComment) │
│  - 텍스트: createTextComment()        │
│  - 음성: createCommentRecord()        │
│    1. Storage에 음성 파일 업로드       │
│    2. Firestore에 메타데이터 저장      │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ 실시간 동기화                          │
│ (Firestore Stream)                    │
│  - 다른 사용자 댓글도 실시간 반영       │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ UI에 댓글 아바타 표시                  │
│ (PhotoDisplayWidget._buildCommentAvatars) │
│  - 상대 좌표 → 절대 좌표 변환           │
│  - Positioned 위젯으로 배치            │
└──────────────────────────────────────┘
```

---

## 체크리스트: API 버전 구현 시

- [ ] `ApiCommentController` 클래스 구현
  - [ ] `createComment()` 메서드
  - [ ] `createTextComment()` 편의 메서드
  - [ ] `createAudioComment()` 편의 메서드
  - [ ] `getComments()` 메서드
- [ ] `MediaService` 클래스 구현
  - [ ] `uploadAudio()` 메서드 (multipart/form-data)
- [ ] `CommentService` 클래스 구현
  - [ ] POST `/api/comments` 엔드포인트 호출
  - [ ] GET `/api/comments?postId={postId}` 엔드포인트 호출
- [ ] 실시간 동기화 구현
  - [ ] 폴링 방식 (초기)
  - [ ] WebSocket / SSE (추후)
- [ ] 데이터 변환 로직
  - [ ] `photoId` → `postId`
  - [ ] `userId`: String → int
  - [ ] `waveformData`: List<double> → JSON String
  - [ ] `relativePosition`: Offset → `locationX`, `locationY`
- [ ] `ApiVoiceCommentStateManager` 수정
  - [ ] `saveVoiceComment()` 메서드 API 버전으로 수정
  - [ ] 스트림 구독 → 폴링 또는 WebSocket
- [ ] 에러 처리
  - [ ] HTTP 401: 토큰 갱신
  - [ ] HTTP 400: 잘못된 요청
  - [ ] HTTP 500: 서버 에러
- [ ] 테스트
  - [ ] 텍스트 댓글 생성 및 표시
  - [ ] 음성 댓글 생성 및 표시
  - [ ] 다중 댓글 지원
  - [ ] 다양한 화면 크기에서 위치 정확도

---

## 마무리

이 문서는 Firebase 버전의 댓글 태그 시스템 플로우를 상세히 분석한 결과입니다. API 버전으로 전환 시 **핵심 UI 로직과 상태 머신은 그대로 유지**하고, **데이터 레이어(Firebase → REST API)**만 교체하면 됩니다.

**핵심 포인트**:
1. **상대 좌표 시스템 유지** (0.0 ~ 1.0 범위)
2. **Pending 상태 관리** (위치 지정 전 임시 저장)
3. **다중 댓글 지원** (한 사진에 여러 댓글)
4. **실시간 동기화** (폴링 또는 WebSocket)

질문이나 추가 설명이 필요하시면 언제든지 문의하세요! 🚀
