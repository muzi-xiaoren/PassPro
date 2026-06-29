// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get enterMasterKey => '마스터 키를 입력하세요';

  @override
  String get masterKeyLabel => '마스터 키';

  @override
  String get unlock => '잠금 해제';

  @override
  String get masterKeyHint =>
      '마스터 키는 저장되지 않으며 실행할 때마다 다시 입력해야 합니다.\n비워 두면 공백 한 칸을 키로 사용합니다.';

  @override
  String get checkUpdate => '업데이트 확인';

  @override
  String get checkingUpdate => '업데이트 확인 중…';

  @override
  String updateUpToDate(String version) {
    return '최신 버전입니다 ($version)';
  }

  @override
  String updateAvailable(String version) {
    return '새 버전 $version 사용 가능 — 눌러서 다운로드';
  }

  @override
  String get updateCheckFailed => '업데이트 확인 실패';

  @override
  String get websiteCopied => '사이트 주소 복사됨';

  @override
  String get sectionBackup => '로컬 백업';

  @override
  String get exportBackup => '암호화 백업 내보내기 (.log)';

  @override
  String get exportBackupSub =>
      '비밀번호는 암호화된 상태로 유지되며, 같은 마스터 키로 다른 기기에서 가져올 수 있습니다';

  @override
  String get importBackup => '암호화 백업 가져오기 (.log)';

  @override
  String get importBackupSub => '현재 보관함에 레코드 단위로 병합되며 데이터가 사라지지 않습니다';

  @override
  String get exportCsvTitle => '평문 CSV 내보내기';

  @override
  String get exportCsvSub => '사이트 / 아이디 / 비밀번호를 평문으로 내보냄 — 유출 주의';

  @override
  String get importCsvTitle => 'CSV에서 가져오기';

  @override
  String get importCsvSub => '사이트, 아이디, 비밀번호 3개 열을 읽습니다';

  @override
  String get exportCsvWarnTitle => '평문 비밀번호를 내보낼까요?';

  @override
  String get exportCsvWarnBody => 'CSV 파일의 비밀번호는 평문이라 누구나 읽을 수 있습니다. 계속할까요?';

  @override
  String exportDone(int count) {
    return '$count개 내보냄';
  }

  @override
  String exportFailed(String error) {
    return '내보내기 실패: $error';
  }

  @override
  String importDone(int added, int total) {
    return '가져오기 완료: $added개 추가, 총 $total개';
  }

  @override
  String importFailed(String error) {
    return '가져오기 실패: $error';
  }

  @override
  String get nothingToExport => '내보낼 레코드가 없습니다';

  @override
  String get sectionSearch => '검색 규칙';

  @override
  String get searchExact => '정확히 일치';

  @override
  String get searchContains => '포함 일치';

  @override
  String get searchFuzzy => '유사 검색';

  @override
  String get searchCustom => '사용자 지정';

  @override
  String get searchExactDesc => '\".\"로 분리; 완전히 같은 사이트가 있으면 그것만 표시';

  @override
  String get searchContainsDesc => '\".\"로 분리; 관련 항목을 일치도순으로 모두 표시';

  @override
  String get searchFuzzyDesc => '쿼리 문자열을 포함하는 사이트를 모두 표시';

  @override
  String get searchCustomDesc => '지정한 구분자로 분리한 뒤 검색';

  @override
  String get searchDelimiterLabel => '구분자';

  @override
  String get searchMatchTypeLabel => '일치 방식';

  @override
  String get settings => '설정';

  @override
  String get lock => '잠금';

  @override
  String get tabQuery => '검색';

  @override
  String get tabAdd => '추가';

  @override
  String get tabList => '목록';

  @override
  String get syncIdle => '동기화 안 됨';

  @override
  String get syncWorking => '동기화 중…';

  @override
  String get syncOk => '동기화됨';

  @override
  String get syncOffline => '오프라인';

  @override
  String get syncError => '동기화 실패';

  @override
  String get queryFieldLabel => '사이트(키워드 부분 일치 지원)';

  @override
  String get queryInvalidKey => '마스터 키 오류: 일치하는 사이트는 있으나 복호화할 수 없습니다';

  @override
  String get queryNoMatch => '일치하는 레코드를 찾을 수 없습니다';

  @override
  String get queryPrompt => '사이트를 입력하고 Enter를 눌러 검색하세요';

  @override
  String get edit => '편집';

  @override
  String get delete => '삭제';

  @override
  String get copyUsername => '사용자 이름 복사';

  @override
  String get hide => '숨기기';

  @override
  String get show => '표시';

  @override
  String get copyPassword => '비밀번호 복사';

  @override
  String get usernameCopied => '사용자 이름이 복사되었습니다';

  @override
  String get passwordCopied => '비밀번호가 복사되었습니다';

  @override
  String get confirmDelete => '삭제 확인';

  @override
  String deleteBody(String website) {
    return '$website의 이 레코드를 삭제하시겠습니까?';
  }

  @override
  String get cancel => '취소';

  @override
  String get confirm => '확인';

  @override
  String get deleted => '삭제됨';

  @override
  String get generatePassword => '비밀번호 생성';

  @override
  String get length => '길이';

  @override
  String get generate => '생성';

  @override
  String get charUpper => '대문자';

  @override
  String get charLower => '소문자';

  @override
  String get charDigits => '숫자';

  @override
  String get charSpecial => '특수문자';

  @override
  String get saveToVault => '보관함에 저장';

  @override
  String get websiteRequired => '사이트 *';

  @override
  String get usernameOptional => '사용자 이름(선택)';

  @override
  String get passwordRequired => '비밀번호 *';

  @override
  String get save => '저장';

  @override
  String get websitePasswordEmpty => '사이트와 비밀번호는 비워 둘 수 없습니다';

  @override
  String get saved => '저장됨';

  @override
  String get duplicateEntry => '동일한 항목이 이미 존재합니다';

  @override
  String get emptyVault => '보관함이 비어 있습니다. ‘추가’에서 첫 항목을 등록하세요';

  @override
  String totalCount(int count) {
    return '총 $count개';
  }

  @override
  String get sortNameAsc => '이름 A→Z';

  @override
  String get sortNameDesc => '이름 Z→A';

  @override
  String get sortTimeDesc => '수정 시간(최신순)';

  @override
  String get sortTimeAsc => '수정 시간(오래된순)';

  @override
  String get sortTooltip => '정렬';

  @override
  String get decryptFailedCopy => '현재 마스터 키로 복호화할 수 없어 복사에 실패했습니다';

  @override
  String get noUsername => '(사용자 이름 없음)';

  @override
  String get cannotDecrypt => '복호화할 수 없음';

  @override
  String get cannotDecryptBody =>
      '이 레코드는 현재 마스터 키로 복호화할 수 없습니다.\n왼쪽 상단의 뒤로를 눌러 올바른 마스터 키를 다시 입력하세요.';

  @override
  String get website => '사이트';

  @override
  String get username => '사용자 이름';

  @override
  String get password => '비밀번호';

  @override
  String get updated => '업데이트됨';

  @override
  String get sectionLanguage => '언어';

  @override
  String get language => '언어';

  @override
  String get followSystem => '시스템 설정 따름';

  @override
  String get sectionCloudSync => '클라우드 동기화';

  @override
  String get enableCloudSync => '클라우드 동기화 사용';

  @override
  String get enableCloudSyncSub => '끄면 모든 데이터가 이 기기에만 보관됩니다';

  @override
  String get sectionSyncPrompt => '동기화 확인';

  @override
  String get promptBeforePull => '작업 전 풀 확인';

  @override
  String get promptBeforePullSub => '추가/편집/삭제 전에 ‘원격에서 풀’ 확인을 표시';

  @override
  String get promptAfterPush => '작업 후 푸시 확인';

  @override
  String get smartSkip => '스마트 건너뛰기';

  @override
  String get smartSkipSub => '원격에 업데이트가 없으면 ‘풀’ 확인을 자동으로 건너뜁니다';

  @override
  String get sectionMaintenance => '유지 관리';

  @override
  String get compactNow => '지금 로그 정리';

  @override
  String get sectionAbout => '정보';

  @override
  String get aboutSubtitle =>
      'GitHub: muzi-xiaoren · https://github.com/muzi-xiaoren/PassPro';

  @override
  String get aboutVersionLabel => '버전';

  @override
  String get aboutAuthorLabel => '작성자';

  @override
  String get aboutRepoLabel => '저장소';

  @override
  String compactDone(int count, String size) {
    return '정리 완료: 유효 레코드 $count개, $size 절약';
  }

  @override
  String compactionStatus(int active, int total, String amp) {
    return '현재 유효 $active개 / $total행(증폭률 $amp×)';
  }

  @override
  String get backendDisabled => '사용 안 함';

  @override
  String get enable => '사용';

  @override
  String get roleLabel => '역할:';

  @override
  String get repoName => '저장소 이름';

  @override
  String get branch => '브랜치';

  @override
  String get filePath => '파일 경로';

  @override
  String get patHelper => 'OS 키체인에 저장되며 어떤 파일에도 기록되지 않습니다';

  @override
  String syncAllBackendsPullFailed(String detail) {
    return '모든 백엔드에서 가져오기 실패: $detail';
  }

  @override
  String syncPulledFrom(String backend) {
    return '$backend에서 가져왔습니다';
  }

  @override
  String get syncNoPrimary => '사용 가능한 기본 백엔드가 설정되지 않았습니다';

  @override
  String syncPrimaryOffline(String detail) {
    return '기본 백엔드 오프라인: $detail';
  }

  @override
  String syncPrimaryPushFailed(String detail) {
    return '기본 백엔드 푸시 실패: $detail';
  }

  @override
  String get syncPushConflictManual => '푸시 충돌 및 자동 병합 실패 — 수동으로 동기화하세요';

  @override
  String get syncPushedPrimary => '기본 백엔드에 푸시했습니다';

  @override
  String get syncRemoteEmptySkipped => '원격이 비어 있어 덮어쓰기를 건너뛰었습니다(로컬 삭제 방지)';

  @override
  String syncOverwroteLocalFrom(String backend) {
    return '$backend에서 로컬을 덮어썼습니다';
  }

  @override
  String syncPrimaryOverwriteFailed(String detail) {
    return '기본 백엔드 덮어쓰기 실패: $detail';
  }

  @override
  String get syncOverwriteRemoteStillChanging =>
      '덮어쓰기 실패: 원격이 계속 변경됨, 다시 시도하세요';

  @override
  String get syncOverwroteRemoteWithLocal => '로컬로 원격을 덮어썼습니다';

  @override
  String syncGenericError(String detail) {
    return '오류: $detail';
  }

  @override
  String get syncMirrorsLabel => '미러';

  @override
  String get syncMirrorOk => '성공';

  @override
  String get syncMirrorConflict => '충돌';

  @override
  String get syncMirrorFailed => '실패';

  @override
  String syncPrimaryResult(String backend, String outcome) {
    return '기본 $backend ($outcome)';
  }

  @override
  String repoNotFoundOrNoAccess(String repo) {
    return '저장소를 찾을 수 없거나 토큰에 접근 권한이 없습니다: $repo';
  }

  @override
  String get webdavFolderMissing =>
      '대상 폴더가 없습니다. 먼저 WebDAV/Nutstore에서 폴더를 만들고 원격 파일 경로를 일치시키세요(예: /PassPro/passwords.log).';

  @override
  String get owner => '소유자';

  @override
  String get personalAccessToken => '개인 액세스 토큰';

  @override
  String get webdavAccount => '계정';

  @override
  String get webdavServer => '서버 주소';

  @override
  String get webdavRemotePath => '원격 파일 경로';

  @override
  String get webdavAppPassword => '앱 비밀번호';

  @override
  String get webdavAppPasswordHelper => 'Nutstore: 타사 앱 관리에서 생성한 앱 비밀번호를 입력하세요';

  @override
  String get rolePrimary => '기본';

  @override
  String get roleMirror => '미러';

  @override
  String get testOkNoFile => '연결 성공(원격 파일이 아직 없습니다. 첫 푸시 시 생성됩니다)';

  @override
  String testOkSha(String sha) {
    return '연결 성공(현재 sha=$sha…)';
  }

  @override
  String testFailHttp(String code, String message) {
    return '실패: HTTP $code $message';
  }

  @override
  String testFail(String error) {
    return '실패: $error';
  }

  @override
  String get testConnection => '연결 테스트';

  @override
  String get pullTitle => '먼저 원격에서 풀할까요?';

  @override
  String get pullMessage => '원격에 업데이트가 있을 수 있습니다. 계속하기 전에 풀하시겠습니까?';

  @override
  String get pull => '풀';

  @override
  String get skip => '건너뛰기';

  @override
  String get pushTitle => '로컬에 저장됨';

  @override
  String get pushMessage => '원격으로 푸시할까요?';

  @override
  String get push => '푸시';

  @override
  String get later => '나중에';

  @override
  String get dontPromptThisSession => '이번 세션에서는 다시 표시 안 함';

  @override
  String get syncMenu => '동기화';

  @override
  String get syncPull => '풀 후 병합';

  @override
  String get syncPush => '현재 데이터 푸시';

  @override
  String get syncOverwriteLocal => '클라우드로 로컬 덮어쓰기';

  @override
  String get syncOverwriteRemote => '로컬로 클라우드 덮어쓰기';

  @override
  String syncOverwriteLocalConfirm(String file) {
    return '클라우드의 $file(으)로 로컬 데이터를 덮어씁니다. 푸시하지 않은 로컬 변경 사항은 사라집니다. 계속하시겠습니까?';
  }

  @override
  String syncOverwriteRemoteConfirm(String file) {
    return '로컬 데이터로 클라우드의 $file을(를) 덮어씁니다. 현재 클라우드 내용이 대체됩니다. 계속하시겠습니까?';
  }

  @override
  String get continueLabel => '계속';

  @override
  String get overwroteLocal => '클라우드로 로컬을 덮어썼습니다';

  @override
  String get overwroteRemote => '로컬로 클라우드를 덮어썼습니다';

  @override
  String get accountMenu => '계정';

  @override
  String get changeMasterKey => '마스터 키 변경';

  @override
  String get newMasterKey => '새 마스터 키';

  @override
  String get confirmNewMasterKey => '새 마스터 키 확인';

  @override
  String get masterKeyMismatch => '두 마스터 키가 일치하지 않습니다';

  @override
  String get masterKeyChanged => '마스터 키를 변경했습니다';

  @override
  String get changeMasterKeyHint =>
      '현재 세션에서 사용하는 마스터 키를 교체합니다. 이후의 암호화/복호화에만 영향을 주며 기존 항목은 변경되지 않습니다.';

  @override
  String get autoSyncOnLaunch => '실행 시 자동 동기화';

  @override
  String get autoSyncOnLaunchSub => '앱을 열 때마다 원격에서 가져와 병합합니다';

  @override
  String get sectionBackground => '배경 이미지';

  @override
  String get bgChooseImage => '이미지 선택';

  @override
  String get bgImageSet => '설정됨 — 눌러서 변경';

  @override
  String get bgNoImage => '배경 이미지 없음';

  @override
  String get bgClearImage => '이미지 제거';

  @override
  String get bgOpacity => '불투명도';

  @override
  String get bgBlur => '흐림';

  @override
  String get bgFit => '크기';

  @override
  String get bgFitCover => '채우기';

  @override
  String get bgFitContain => '맞춤';

  @override
  String get bgFitFill => '늘이기';

  @override
  String get bgFitWidth => '너비 맞춤';

  @override
  String listModifiedAt(String time) {
    return '수정 $time';
  }

  @override
  String get mirrorSyncDone => '미러 동기화 완료';

  @override
  String get sortCopyCountDesc => '자주 사용순';

  @override
  String get sortRelevance => '관련도';
}
