# Roblox Max Animations Plugin

3ds Max와 Roblox Studio 사이에서 rig와 animation을 주고받기 위한 오픈소스 플러그인 프로젝트입니다. 목표는 Cautioned의 Blender Animations Plugin 흐름을 유지하되, Blender 애드온 대신 3ds Max용 플러그인을 붙이는 것입니다.

이 프로젝트는 무료 공개 소프트웨어이며 GPL-3.0-or-later로 배포됩니다.

## 현재 상태

초기 포팅 작업용 저장소입니다.

- Studio 플러그인 UI와 기능 흐름은 기존 Blender Animations Plugin을 최대한 유지합니다.
- 3ds Max 쪽은 기존 localhost HTTP API와 호환되는 서버부터 구현합니다.
- 첫 목표는 `Roblox Studio Plugin -> localhost:31337 -> 3ds Max Plugin` 연결을 검증하는 것입니다.

아직 전체 기능이 완성된 릴리스는 아닙니다.

## 목표 기능

- Roblox Studio에서 선택한 rig를 3ds Max로 내보내기
- 3ds Max에서 만든 animation을 Roblox `KeyframeSequence`로 가져오기
- Roblox animation을 3ds Max rig에 다시 적용하기
- 기존 Studio 플러그인의 Player, Rigging, Tools, More 탭 흐름 유지
- Live Sync, weapon/accessory export, marker/event, animation simplifier는 단계적으로 포팅

## 저장소 구조

```text
.
├── max-plugin/
│   ├── start_max_server.py
│   └── src/rbx_max_animations/
│       ├── __init__.py
│       ├── max_scene.py
│       └── server.py
├── studio-plugin/
│   └── README.md
├── docs/
│   ├── protocol.md
│   └── roadmap.md
├── LICENSE
├── NOTICE.md
└── README.md
```

## 3ds Max 플러그인 실행

현재는 개발용 Python 서버 골격입니다. 3ds Max 안에서 실행하는 것을 기준으로 합니다.

1. 이 저장소를 클론합니다.

   ```powershell
   git clone https://github.com/madexperience/max-animation-plugin.git
   cd max-animation-plugin
   ```

2. 3ds Max를 실행합니다.

3. 3ds Max의 Python Listener 또는 Script Editor에서 아래 파일을 실행합니다.

   ```python
   exec(open(r"C:\path\to\max-animation-plugin\max-plugin\start_max_server.py", encoding="utf-8").read())
   ```

4. 콘솔에 서버 시작 메시지가 표시되면 `127.0.0.1:31337`에서 Studio 플러그인의 요청을 받을 준비가 된 상태입니다.

현재 서버는 연결/프로토콜 검증용입니다. 실제 rig export/import와 animation 변환은 이후 단계에서 구현합니다.

## Roblox Studio 플러그인 설치

초기 단계에서는 기존 Studio 플러그인 구조를 유지하고, 연결 대상만 3ds Max 서버로 맞추는 방향입니다.

개발 중 설치 흐름은 다음을 목표로 합니다.

1. `studio-plugin/` 아래에 Rojo 프로젝트를 구성합니다.
2. Studio 플러그인 UI 텍스트를 Blender에서 Max로 변경합니다.
3. localhost 통신 API는 기존 Blender 서버 호환 형식을 유지합니다.
4. Rojo 또는 Roblox Studio의 Local Plugin 저장 기능으로 설치합니다.

정식 설치 방법은 Studio 플러그인 소스가 이 저장소에 정리되는 시점에 업데이트합니다.

## 통신 API

Studio 플러그인은 localhost HTTP 서버와 통신합니다. 1차 Max 포팅은 기존 Blender 서버 API와 호환되도록 구현합니다.

주요 엔드포인트:

- `GET /list_armatures`
- `GET /get_bone_rest/{armature}`
- `GET /export_animation/{armature}`
- `POST /export_animation/{armature}`
- `POST /import_animation`
- `GET /animation_status`

자세한 내용은 [docs/protocol.md](docs/protocol.md)를 참고하세요.

## 개발 원칙

- Studio 플러그인은 가능한 한 작게 수정합니다.
- 기존 API와 JSON 구조를 먼저 호환시킨 뒤, 내부 이름 정리는 나중에 합니다.
- 3ds Max 포팅은 작은 기능 단위로 검증합니다.
- 모바일/PC Studio UI 사용성을 고려해 UI 변경은 scale 중심으로 유지합니다.

## 라이선스와 출처

이 프로젝트는 GPL-3.0-or-later로 공개됩니다.

기반 분석 대상:

- Cautioned/Blender-Animations-Plugin
- Den_S의 Roblox DevForum Blender rig exporter/animation importer

자세한 출처는 [NOTICE.md](NOTICE.md)를 참고하세요.
