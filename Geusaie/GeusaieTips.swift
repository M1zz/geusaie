import SwiftUI
import TipKit

// MARK: - 사용 팁 (TipKit)
//
// 처음 쓰는 사람이 놓치기 쉬운 것 두 가지만. 한 번 써 보면 다시 뜨지 않는다.

/// 마이크 버튼 — 손이 젖어 있을 때 말로 넘길 수 있다는 걸 모르고 지나가기 쉽다
struct VoiceNextTip: Tip {
    var title: Text { Text("말로 넘기기") }
    var message: Text? { Text("손이 젖었으면 \"다음\"이라고 말해 보세요. 화면을 만지지 않아도 다음 일로 넘어가요.") }
    var image: Image? { Image(systemName: "mic.fill") }
}

/// 글자 크기 — 조리대에 세워 두고 떨어져서 보는 앱이라 글자를 키울 일이 많다
struct TextSizeTip: Tip {
    var title: Text { Text("멀리서도 잘 보이게") }
    var message: Text? { Text("조리대에 세워 두고 보신다면 여기서 글자를 더 키울 수 있어요.") }
    var image: Image? { Image(systemName: "textformat.size") }
}
