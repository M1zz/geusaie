#!/usr/bin/env python3
"""App Store 크리에이티브 자산(제품 페이지 헤더 · 검색 결과) 생성: HTML → 헤드리스 Chrome.

사용법: python3 scripts/make_creative_assets.py [언어 ...]     (없으면 전부)

자리
  docs/screenshots/creative/<스토어 로케일>/header.png   3840x1646  제품 페이지 맨 위
  docs/screenshots/creative/<스토어 로케일>/search.png   3840x2560  검색 결과 (없으면 스크린샷이 대신 보인다)

⚠️ 안전 영역 밖은 기기에 따라 잘린다. 글은 **반드시** 안전 영역 안에 둔다(배경 · 기기 그림은 넘쳐도 된다).
   수치는 Apple 공식 PSD 템플릿에서 잰 값이다(https://developer.apple.com/app-store/asset-best-practices/).
   아이폰에서 헤더는 가운데만 남고, 검색 결과는 약 385pt 폭으로 줄어 보인다. 그래서 글이 크다.

⚠️ 가격 · 할인 · 주소(URL) · 수상 · 다른 플랫폼 이름은 넣지 않는다(Apple 가이드).
"""
import os, signal, subprocess, sys, pathlib, tempfile, time

ROOT = pathlib.Path(__file__).resolve().parent.parent
# 기기 화면 재료: 레포의 아이패드 원본 캡처(이 앱은 아이패드 앱이다 — 기기 그림도 아이패드).
SHOTS = ROOT / "docs" / "screenshots"
OUT = ROOT / "docs" / "screenshots" / "creative"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# 스토어에 있는 언어는 한국어(ko) 하나다(DeployBar --storetext 그사이에).
STORE = {}

# (가로, 세로, 안전 영역 left, top, right, bottom)
SPEC = {
    "header": (3840, 1646, (1097, 493, 2743, 1154)),
    "search": (3840, 2560, (836, 765, 3004, 1795)),
}

# 검색 결과: 조리 화면 한 장으로 "냄비 두 개를 같이 돌려도 놓치지 않는다"를 보인다.
# 눈썹글은 검색창에 칠 말(스토어 키워드: 요리타이머).
SEARCH = {
    "ko": ("요리 타이머", "냄비 두 개도<br>놓치지 않게", "지금 할 일과 냄비마다 남은 시간을 한눈에"),
}

# 헤더는 한 가지 약속: 면 삶는 그사이에 소스까지(앱의 부제 문장).
HEADER = {
    "ko": ("요리 타이머", "면 삶는 그사이에<br>소스까지"),
}

# ⚠️ 바탕 · 글자색은 앱 팔레트(Geusaie/Theme.swift)와 같다: cream · ink · terracotta.
BASE_CSS = """
* { margin:0; padding:0; box-sizing:border-box; }
html,body { width:%(W)dpx; height:%(H)dpx; overflow:hidden; }
body { background:#FAF6ED; position:relative; -webkit-font-smoothing:antialiased;
  font-family:-apple-system, "SF Pro Display", "Apple SD Gothic Neo", sans-serif; }
.glow { position:absolute; border-radius:50%%; filter:blur(170px); pointer-events:none; }
.text { position:absolute; display:flex; flex-direction:column; justify-content:center; }
.eyebrow { font-weight:700; color:#C75B39; letter-spacing:-0.01em; line-height:1.15; }
.headline { font-weight:800; color:#2D2A24; letter-spacing:-0.02em; line-height:1.2; text-wrap:balance; }
.sub { font-weight:500; color:#8A8271; letter-spacing:-0.01em; line-height:1.4; text-wrap:balance; }
:lang(ko) .headline, :lang(ko) .sub, :lang(ko) .eyebrow { word-break:keep-all; }
.ipad { position:absolute; background:#1c1b19; box-shadow:0 60px 160px rgba(45,42,36,.28), 0 0 0 3px #3b3934 inset; }
.ipad img { display:block; width:100%%; }
.dot { position:absolute; border-radius:50%%; }
"""

# 글이 상자를 넘지 않을 때까지 줄인다. 잘리는 글은 없다 - 끝까지 안 맞으면 표시하고 멈춘다.
FIT_JS = """
<script>
// 문구에 적은 줄(<br>)보다 더 쪼개지면 "Rispondi / con un / tocco" 처럼 읽기가 끊긴다.
// 적은 줄 수를 지킬 때까지 줄인다.
function lines(el) {
  return Math.round(el.getBoundingClientRect().height / parseFloat(getComputedStyle(el).lineHeight));
}
function fit(box, el, max, min) {
  const want = el.querySelectorAll('br').length + 1;
  let size = max;
  el.style.fontSize = size + 'px';
  while (size > min && (box.scrollHeight > box.clientHeight + 1 || box.scrollWidth > box.clientWidth + 1 ||
         lines(el) > want)) {
    size -= 4; el.style.fontSize = size + 'px';
  }
  if (box.scrollHeight > box.clientHeight + 1 || box.scrollWidth > box.clientWidth + 1 || lines(el) > want)
    document.body.dataset.overflow = '1';
}
document.fonts.ready.then(() => {
  const box = document.querySelector('.text');
  const h = document.querySelector('.headline');
  fit(box, h, +h.dataset.max, +h.dataset.min);
  document.body.dataset.done = '1';
});
</script>
"""


TMP = pathlib.Path(tempfile.gettempdir()) / "geusaie-creative"
# ⚠️ 프로필을 따로 쓴다. 기본 프로필을 다른 Chrome 과 같이 쓰면 잠금에 걸려 멈춘다.
PROFILE = TMP / "chrome-profile"


def ipad(img, left, top, width, rotate=0):
    """아이패드 모양: 얇고 고른 테두리, 둥근 모서리(화면 비율은 캡처 그대로)."""
    pad = round(width * 0.028)
    return (f'<div class="ipad" style="left:{left}px;top:{top}px;width:{width}px;padding:{pad}px;'
            f'border-radius:{round(width * 0.06)}px;transform:rotate({rotate}deg)">'
            f'<img src="{img}" style="border-radius:{round(width * 0.036)}px"></div>')


def dots(spec):
    # 냄비 색(면냄비 머스터드 · 소스팬 초록 · 내 손 테라코타)으로 둥근 점을 흩는다. 안전 영역 밖 장식.
    colors = ["#D99A3C", "#5B8C5A", "#C75B39"]
    return "".join(f'<div class="dot" style="left:{x}px;top:{y}px;width:{w}px;height:{w}px;'
                   f'background:{colors[c]};opacity:{o}"></div>' for x, y, w, c, o in spec)


def search_html(lang):
    W, H, (l, t, r, b) = SPEC["search"]
    eyebrow, headline, sub = SEARCH[lang]
    sw, sh = r - l, b - t
    col = int(sw * 0.54)
    img = (SHOTS / "raw-ipad" / "02-cook-portrait.png").as_uri()
    pw = 1300
    left = l + col + 60
    return f"""
<div class="glow" style="left:{left - 200}px;top:500px;width:1800px;height:1800px;background:rgba(217,154,60,.22)"></div>
<div class="glow" style="left:{l - 700}px;top:{t - 400}px;width:1500px;height:1100px;background:rgba(199,91,57,.10)"></div>
{dots([(3500, 260, 120, 0, .9), (3620, 470, 70, 1, .9), (330, 2120, 110, 2, .85), (560, 2330, 70, 0, .85)])}
{ipad(img, left, t - 330, pw, 0)}
<div class="text" style="left:{l}px;top:{t}px;width:{col}px;height:{sh}px">
  <div class="eyebrow" style="font-size:96px">{eyebrow}</div>
  <div class="headline" data-max="230" data-min="130" style="margin-top:40px">{headline}</div>
  <div class="sub" style="font-size:80px;margin-top:56px">{sub}</div>
</div>"""


def header_html(lang):
    W, H, (l, t, r, b) = SPEC["header"]
    eyebrow, headline = HEADER[lang]
    sw, sh = r - l, b - t
    land = (SHOTS / "marketing-ipad" / "03-cook-landscape.png").as_uri()
    port = (SHOTS / "raw-ipad" / "02-cook-portrait.png").as_uri()
    return f"""
<div class="glow" style="left:{l - 200}px;top:{t - 400}px;width:{sw + 400}px;height:{sh + 800}px;background:rgba(217,154,60,.16)"></div>
{dots([(140, 110, 110, 0, .9), (380, 60, 64, 1, .9), (3560, 120, 120, 1, .9), (3400, 300, 64, 2, .85),
       (3680, 1380, 90, 0, .85), (70, 1420, 80, 2, .85)])}
{ipad(land, -120, 560, 1160, -6)}
{ipad(port, 2930, 330, 800, 7)}
<div class="text" style="left:{l}px;top:{t}px;width:{sw}px;height:{sh}px;align-items:center;text-align:center">
  <div class="eyebrow" style="font-size:80px">{eyebrow}</div>
  <div class="headline" data-max="200" data-min="110" style="margin-top:26px">{headline}</div>
</div>"""


def html_lang(lang):
    return lang


def chrome(args, log, done, timeout=300):
    """헤드리스 Chrome 을 띄우고 done() 이 참이 되면 끈다.
    ⚠️ 이 맥에서는 Chrome 이 일을 다 하고도 끝나지 않고 매달려 있는 일이 있다(업데이터 자식 프로세스).
       그래서 끝나기를 기다리지 않고 결과(DOM 출력·PNG 파일)가 나오면 프로세스 묶음을 통째로 끈다."""
    TMP.mkdir(exist_ok=True)
    with open(log, "w") as out:
        proc = subprocess.Popen([CHROME, "--headless=new", f"--user-data-dir={PROFILE}", "--no-first-run",
                                 "--disable-component-update", *args],
                                stdout=out, stderr=subprocess.DEVNULL, start_new_session=True)
        ok = False
        end = time.time() + timeout
        while time.time() < end:
            time.sleep(1)
            if done():
                ok = True
                break
            if proc.poll() is not None:
                ok = done()
                break
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except OSError:
            proc.kill()
        # 이 프로필을 쓰는 남은 Chrome 프로세스(렌더러 등)도 끈다
        subprocess.run(["pkill", "-9", "-f", f"--user-data-dir={PROFILE}"], capture_output=True)
        proc.wait()
    return ok


def render(lang, kind):
    W, H, _ = SPEC[kind]
    body = search_html(lang) if kind == "search" else header_html(lang)
    page = (f'<!doctype html><html lang="{html_lang(lang)}"><head><meta charset="utf-8"><style>'
            f'{BASE_CSS % {"W": W, "H": H}}</style></head><body>{body}{FIT_JS}</body></html>')
    html_path = pathlib.Path(tempfile.gettempdir()) / f"geusaie-creative-{lang}-{kind}.html"
    html_path.write_text(page, encoding="utf-8")
    # 글이 끝까지 안 맞으면 그림을 만들지 않는다(잘린 글이 스토어에 올라가는 것보다 낫다).
    flags = [f"--window-size={W},{H}", "--force-device-scale-factor=1", "--disable-gpu",
             "--virtual-time-budget=3000", "--allow-file-access-from-files"]
    dom_txt = TMP / f"{lang}-{kind}.dom"
    chrome(["--dump-dom", *flags, html_path.as_uri()], dom_txt,
           lambda: "</html>" in dom_txt.read_text(errors="ignore"))
    dom = dom_txt.read_text(errors="ignore")
    if 'data-done="1"' not in dom:
        raise SystemExit(f"글 맞추기가 끝나지 않았다: {lang} {kind}")
    if 'data-overflow="1"' in dom:
        raise SystemExit(f"글이 안전 영역을 넘는다: {lang} {kind} - 문구를 줄일 것")
    out_dir = OUT / STORE.get(lang, lang)
    out_dir.mkdir(parents=True, exist_ok=True)
    out_png = out_dir / f"{kind}.png"
    out_png.unlink(missing_ok=True)
    sizes = []

    def written():
        sizes.append(out_png.stat().st_size if out_png.exists() else 0)
        return len(sizes) > 2 and sizes[-1] > 0 and sizes[-1] == sizes[-2] == sizes[-3]
    if not chrome([f"--screenshot={out_png}", "--hide-scrollbars", *flags, html_path.as_uri()],
                  TMP / f"{lang}-{kind}.log", written):
        raise SystemExit(f"Chrome 이 그리지 못했다: {out_png}")
    print(f"rendered {out_png}")


if __name__ == "__main__":
    langs = sys.argv[1:] or list(SEARCH)
    for lang in langs:
        if lang not in SEARCH:
            raise SystemExit(f"모르는 언어: {lang} (아는 것: {', '.join(SEARCH)})")
        for kind in ("header", "search"):
            render(lang, kind)
