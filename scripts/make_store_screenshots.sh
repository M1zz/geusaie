#!/bin/sh
# 언어마다 스토어 스크린샷을 찍는다 — 앱이 스스로 그 장면을 띄우는 디버그 인자(-demoRecipe …)를 쓴다.
#
# 사용법:
#   scripts/make_store_screenshots.sh iphone <시뮬레이터 UDID> <언어 ...>   (아이폰 6.9" — 1320x2868 원본)
#   scripts/make_store_screenshots.sh ipad   <시뮬레이터 UDID> <언어 ...>   (아이패드 13" — 2064x2752 원본)
#
# 미리: Debug 빌드를 그 시뮬레이터에 설치하고(데모 인자는 DEBUG 전용),
#       xcrun simctl status_bar <UDID> override --time 9:41 --batteryState charged --batteryLevel 100
#
# 결과: docs/screenshots/marketing/<언어>/0N-….png (아이폰 1242x2688) · ipad-0N-….png (2064x2752)
#       원본은 RAW(기본 /tmp/geusaie-raw)/<언어>/ 에 남는다 — 레포에 넣지 않는다.
#
# ⚠️ 데모 인자 -demoTextScale 은 앱 설정에 저장된다. 장마다 꼭 다시 준다(안 주면 앞 장의 글자 크기가 남는다).
# ⚠️ 언어는 -AppleLanguages / -AppleLocale 로 바꾼다. 시뮬레이터를 언어마다 지우거나 다시 켜지 않는다.
set -e
KIND=$1; U=$2; shift 2
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RAW=${RAW:-/tmp/geusaie-raw}

locale_of() {
  case $1 in
    en) echo en_US;; en-GB) echo en_GB;; zh-Hans) echo zh_CN;; zh-Hant) echo zh_TW;; pt-BR) echo pt_BR;;
    ja) echo ja_JP;; ko) echo ko_KR;; cs) echo cs_CZ;; da) echo da_DK;; el) echo el_GR;; nb) echo nb_NO;;
    sv) echo sv_SE;; vi) echo vi_VN;; *) echo "$1_$(echo "$1" | tr a-z A-Z)";;
  esac
}

cap() {  # cap <언어> <파일> <인자...>
  L=$1; OUT=$2; shift 2
  xcrun simctl terminate "$U" com.leeo.geusaie >/dev/null 2>&1 || true
  perl -e 'alarm 60; exec @ARGV' xcrun simctl launch "$U" com.leeo.geusaie \
    -AppleLanguages "($L)" -AppleLocale "$(locale_of "$L")" "$@" >/dev/null
  sleep "${WAIT:-4}"
  perl -e 'alarm 120; exec @ARGV' xcrun simctl io "$U" screenshot "$OUT" >/dev/null 2>&1
}

for L in "$@"; do
  R="$RAW/$KIND/$L"; M="$ROOT/docs/screenshots/marketing/$L"
  mkdir -p "$R" "$M"
  if [ "$KIND" = iphone ]; then
    cap "$L" "$R/01-home.png"     -demoRecipe none       -demoTextScale 1
    cap "$L" "$R/02-start.png"    -demoRecipe aglio-olio -demoTextScale 1
    cap "$L" "$R/03-prep.png"     -demoRecipe aglio-olio -demoAt 106 -demoTextScale 1
    cap "$L" "$R/04-deadline.png" -demoRecipe aglio-olio -demoAt 476 -demoTextScale 1
    cap "$L" "$R/05-bigtext.png"  -demoRecipe aglio-olio -demoAt 106 -demoTextScale 3
    for f in "$R"/0*.png; do
      ffmpeg -loglevel error -y -i "$f" -vf "scale=1242:2699,crop=1242:2688" "$M/$(basename "$f")"
    done
  else
    # 아이패드 상태 막대의 날짜는 SpringBoard 가 시스템 언어로 그린다 — 앱 인자로는 안 바뀐다.
    # 그래서 시스템 언어만 바꾸고 SpringBoard 를 다시 띄운다(시뮬레이터를 끄거나 지우지 않는다).
    # 가로 화면(-demoLandscape)은 창 없는 시뮬레이터에서 돌지 않아 세로 네 장으로 찍는다.
    xcrun simctl spawn "$U" defaults write -g AppleLanguages -array "$L"
    xcrun simctl spawn "$U" defaults write -g AppleLocale "$(locale_of "$L")"
    xcrun simctl spawn "$U" launchctl kickstart -k system/com.apple.SpringBoard >/dev/null 2>&1 || true
    sleep 10
    cap "$L" "$R/01-home.png"    -demoRecipe none       -demoTextScale 1
    cap "$L" "$R/02-cook.png"    -demoRecipe aglio-olio -demoAt 477 -demoTextScale 1
    cap "$L" "$R/03-start.png"   -demoRecipe aglio-olio -demoTextScale 1
    cap "$L" "$R/04-bigtext.png" -demoRecipe aglio-olio -demoAt 106 -demoTextScale 3
    for f in "$R"/0*.png; do cp "$f" "$M/ipad-$(basename "$f")"; done
  fi
  echo "done $KIND $L"
done
