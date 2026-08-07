# Claude 작업 규칙

- 작업을 시작하기 전에 저장소 루트의 `AGENTS.md`를 읽고 모든 규칙을 준수한다.
- 홈페이지의 디자인, 리디자인, UI/UX 검토, 접근성·반응형·성능 감사 또는 시각적 다듬기 작업에는 `.claude/skills/impeccable` 스킬을 자동 적용한다.
- `.claude/skills/impeccable/SKILL.md` 또는 `.agents/skills/impeccable/SKILL.md`가 없으면 작업 전에 저장소 루트에서 `npx --yes impeccable@3.5.0 install --providers=claude,codex --scope=project`를 실행한다.
- 백엔드 전용 작업이나 홈페이지 UI와 무관한 배포 파일 작업에는 Impeccable을 적용하지 않는다.
