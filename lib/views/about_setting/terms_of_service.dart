import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TermsOfService extends StatefulWidget {
  const TermsOfService({super.key});

  @override
  State<TermsOfService> createState() => _TermsOfServiceState();
}

class _TermsOfServiceState extends State<TermsOfService> {
  final String _html = """
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8" />
  <title>SOI 서비스 이용약관</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <style>
    body { font-family: -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif; line-height: 1.6; padding: 16px; background-color: #000; color: #fff; }
    h1 { font-size: 1.6rem; margin-bottom: 0.5rem; color: #fff; }
    h2 { font-size: 1.2rem; margin-top: 1.5rem; color: #fff; }
    p, li { font-size: 0.95rem; color: #fff; }
    ul, ol { padding-left: 1.2rem; }
    small { color: #ccc; }
  </style>
</head>

<body>
  <h1>SOI 서비스 이용약관</h1>
  <p>본 약관은 팀 NewDawn(이하 "회사")가 제공하는 SOI 서비스(이하 "서비스")의 이용과 관련하여 회사와 이용자 간의 권리, 의무 및 책임 사항을 규정함을 목적으로 합니다.</p>
  <p><small>시행일: 2025년 11월 27일</small></p>

  <h2>제1조 (약관의 적용 및 변경)</h2>
  <ol>
    <li>본 약관은 SOI 서비스를 이용하는 모든 이용자에게 적용됩니다.</li>
    <li>회사는 관련 법령을 위배하지 않는 범위에서 본 약관을 변경할 수 있습니다.</li>
    <li>약관이 변경되는 경우 회사는 변경 사항과 시행일자를 서비스 내 공지사항 또는 이메일로 사전에 공지합니다.</li>
  </ol>

  <h2>제2조 (서비스의 제공)</h2>
  <ol>
    <li>서비스 주요 기능은 다음과 같습니다.
      <ul>
        <li>사진 업로드</li>
        <li>사진 내 특정 지점에 텍스트·음성 태그 기능</li>
        <li>친구와 사진 공유</li>
        <li>사진에 대한 텍스트 댓글·태그 기능</li>
      </ul>
    </li>
    <li>회사는 서비스 제공을 위해 최선을 다하지만, 아래의 사유 발생 시 서비스의 전부 또는 일부가 제한되거나 중단될 수 있습니다.
      <ul>
        <li>서버 점검 또는 장애</li>
        <li>천재지변 등 불가항력</li>
        <li>전기통신사업자 또는 외부 플랫폼(Firebase, Supabase 등)의 장애</li>
      </ul>
    </li>
  </ol>

  <h2>제3조 (회원 가입 및 계정 관리)</h2>
  <ol>
    <li>이용자는 이름, 생년월일, 휴대전화번호, 사용자 ID, 프로필 사진을 제공하여 계정을 생성합니다.</li>
    <li>서비스는 전 연령 이용이 가능하며, 만 14세 미만 이용자의 경우 관련 법령에 따라 추가적인 보호 조치가 적용될 수 있습니다.</li>
    <li>이용자는 자신의 계정 정보를 정확하고 최신으로 유지해야 합니다.</li>
    <li>비밀번호 또는 인증 정보 관리 책임은 이용자 본인에게 있으며, 계정을 제3자에게 양도하거나 공유할 수 없습니다.</li>
  </ol>

  <h2>제4조 (이용자의 의무)</h2>
  <ol>
    <li>이용자는 서비스 이용 시 다음 행위를 해서는 안 됩니다.
      <ul>
        <li>불법 콘텐츠 업로드</li>
        <li>타인의 개인정보 또는 계정 정보 도용</li>
        <li>음란물, 폭력적·혐오·차별적 표현 등 부적절한 콘텐츠 게시</li>
        <li>시스템을 악용하거나 비정상적인 방식(스크래핑, 자동화 도구 등)으로 접근하는 행위</li>
        <li>기타 회사의 운영정책을 위반하는 행위</li>
      </ul>
    </li>
    <li>이용자가 본 조를 위반하는 경우 회사는 경고, 이용 제한, 계정 정지 등 필요한 조치를 취할 수 있습니다.</li>
  </ol>

  <h2>제5조 (콘텐츠의 권리 및 사용)</h2>
  <ol>
    <li>서비스에 업로드된 사진, 음성 태그, 텍스트 태그 등의 콘텐츠에 대한 저작권은 콘텐츠를 제작한 이용자에게 귀속됩니다.</li>
    <li>이용자는 회사가 다음의 목적 범위에서 콘텐츠를 사용할 수 있음을 동의합니다.
      <ul>
        <li>서비스 운영 및 제공</li>
        <li>기능 개선 및 오류 분석</li>
        <li>비식별화된 통계 자료 생성</li>
      </ul>
    </li>
    <li>회사는 이용자의 동의 없이 콘텐츠를 외부에 공개하지 않습니다.</li>
  </ol>

  <h2>제6조 (서비스 이용 제한 및 계정 해지)</h2>
  <ol>
    <li>회사는 다음의 사유가 있는 경우 계정 일시 정지 또는 영구 정지 조치를 취할 수 있습니다.
      <ul>
        <li>불법 콘텐츠 업로드</li>
        <li>타인의 정보 도용</li>
        <li>음란물 또는 폭력적·혐오 표현 업로드</li>
        <li>시스템 악용, 비정상적 사용</li>
        <li>기타 운영정책 위반</li>
      </ul>
    </li>
    <li>이용자는 앱 내 설정 메뉴를 통해 언제든지 탈퇴할 수 있습니다.</li>
    <li>탈퇴 시 이용자의 모든 데이터는 개인정보처리방침에 따라 삭제됩니다.</li>
  </ol>

  <h2>제7조 (책임의 제한)</h2>
  <ol>
    <li>회사는 다음과 같은 사항에 대해 책임을 지지 않습니다.
      <ul>
        <li>이용자가 서비스에 업로드한 콘텐츠에 대한 법적 책임</li>
        <li>이용자의 기기 환경 문제(OS 버전, 저장 공간 부족 등)로 인해 발생한 문제</li>
        <li>Firebase, Supabase 등 외부 플랫폼 또는 네트워크 오류로 인해 발생한 장애</li>
        <li>천재지변, 해킹 등 불가항력에 의한 서비스 이용 불가</li>
      </ul>
    </li>
    <li>회사는 이용자가 서비스 이용 중 발생한 간접적 손해, 특별 손해에 대해 책임을 지지 않습니다.</li>
  </ol>

  <h2>제8조 (유료 서비스)</h2>
  <p>현재 SOI는 별도의 유료 결제 기능을 제공하지 않습니다.</p>

  <h2>제9조 (개인정보 보호)</h2>
  <p>회사는 이용자의 개인정보를 관련 법령 및 개인정보처리방침에 따라 안전하게 처리합니다.</p>

  <h2>제10조 (지적재산권)</h2>
  <ol>
    <li>서비스 및 관련 소프트웨어, 디자인, 로고 등 일체의 지식재산권은 회사에 귀속됩니다.</li>
    <li>이용자는 회사의 명시적 승인 없이 서비스 내 자료를 복제, 배포, 수정, 판매할 수 없습니다.</li>
  </ol>

  <h2>제11조 (관할 법원)</h2>
  <p>서비스 이용과 관련하여 회사와 이용자 사이에 분쟁이 발생할 경우 대한민국 서울중앙지방법원을 전속 관할로 합니다.</p>

  <h2>제12조 (약관의 시행)</h2>
  <p>본 약관은 상단에 기재된 시행일부터 적용됩니다.</p>

</body>
</html>
""";

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('서비스 이용약관'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: WebViewWidget(
        controller: WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.black)
          ..loadHtmlString(_html),
      ),
    );
  }
}
