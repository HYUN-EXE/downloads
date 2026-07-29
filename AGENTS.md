# downloads 저장소 작업 규칙

## 향후 신규 프로그램

- 새 프로그램을 다운로드 페이지에 추가하기 전에, 그 프로그램이 설치 프로그램(Inno Setup)과 자동 업데이트를 갖췄는지 확인한다.
- 아직 없다면 `HYUN-EXE/AppInstallerTemplate` 저장소(재사용 가능한 설치 프로그램 + 자동 업데이트 스캐폴드)를 먼저 참고해 적용할지 검토한다.
- 설계 배경: `AppInstallerTemplate` 저장소의 `docs/superpowers/specs/2026-07-29-installer-autoupdate-standard-design.md` 참고.

## 카드 추가 시 확인 사항

- 다운로드 버튼 href는 자동 업데이트 전송용 zip이 아니라 사용자가 최초 설치에 쓰는 파일(설치 프로그램이 있다면 `_Setup.exe`, 없다면 `_Setup.zip`)을 가리켜야 한다.
- 버튼 텍스트가 실제 파일 형식(EXE/ZIP)과 맞는지 확인한다.
- 다른 프로그램 카드나 디자인은 요청받지 않은 한 함께 수정하지 않는다.
