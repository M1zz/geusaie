import Foundation
import LeeoKit

// MARK: - 원격 킬스위치
//
// 심사 없이 문제 기능을 끄는 장치. FeedbackHub 의 RemoteFlags 레코드
// (recordName `flags_com.leeo.geusaie`)에 필드를 Int64 로 두고 0 이면 꺼진다.
// 조회에 실패하거나 필드가 없으면 켜진 채로 동작한다 — 킬스위치가 장애 원인이 되면 안 된다.
//
// ⚠️ rawValue 가 CloudKit 필드명이다. 바꾸면 대시보드에서 꺼도 앱은 켠 채로 돈다.

enum GeusaieFlag: String, LeeoRemoteFlag, CaseIterable {
    /// "다음" 음성 넘기기 — 마이크·음성 인식을 쓰는 유일한 기능.
    /// 특정 iOS 에서 오디오 세션이 꼬이거나 심사 문제가 생기면 이것만 끄고
    /// 버튼으로 넘기는 기본 흐름은 그대로 둔다.
    case voiceCue
}
