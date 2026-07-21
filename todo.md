# 그사이에 — 병렬 작업 타임라인 리디자인 todo

정체성: **"음식 하나 = 병렬로 겹쳐 돌아가는 작업들의 타임라인"**
(면 삶기 ‖ 소스 만들기가 특정 구간에서 동시에 진행됨)

## 완료
- [x] 레시피 리서치 (알리오 올리오, 토마토 크림 파스타) — 실제 조리 순서를 초 단위 타임라인으로
- [x] Models.swift — Recipe / RecipeStep(startAt·duration·lane·attention) / StepStatus
- [x] Recipes.swift — 파스타 2종 레시피 DB (출처 명시)
- [x] CookSession.swift — 시작시각 하나로 파생되는 병렬 엔진 + 작업별 시작/완료 알림
- [x] RecipeListView.swift — 홈: 레시피 카드(미니 간트 미리보기) → 탭해서 시작
- [x] CookView.swift — 병렬 간트 타임라인 + '지금 할 일' 카드 + 체크리스트 + 움직이는 '지금' 선
- [x] GeusaieApp.swift / pbxproj / 파일 rename
- [x] 빌드 확인 (BUILD SUCCEEDED)

## 다음 후보
- [ ] 파스타 외 레시피 추가 (김치볶음밥·된장찌개 등 병렬 구조 있는 것)
- [ ] 사용자 레시피 직접 만들기(작업 추가·시간 조절)
- [ ] 레인 색·attention 아이콘 튜닝, 간트 가로 스크롤(긴 레시피)
- [ ] 라이브 액티비티(잠금화면 병렬 레인)
- [ ] 여러 요리 동시 진행(파스타 + 사이드) 지원 여부 결정
