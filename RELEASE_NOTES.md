# 그사이에 릴리즈 노트

## 1.0

### 앱스토어 (한국어)

면 삶는 그사이에 소스까지 끝내는 요리 타이머입니다.
지금 할 일 하나만 크게 보여 줍니다.
냄비마다 남은 시간을 따로 보여 줍니다.
손이 젖어 있으면 다음이라고 말해서 넘기세요.
세워 두고 볼 수 있게 글자를 키울 수 있습니다.

### App Store (English)

A cooking timer for two pots at once.
One task at a time, in large type.
Each pot keeps its own countdown.
Say next to move on, hands free.
Text scales up so you can stand back.

### 개발 메모 (내부, 스토어에 올리지 않음)

- 일정은 절대 시각이 아니라 의존 관계로 계산한다(Plan). 불을 늦게 켜면 뒤가 함께 밀린다.
- 일은 세 종류: 도마 일(prep, 밀려도 됨) / 내 동작(action, deadline이면 못 미룸) / 냄비 시간(cook).
- 음성은 SFSpeechRecognizer ko-KR, 가능하면 on-device. 마이크는 조리 화면에서만 켠다.
- 글자 크기는 앱 안에서 4단계(AppStorage "textScale"). 접근성 크기는 배치가 무너져 제외.
- 스크린샷용 디버그 인자: -demoRecipe <id> [-demoAt <초>] [-textScale 0~3] (DEBUG 전용).
