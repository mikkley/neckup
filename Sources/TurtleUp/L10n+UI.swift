import Foundation
import TurtleUpCore

/// UI 层文案（岛/引导/设置/菜单栏）。语言解析与游戏文案见 TurtleUpCore/L10n.swift。
extension L10n {

    // MARK: 通用按钮

    public static var done: String {
        switch resolved {
        case .zhHans, .system: "完成"
        case .en: "Done"
        case .ja: "完了"
        case .ko: "완료"
        }
    }
    public static var next: String {
        switch resolved {
        case .zhHans, .system: "下一步"
        case .en: "Next"
        case .ja: "次へ"
        case .ko: "다음"
        }
    }
    public static var back: String {
        switch resolved {
        case .zhHans, .system: "上一步"
        case .en: "Back"
        case .ja: "戻る"
        case .ko: "이전"
        }
    }
    public static var skip: String {
        switch resolved {
        case .zhHans, .system: "跳过"
        case .en: "Skip"
        case .ja: "スキップ"
        case .ko: "건너뛰기"
        }
    }
    public static var cancel: String {
        switch resolved {
        case .zhHans, .system: "取消"
        case .en: "Cancel"
        case .ja: "キャンセル"
        case .ko: "취소"
        }
    }
    public static var start: String {
        switch resolved {
        case .zhHans, .system: "开始"
        case .en: "Start"
        case .ja: "開始"
        case .ko: "시작"
        }
    }
    public static var openSystemSettings: String {
        switch resolved {
        case .zhHans, .system: "打开系统设置"
        case .en: "Open System Settings"
        case .ja: "システム設定を開く"
        case .ko: "시스템 설정 열기"
        }
    }

    // MARK: 新手引导

    public static var welcomeTitle: String {
        switch resolved {
        case .zhHans, .system: "欢迎使用 TurtleUp"
        case .en: "Welcome to TurtleUp"
        case .ja: "TurtleUp へようこそ"
        case .ko: "TurtleUp에 오신 것을 환영합니다"
        }
    }
    public static var welcomeBody: String {
        switch resolved {
        case .zhHans, .system: "脖子曲度变直这件事，自己是感觉不到的。\nTurtleUp 用 AirPods 的传感器实时感知你的低头，\n在该抬头的时候轻轻提醒你。"
        case .en: "You can't feel your neck curve flattening.\nTurtleUp uses your AirPods sensors to notice when you slouch\nand gently reminds you to lift your head."
        case .ja: "首のカーブが失われていても、自分では気づけません。\nTurtleUp は AirPods のセンサーでうつむきを検知し、\nそっと頭を上げるよう促します。"
        case .ko: "목 커브가 펴지는 건 스스로 느끼기 어렵습니다.\nTurtleUp은 AirPods 센서로 숙임을 감지해\n고개를 들도록 부드럽게 알려줍니다."
        }
    }
    public static var welcomeAirpods: String {
        switch resolved {
        case .zhHans, .system: "使用前请准备好 AirPods（Pro / 3 代 / Max / Beats Fit Pro）"
        case .en: "Have your AirPods ready (Pro / 3rd gen / Max / Beats Fit Pro)"
        case .ja: "AirPods（Pro / 第3世代 / Max / Beats Fit Pro）をご用意ください"
        case .ko: "AirPods(Pro / 3세대 / Max / Beats Fit Pro)를 준비하세요"
        }
    }
    public static var permTitle: String {
        switch resolved {
        case .zhHans, .system: "授权「运动与健身」权限"
        case .en: "Allow “Motion & Fitness”"
        case .ja: "「モーションとフィットネス」を許可"
        case .ko: "「모션 및 피트니스」 허용"
        }
    }
    public static var permBody: String {
        switch resolved {
        case .zhHans, .system: "TurtleUp 只读取 AirPods 的头部姿态数据，\n所有记录只保存在本机，绝不上传。"
        case .en: "TurtleUp only reads head-motion data from your AirPods.\nEverything stays on this Mac — nothing is uploaded."
        case .ja: "TurtleUp が読み取るのは AirPods の頭部モーションのみ。\n記録はすべて本機に保存され、送信されません。"
        case .ko: "TurtleUp은 AirPods의 머리 움직임 데이터만 읽습니다.\n모든 기록은 이 Mac에만 저장되며 업로드되지 않습니다."
        }
    }
    public static var permGranted: String {
        switch resolved {
        case .zhHans, .system: "已授权 ✓"
        case .en: "Authorized ✓"
        case .ja: "許可済み ✓"
        case .ko: "허용됨 ✓"
        }
    }
    public static var permDenied: String {
        switch resolved {
        case .zhHans, .system: "权限曾被拒绝，需要在系统设置里手动打开"
        case .en: "Permission was denied — enable it in System Settings"
        case .ja: "権限が拒否されています。システム設定で有効にしてください"
        case .ko: "권한이 거부되었습니다. 시스템 설정에서 켜세요"
        }
    }
    public static var permAuthorize: String {
        switch resolved {
        case .zhHans, .system: "去授权"
        case .en: "Authorize"
        case .ja: "許可する"
        case .ko: "허용하기"
        }
    }
    public static var permNoAirpods: String {
        switch resolved {
        case .zhHans, .system: "还没检测到 AirPods，戴上后自动开始；也可以先跳过"
        case .en: "No AirPods detected yet; starts automatically when worn. You can skip for now."
        case .ja: "AirPods 未検出。装着すると自動で開始します。スキップも可能です"
        case .ko: "AirPods가 감지되지 않았습니다. 착용하면 자동 시작. 건너뛰어도 돼요"
        }
    }
    public static var calTitle: String {
        switch resolved {
        case .zhHans, .system: "校准你的坐姿"
        case .en: "Calibrate your posture"
        case .ja: "姿勢をキャリブレーション"
        case .ko: "자세 보정"
        }
    }
    public static var calInstruction: String {
        switch resolved {
        case .zhHans, .system: "戴上 AirPods，坐直、目视前方，然后点击校准"
        case .en: "Wear AirPods, sit upright, look ahead, then tap calibrate"
        case .ja: "AirPods を装着し、背筋を伸ばして前を向いてからキャリブレーション"
        case .ko: "AirPods를 쓰고 허리를 펴고 정면을 본 뒤 보정을 누르세요"
        }
    }
    public static var calNoAirpods: String {
        switch resolved {
        case .zhHans, .system: "未检测到 AirPods。可以先跳过，之后随时在岛上点「坐直校准」。"
        case .en: "No AirPods detected. You can skip and use “Recalibrate” on the island anytime."
        case .ja: "AirPods 未検出。スキップしてもOK。島の「姿勢リセット」からいつでも再調整できます"
        case .ko: "AirPods가 없습니다. 건너뛰고 아일랜드의 「자세 재보정」을 나중에 사용하세요"
        }
    }
    public static var calDone: String {
        switch resolved {
        case .zhHans, .system: "校准完成！点点头、转转头，小人会跟着你动 🐢"
        case .en: "Calibrated! Nod and turn — the buddy follows you 🐢"
        case .ja: "完了！うなずいたり首を回したりするとマスコットが連動します 🐢"
        case .ko: "완료! 고개를 끄덕이거나 돌리면 캐릭터가 따라 움직여요 🐢"
        }
    }
    public static var calButton: String {
        switch resolved {
        case .zhHans, .system: "我坐直了，校准"
        case .en: "I'm sitting straight — calibrate"
        case .ja: "背筋を伸ばしました"
        case .ko: "바르게 앉았어요"
        }
    }
    public static var obGameTitle: String {
        switch resolved {
        case .zhHans, .system: "休息时，打一局"
        case .en: "Play a round on breaks"
        case .ja: "休憩中に一戦"
        case .ko: "쉬는 시간에 한 판"
        }
    }
    public static var obGameBody: String {
        switch resolved {
        case .zhHans, .system: "番茄钟休息或活动提醒到点时，岛上会开一局 60 秒头控小游戏——\n用点头、转头、侧屈打跑五只「僵硬怪」，顺便把脖子活动开。\n不玩没有任何惩罚，点一下岛就能收掉。"
        case .en: "When a pomodoro break or activity reminder hits, a 60-second head-controlled game opens on the island —\nnod, turn and tilt to chase off five “stiff monsters” while loosening your neck.\nNo penalty for skipping; tap the island to dismiss."
        case .ja: "ポモドーロ休憩やアクティビティ通知のタイミングで、島に 60 秒の首操作ミニゲームが出現。\nうなずき・首回し・側屈で 5 体の「こわばり怪」を倒しながら首をほぐします。\n遊ばなくてもペナルティなし。島をタップで閉じられます。"
        case .ko: "뽀모도로 휴식이나 활동 알림이 오면 아일랜드에 60초 머리 조작 미니게임이 열립니다.\n끄덕임·돌리기·기울이기로 다섯 ‘뻣뻣이 몬스터’를 물리치며 목을 풀어요.\n안해도 불이익 없음. 아일랜드를 탭하면 닫혀요."
        }
    }
    public static var obGameToggle: String {
        switch resolved {
        case .zhHans, .system: "休息段打怪小游戏"
        case .en: "Break-time mini-games"
        case .ja: "休憩ミニゲーム"
        case .ko: "휴식 미니게임"
        }
    }
    public static var obBreakPicker: String {
        switch resolved {
        case .zhHans, .system: "定时活动提醒"
        case .en: "Activity reminder"
        case .ja: "アクティビティ通知"
        case .ko: "활동 알림"
        }
    }
    public static var followPomodoro: String {
        switch resolved {
        case .zhHans, .system: "跟随番茄钟"
        case .en: "Follow pomodoro"
        case .ja: "ポモドーロに従う"
        case .ko: "뽀모도로 따르기"
        }
    }
    public static func everyMinutes(_ n: Int) -> String {
        switch resolved {
        case .zhHans, .system: "每 \(n) 分钟"
        case .en: "Every \(n) min"
        case .ja: "\(n) 分ごと"
        case .ko: "\(n)분마다"
        }
    }
    public static var sensitivityLabel: String {
        switch resolved {
        case .zhHans, .system: "提醒灵敏度"
        case .en: "Sensitivity"
        case .ja: "通知の感度"
        case .ko: "알림 민감도"
        }
    }
    public static var sensStrict: String {
        switch resolved {
        case .zhHans, .system: "严格"
        case .en: "Strict"
        case .ja: "厳しめ"
        case .ko: "엄격"
        }
    }
    public static var sensStandard: String {
        switch resolved {
        case .zhHans, .system: "标准"
        case .en: "Standard"
        case .ja: "標準"
        case .ko: "표준"
        }
    }
    public static var sensRelaxed: String {
        switch resolved {
        case .zhHans, .system: "宽松"
        case .en: "Relaxed"
        case .ja: "ゆるめ"
        case .ko: "느슨"
        }
    }
    public static var obSettingsHint: String {
        switch resolved {
        case .zhHans, .system: "这些以后都能在菜单栏「设置…」里随时修改。"
        case .en: "You can change all of this anytime under “Settings…” in the menu bar."
        case .ja: "これらはメニューバーの「設定…」からいつでも変更できます。"
        case .ko: "이 설정은 메뉴 막대 「설정…」에서 언제든 바꿀 수 있어요."
        }
    }

    // MARK: 方向校准

    public static var dirCalTitle: String {
        switch resolved {
        case .zhHans, .system: "方向校准"
        case .en: "Direction Calibration"
        case .ja: "方向キャリブレーション"
        case .ko: "방향 보정"
        }
    }
    public static var dirCalStep1: String {
        switch resolved {
        case .zhHans, .system: "第 1 步（共 3 步）：坐直、目视前方，\n让小人回到正中"
        case .en: "Step 1 of 3: Sit upright, look ahead,\nlet the buddy center itself"
        case .ja: "ステップ 1/3：背筋を伸ばして前を向き、\nマスコットを中央に戻す"
        case .ko: "1/3단계: 허리를 펴고 정면을 봐서\n캐릭터를 중앙에 맞추세요"
        }
    }
    public static var dirCalStep2: String {
        switch resolved {
        case .zhHans, .system: "第 2 步（共 3 步）：慢慢向「左」转头，像看屏幕左边缘，保持住"
        case .en: "Step 2 of 3: Slowly turn LEFT, as if looking at the screen’s left edge, and hold"
        case .ja: "ステップ 2/3：ゆっくり「左」を向き（画面の左端を見る感じ）、キープ"
        case .ko: "2/3단계: 천천히 「왼쪽」으로 돌려(화면 왼쪽 끝을 보듯) 유지하세요"
        }
    }
    public static var dirCalStep3: String {
        switch resolved {
        case .zhHans, .system: "第 3 步（共 3 步）：向「左」侧倾，左耳找左肩，保持住"
        case .en: "Step 3 of 3: Tilt LEFT, left ear toward left shoulder, and hold"
        case .ja: "ステップ 3/3：「左」に傾け（左耳を左肩に）、キープ"
        case .ko: "3/3단계: 「왼쪽」으로 기울여(왼쪽 귀가 왼쪽 어깨로) 유지하세요"
        }
    }
    public static var dirCalDone: String {
        switch resolved {
        case .zhHans, .system: "完成！动一动试试——小人现在应该和你同向了 🐢"
        case .en: "Done! Move around — the buddy should mirror you now 🐢"
        case .ja: "完了！動いてみて——マスコットが同じ向きになったはず 🐢"
        case .ko: "완료! 움직여 보세요. 캐릭터가 같은 방향이어야 해요 🐢"
        }
    }
    public static var dirCalStart: String {
        switch resolved {
        case .zhHans, .system: "我坐直了，开始"
        case .en: "I’m upright, start"
        case .ja: "背筋を伸ばしました"
        case .ko: "바르게 앉았어요"
        }
    }
    public static var dirCalRecenter: String {
        switch resolved {
        case .zhHans, .system: "请先回正坐直，再开始做动作"
        case .en: "Return to center first, then start the move"
        case .ja: "まず中央に戻ってから動作を開始"
        case .ko: "먼저 중앙으로 돌아온 뒤 동작을 시작하세요"
        }
    }
    public static var dirCalDetected: String {
        switch resolved {
        case .zhHans, .system: "识别到动作后，小人会立刻转向同侧"
        case .en: "Once detected, the buddy turns the same way instantly"
        case .ja: "検出されるとマスコットがすぐ同じ向きに"
        case .ko: "인식되면 캐릭터가 바로 같은 방향을 봐요"
        }
    }
    public static var dirCalNoAirpods: String {
        switch resolved {
        case .zhHans, .system: "未检测到 AirPods。戴上耳机后再校准，也可以先跳过。"
        case .en: "No AirPods detected. Wear them to calibrate, or skip for now."
        case .ja: "AirPods 未検出。装着してからキャリブレーションするか、スキップしてください"
        case .ko: "AirPods가 없습니다. 착용 후 보정하거나 건너뛰세요"
        }
    }

    // MARK: 设置页

    public static var settingsWindowTitle: String {
        switch resolved {
        case .zhHans, .system: "TurtleUp 设置"
        case .en: "TurtleUp Settings"
        case .ja: "TurtleUp 設定"
        case .ko: "TurtleUp 설정"
        }
    }
    public static var secPosture: String {
        switch resolved {
        case .zhHans, .system: "姿势提醒"
        case .en: "Posture Reminders"
        case .ja: "姿勢リマインダー"
        case .ko: "자세 알림"
        }
    }
    public static var sensDesc: String {
        switch resolved {
        case .zhHans, .system: "严格：稍微低头就提醒；宽松：低得比较明显才提醒。"
        case .en: "Strict: reminds at a slight slouch; Relaxed: only when clearly hunched."
        case .ja: "厳しめ：少しのうつむきで通知。ゆるめ：明らかに低いときだけ。"
        case .ko: "엄격: 살짝만 숙여도 알림. 느슨: 확실히 숙일 때만."
        }
    }
    public static func sustainedSec(_ n: Int) -> String {
        switch resolved {
        case .zhHans, .system: "持续时长：\(n) 秒"
        case .en: "Duration: \(n) s"
        case .ja: "継続時間：\(n) 秒"
        case .ko: "지속 시간: \(n)초"
        }
    }
    public static var remindersToggle: String {
        switch resolved {
        case .zhHans, .system: "启用低头提醒"
        case .en: "Enable slouch reminders"
        case .ja: "うつむき通知を有効化"
        case .ko: "숙임 알림 사용"
        }
    }
    public static var soundToggle: String {
        switch resolved {
        case .zhHans, .system: "音效与提示音"
        case .en: "Sounds & alerts"
        case .ja: "効果音と通知音"
        case .ko: "효과음 및 알림음"
        }
    }
    public static var secGame: String {
        switch resolved {
        case .zhHans, .system: "休息段微游戏"
        case .en: "Break-time Games"
        case .ja: "休憩ミニゲーム"
        case .ko: "휴식 미니게임"
        }
    }
    public static var gameToggle: String {
        switch resolved {
        case .zhHans, .system: "番茄休息时打怪舒展"
        case .en: "Stretch games during pomodoro breaks"
        case .ja: "休憩中にモンスター退治でストレッチ"
        case .ko: "휴식 중 몬스터 스트레칭"
        }
    }
    public static var zenToggle: String {
        switch resolved {
        case .zhHans, .system: "佛系模式（山峰不枯萎）"
        case .en: "Zen mode (mountain never withers)"
        case .ja: "禅モード（山が枯れない）"
        case .ko: "젠 모드(산이 시들지 않음)"
        }
    }
    public static var gameDesc: String {
        switch resolved {
        case .zhHans, .system: "休息 5 分钟里，用缓慢的颈部动作打跑僵硬怪；可随时关闭。"
        case .en: "During the 5-minute break, chase off stiff monsters with slow neck moves; turn off anytime."
        case .ja: "5 分の休憩で、ゆっくりした首の動きでこわばり怪を倒します。いつでもオフに。"
        case .ko: "5분 휴식 동안 천천히 목을 움직여 뻣뻣이 몬스터를 물리치세요. 언제든 끌 수 있어요."
        }
    }
    public static var secHowToPlay: String {
        switch resolved {
        case .zhHans, .system: "游戏玩法"
        case .en: "How to Play"
        case .ja: "遊び方"
        case .ko: "게임 방법"
        }
    }
    public static var tryIt: String {
        switch resolved {
        case .zhHans, .system: "试玩"
        case .en: "Try"
        case .ja: "試す"
        case .ko: "체험"
        }
    }
    public static var howToPlayDesc: String {
        switch resolved {
        case .zhHans, .system: "点任意一只即可在灵动岛上试玩；首次会先播教学卡。正式对局在番茄钟休息段自动开始。"
        case .en: "Tap any monster to try it on the island; a tutorial plays on first encounter. Real games start automatically in pomodoro breaks."
        case .ja: "タップで島で試遊。初回はチュートリアルが流れます。本番はポモドーロ休憩中に自動開始。"
        case .ko: "아무 몬스터나 탭하면 아일랜드에서 체험. 처음엔 튜토리얼이 나와요. 실전은 뽀모도로 휴식에 자동 시작."
        }
    }
    public static var secBreak: String {
        switch resolved {
        case .zhHans, .system: "定时活动"
        case .en: "Timed Breaks"
        case .ja: "定時アクティビティ"
        case .ko: "정시 활동"
        }
    }
    public static var breakPickerLabel: String {
        switch resolved {
        case .zhHans, .system: "活动提醒"
        case .en: "Break reminder"
        case .ja: "アクティビティ通知"
        case .ko: "활동 알림"
        }
    }
    public static var off: String {
        switch resolved {
        case .zhHans, .system: "关闭"
        case .en: "Off"
        case .ja: "オフ"
        case .ko: "끄기"
        }
    }
    public static var breakDesc: String {
        switch resolved {
        case .zhHans, .system: "不用番茄钟也能定时活动：到点开一局打怪（游戏已关闭则只发通知）。番茄钟运行期间自动让位。"
        case .en: "Timed breaks without pomodoro: starts a game (or just a notification if games are off). Yields while a pomodoro is running."
        case .ja: "ポモドーロなしでも定時で活動：時間になると一戦開始（ゲームオフ時は通知のみ）。ポモドーロ中は自動で譲ります。"
        case .ko: "뽀모도로 없이도 정시 활동: 시간이 되면 한 판 시작(게임 off 시 알림만). 뽀모도로 중에는 자동으로 양보."
        }
    }
    public static var secGeneral: String {
        switch resolved {
        case .zhHans, .system: "通用"
        case .en: "General"
        case .ja: "一般"
        case .ko: "일반"
        }
    }
    public static var launchAtLogin: String {
        switch resolved {
        case .zhHans, .system: "开机自动启动"
        case .en: "Launch at login"
        case .ja: "ログイン時に起動"
        case .ko: "로그인 시 자동 실행"
        }
    }
    public static var secIsland: String {
        switch resolved {
        case .zhHans, .system: "灵动岛"
        case .en: "Dynamic Island"
        case .ja: "ダイナミックアイランド"
        case .ko: "다이내믹 아일랜드"
        }
    }
    public static var showOn: String {
        switch resolved {
        case .zhHans, .system: "显示在"
        case .en: "Show on"
        case .ja: "表示先"
        case .ko: "표시 위치"
        }
    }
    public static var displayAuto: String {
        switch resolved {
        case .zhHans, .system: "自动（刘海屏优先）"
        case .en: "Automatic (notch screen first)"
        case .ja: "自動（ノッチ画面優先）"
        case .ko: "자동(노치 화면 우선)"
        }
    }
    public static var reopenOnboarding: String {
        switch resolved {
        case .zhHans, .system: "重新打开新手指引"
        case .en: "Reopen onboarding"
        case .ja: "チュートリアルを再表示"
        case .ko: "온보딩 다시 열기"
        }
    }
    public static var secSensor: String {
        switch resolved {
        case .zhHans, .system: "传感器"
        case .en: "Sensor"
        case .ja: "センサー"
        case .ko: "센서"
        }
    }
    public static var recalibrateButton: String {
        switch resolved {
        case .zhHans, .system: "坐直后点此校准"
        case .en: "Sit up straight, then tap to calibrate"
        case .ja: "背筋を伸ばしてからタップでキャリブレーション"
        case .ko: "허리를 펴고 탭해서 보정"
        }
    }
    public static var dirCalButton: String {
        switch resolved {
        case .zhHans, .system: "方向校准…"
        case .en: "Direction Calibration…"
        case .ja: "方向キャリブレーション…"
        case .ko: "방향 보정…"
        }
    }
    public static var dirCalDesc: String {
        switch resolved {
        case .zhHans, .system: "转头/侧倾时小人或游戏方向反了？戴上 AirPods 做一次方向校准即可。"
        case .en: "Avatar or game direction feels reversed? Do a quick direction calibration with AirPods on."
        case .ja: "向きが逆に感じたら？AirPods を装着して方向キャリブレーションをどうぞ。"
        case .ko: "방향이 반대로 느껴지나요? AirPods를 쓰고 방향 보정을 하세요."
        }
    }
    public static var mockToggle: String {
        switch resolved {
        case .zhHans, .system: "使用模拟数据（无 AirPods 调试）"
        case .en: "Use mock data (debug without AirPods)"
        case .ja: "モックデータを使用（AirPods なしでデバッグ）"
        case .ko: "모의 데이터 사용(AirPods 없이 디버그)"
        }
    }
    public static var mockDesc: String {
        switch resolved {
        case .zhHans, .system: "模拟数据开关需重启 App 后生效；也可用 --mock 启动参数临时开启。"
        case .en: "Mock data takes effect after restart; or launch with --mock."
        case .ja: "モックは再起動後に有効。--mock 引数でも可。"
        case .ko: "모의 데이터는 재시작 후 적용. --mock 인수로도 가능."
        }
    }
    public static var secLanguage: String {
        switch resolved {
        case .zhHans, .system: "语言"
        case .en: "Language"
        case .ja: "言語"
        case .ko: "언어"
        }
    }
    public static var languageLabel: String {
        switch resolved {
        case .zhHans, .system: "语言"
        case .en: "Language"
        case .ja: "言語"
        case .ko: "언어"
        }
    }
    public static var languageSystem: String {
        switch resolved {
        case .zhHans, .system: "跟随系统"
        case .en: "System"
        case .ja: "システムに従う"
        case .ko: "시스템 따르기"
        }
    }

    // MARK: 反馈 / 诊断日志

    public static var secFeedback: String {
        switch resolved {
        case .zhHans, .system: "反馈问题"
        case .en: "Feedback"
        case .ja: "フィードバック"
        case .ko: "피드백"
        }
    }
    public static var feedbackIssue: String {
        switch resolved {
        case .zhHans, .system: "反馈问题…（GitHub，附诊断信息）"
        case .en: "Report an Issue… (GitHub, with diagnostics)"
        case .ja: "問題を報告…（GitHub・診断情報付き）"
        case .ko: "문제 신고…(GitHub, 진단 정보 포함)"
        }
    }
    public static var feedbackExport: String {
        switch resolved {
        case .zhHans, .system: "导出完整日志到桌面"
        case .en: "Export Full Log to Desktop"
        case .ja: "完全なログをデスクトップへ"
        case .ko: "전체 로그를 데스크톱으로"
        }
    }
    public static var feedbackDesc: String {
        switch resolved {
        case .zhHans, .system: "日志只记录连接/权限/校准等事件，不含姿态数据，只存在本机。"
        case .en: "Logs only record events like connection/permission/calibration — no posture data, stored locally only."
        case .ja: "ログは接続・権限・キャリブレーション等のイベントのみ。姿勢データは含まず本機のみに保存。"
        case .ko: "로그는 연결/권한/보정 이벤트만 기록하며 자세 데이터는 없습니다. 이 Mac에만 저장됩니다."
        }
    }

    // MARK: 支持作者（赞助）

    public static var secSupport: String {
        switch resolved {
        case .zhHans, .system: "支持 TurtleUp"
        case .en: "Support TurtleUp"
        case .ja: "TurtleUp を応援"
        case .ko: "TurtleUp 후원하기"
        }
    }
    public static var supportDesc: String {
        switch resolved {
        case .zhHans, .system: "免费开源，没有广告。如果它帮你抬起了头，可以请作者喝杯咖啡。"
        case .en: "Free and open source, no ads. If it helped you lift your head, you can buy the author a coffee."
        case .ja: "無料・オープンソース・広告なし。役に立ったら作者にコーヒーを一杯どうぞ。"
        case .ko: "무료 오픈소스, 광고 없음. 도움이 되었다면 개발자에게 커피 한 잔을 선물하세요."
        }
    }
    public static var alipayLabel: String {
        switch resolved {
        case .zhHans, .system: "支付宝"
        case .en, .ja, .ko: "Alipay"
        }
    }
    public static var wechatLabel: String {
        switch resolved {
        case .zhHans, .system: "微信支付"
        case .en, .ja, .ko: "WeChat Pay"
        }
    }
    public static var scanHint: String {
        switch resolved {
        case .zhHans, .system: "手机扫码即可支持"
        case .en: "Scan with your phone to support"
        case .ja: "スマホでスキャンして応援"
        case .ko: "휴대폰으로 스캔하여 후원"
        }
    }

    // MARK: 灵动岛

    public static var statusPaused: String {
        switch resolved {
        case .zhHans, .system: "已暂停"
        case .en: "Paused"
        case .ja: "一時停止"
        case .ko: "일시 정지"
        }
    }
    public static var statusNotWearing: String {
        switch resolved {
        case .zhHans, .system: "未佩戴"
        case .en: "Not wearing"
        case .ja: "未装着"
        case .ko: "미착용"
        }
    }
    public static var statusGood: String {
        switch resolved {
        case .zhHans, .system: "挺好"
        case .en: "Good"
        case .ja: "良好"
        case .ko: "좋음"
        }
    }
    public static var statusLow: String {
        switch resolved {
        case .zhHans, .system: "有点低"
        case .en: "A bit low"
        case .ja: "やや低い"
        case .ko: "조금 낮음"
        }
    }
    public static var statusBad: String {
        switch resolved {
        case .zhHans, .system: "快抬头"
        case .en: "Heads up"
        case .ja: "頭を上げて"
        case .ko: "고개를 들어요"
        }
    }
    public static var avatarHint: String {
        switch resolved {
        case .zhHans, .system: "小人跟着你动，脸正居中就是坐直了"
        case .en: "The buddy mirrors you — face centered means you’re upright"
        case .ja: "マスコットが連動。顔が中央なら正しい姿勢です"
        case .ko: "캐릭터가 따라 움직여요. 얼굴이 중앙이면 바른 자세"
        }
    }
    public static var calibratedFlash: String {
        switch resolved {
        case .zhHans, .system: "已校准，小人回正了 ✓"
        case .en: "Calibrated — buddy recentered ✓"
        case .ja: "キャリブレーション完了 ✓"
        case .ko: "보정 완료, 캐릭터가 중앙으로 ✓"
        }
    }
    public static var pauseMonitoring: String {
        switch resolved {
        case .zhHans, .system: "暂停监测"
        case .en: "Pause Monitoring"
        case .ja: "検出を一時停止"
        case .ko: "모니터링 일시 정지"
        }
    }
    public static var resumeMonitoring: String {
        switch resolved {
        case .zhHans, .system: "继续监测"
        case .en: "Resume Monitoring"
        case .ja: "検出を再開"
        case .ko: "모니터링 재개"
        }
    }
    public static var recalibrate: String {
        switch resolved {
        case .zhHans, .system: "坐直校准"
        case .en: "Recalibrate"
        case .ja: "姿勢リセット"
        case .ko: "자세 재보정"
        }
    }
    public static var sentencePaused: String {
        switch resolved {
        case .zhHans, .system: "监测已暂停"
        case .en: "Monitoring paused"
        case .ja: "検出を一時停止中"
        case .ko: "모니터링 일시 정지됨"
        }
    }
    public static var sentenceNotWearing: String {
        switch resolved {
        case .zhHans, .system: "戴上 AirPods 开始守护"
        case .en: "Put on AirPods to start"
        case .ja: "AirPods を装着して開始"
        case .ko: "AirPods를 착용하면 시작"
        }
    }
    public static var sentenceGood: String {
        switch resolved {
        case .zhHans, .system: "姿势不错，继续保持"
        case .en: "Nice posture, keep it up"
        case .ja: "いい姿勢です。そのまま"
        case .ko: "좋은 자세예요, 유지하세요"
        }
    }
    public static var sentenceLow: String {
        switch resolved {
        case .zhHans, .system: "有点低头，抬一点"
        case .en: "Slightly hunched, lift a bit"
        case .ja: "少しうつむいています。少し上げて"
        case .ko: "살짝 숙였어요, 조금 들어요"
        }
    }
    public static var sentenceBad: String {
        switch resolved {
        case .zhHans, .system: "低头太久了，抬一点 🐢"
        case .en: "Head down too long — lift up 🐢"
        case .ja: "長時間うつむいています。頭を上げて 🐢"
        case .ko: "너무 오래 숙였어요, 고개를 들어요 🐢"
        }
    }
    public static var dayNoData: String {
        switch resolved {
        case .zhHans, .system: "戴着就自动记录"
        case .en: "Records automatically"
        case .ja: "装着するだけで自動記録"
        case .ko: "착용하면 자동 기록"
        }
    }
    public static var dayGreat: String {
        switch resolved {
        case .zhHans, .system: "今天很棒"
        case .en: "Great today"
        case .ja: "今日は絶好調"
        case .ko: "오늘 아주 좋아요"
        }
    }
    public static var dayOk: String {
        switch resolved {
        case .zhHans, .system: "今天还行"
        case .en: "Okay today"
        case .ja: "今日はまずまず"
        case .ko: "오늘 괜찮아요"
        }
    }
    public static var dayWarning: String {
        switch resolved {
        case .zhHans, .system: "要注意了"
        case .en: "Needs attention"
        case .ja: "要注意"
        case .ko: "주의 필요"
        }
    }
    public static var dayDescNoData: String {
        switch resolved {
        case .zhHans, .system: "不用点任何东西，统计会随佩戴出现在这里"
        case .en: "Nothing to start — stats build up as you wear AirPods"
        case .ja: "手動開始は不要。装着中に自動で集計されます"
        case .ko: "수동 시작 없이 착용만 하면 자동 집계돼요"
        }
    }
    public static var dayDescGreat: String {
        switch resolved {
        case .zhHans, .system: "今天状态很棒，继续保持"
        case .en: "Great form today, keep it up"
        case .ja: "今日はとても良い状態です"
        case .ko: "오늘 상태 아주 좋아요"
        }
    }
    public static var dayDescOk: String {
        switch resolved {
        case .zhHans, .system: "今天还不错，记得偶尔抬头"
        case .en: "Not bad today — remember to look up"
        case .ja: "今日は悪くないです。時々上を向いて"
        case .ko: "오늘 괜찮아요, 가끔 고개를 들어요"
        }
    }
    public static var dayDescWarning: String {
        switch resolved {
        case .zhHans, .system: "今天低头有点多，多抬头休息"
        case .en: "A bit too much slouching today — rest your neck"
        case .ja: "今日はうつむきが多め。首を休めて"
        case .ko: "오늘 숙임이 많아요, 목을 쉬게 해요"
        }
    }
    public static func startPomodoro(_ time: String) -> String {
        switch resolved {
        case .zhHans, .system: "开始番茄 \(time)"
        case .en: "Start \(time)"
        case .ja: "開始 \(time)"
        case .ko: "시작 \(time)"
        }
    }
    public static func focusTime(_ time: String) -> String {
        switch resolved {
        case .zhHans, .system: "专注 \(time)"
        case .en: "Focus \(time)"
        case .ja: "集中 \(time)"
        case .ko: "집중 \(time)"
        }
    }
    public static func restTime(_ time: String) -> String {
        switch resolved {
        case .zhHans, .system: "休息 \(time)"
        case .en: "Break \(time)"
        case .ja: "休憩 \(time)"
        case .ko: "휴식 \(time)"
        }
    }
    public static var resumeTimer: String {
        switch resolved {
        case .zhHans, .system: "继续"
        case .en: "Resume"
        case .ja: "再開"
        case .ko: "계속"
        }
    }
    public static var pauseTimer: String {
        switch resolved {
        case .zhHans, .system: "暂停"
        case .en: "Pause"
        case .ja: "一時停止"
        case .ko: "일시 정지"
        }
    }
    public static var resetTimer: String {
        switch resolved {
        case .zhHans, .system: "重置"
        case .en: "Reset"
        case .ja: "リセット"
        case .ko: "재설정"
        }
    }
    public static var permNeeded: String {
        switch resolved {
        case .zhHans, .system: "需要「运动与健身」权限"
        case .en: "“Motion & Fitness” permission needed"
        case .ja: "「モーションとフィットネス」の権限が必要"
        case .ko: "「모션 및 피트니스」 권한 필요"
        }
    }

    // MARK: 菜单栏

    public static var menuExpand: String {
        switch resolved {
        case .zhHans, .system: "展开灵动岛"
        case .en: "Expand Island"
        case .ja: "島を展開"
        case .ko: "아일랜드 펼치기"
        }
    }
    public static var menuCollapse: String {
        switch resolved {
        case .zhHans, .system: "收起灵动岛"
        case .en: "Collapse Island"
        case .ja: "島をたたむ"
        case .ko: "아일랜드 접기"
        }
    }
    public static var menuEndGame: String {
        switch resolved {
        case .zhHans, .system: "结束本局"
        case .en: "End Game"
        case .ja: "ゲーム終了"
        case .ko: "게임 종료"
        }
    }
    public static var menuStartPomodoro: String {
        switch resolved {
        case .zhHans, .system: "开始番茄钟"
        case .en: "Start Pomodoro"
        case .ja: "ポモドーロ開始"
        case .ko: "뽀모도로 시작"
        }
    }
    public static var menuStopPomodoro: String {
        switch resolved {
        case .zhHans, .system: "停止番茄钟"
        case .en: "Stop Pomodoro"
        case .ja: "ポモドーロ停止"
        case .ko: "뽀모도로 중지"
        }
    }
    public static var menuMute: String {
        switch resolved {
        case .zhHans, .system: "静音音效"
        case .en: "Mute Sounds"
        case .ja: "ミュート"
        case .ko: "소리 끄기"
        }
    }
    public static var menuUnmute: String {
        switch resolved {
        case .zhHans, .system: "恢复音效"
        case .en: "Unmute Sounds"
        case .ja: "ミュート解除"
        case .ko: "소리 켜기"
        }
    }
    public static var menuSettings: String {
        switch resolved {
        case .zhHans, .system: "设置…"
        case .en: "Settings…"
        case .ja: "設定…"
        case .ko: "설정…"
        }
    }
    public static var menuQuit: String {
        switch resolved {
        case .zhHans, .system: "退出 TurtleUp"
        case .en: "Quit TurtleUp"
        case .ja: "TurtleUp を終了"
        case .ko: "TurtleUp 종료"
        }
    }

    // MARK: 教学卡

    public static var tutorialTryMove: String {
        switch resolved {
        case .zhHans, .system: "跟着小人试试这个动作"
        case .en: "Try the move with the buddy"
        case .ja: "マスコットと一緒に動きを試そう"
        case .ko: "캐릭터와 함께 동작을 따라 해 보세요"
        }
    }

    // MARK: 检查更新

    public static var menuCheckUpdate: String {
        switch resolved {
        case .zhHans, .system: "检查更新…"
        case .en: "Check for Updates…"
        case .ja: "アップデートを確認…"
        case .ko: "업데이트 확인…"
        }
    }
    public static func menuUpdateAvailable(_ v: String) -> String {
        switch resolved {
        case .zhHans, .system: "下载新版本 v\(v)…"
        case .en: "Get v\(v)…"
        case .ja: "新バージョン v\(v) を入手…"
        case .ko: "새 버전 v\(v) 받기…"
        }
    }
    public static func updateAvailableTitle(_ v: String) -> String {
        switch resolved {
        case .zhHans, .system: "发现新版本 v\(v)"
        case .en: "TurtleUp v\(v) is available"
        case .ja: "新バージョン v\(v) があります"
        case .ko: "새 버전 v\(v)이 나왔어요"
        }
    }
    public static var updateAvailableBody: String {
        switch resolved {
        case .zhHans, .system: "Homebrew 安装：复制命令到「终端」执行即可升级；\n手动安装：打开下载页获取最新 zip。"
        case .en: "Homebrew install: copy the command and run it in Terminal.\nManual install: open the download page for the latest zip."
        case .ja: "Homebrew の場合：コマンドをコピーして「ターミナル」で実行。\n手動の場合：ダウンロードページから最新 zip を入手。"
        case .ko: "Homebrew 설치: 명령을 복사해 터미널에서 실행하세요.\n수동 설치: 다운로드 페이지에서 최신 zip을 받으세요."
        }
    }
    public static var updateCopyBrew: String {
        switch resolved {
        case .zhHans, .system: "复制 brew 升级命令"
        case .en: "Copy brew Command"
        case .ja: "brew コマンドをコピー"
        case .ko: "brew 명령 복사"
        }
    }
    public static var updateOpenRelease: String {
        switch resolved {
        case .zhHans, .system: "打开下载页"
        case .en: "Open Download Page"
        case .ja: "ダウンロードページを開く"
        case .ko: "다운로드 페이지 열기"
        }
    }
    public static var updateUpToDate: String {
        switch resolved {
        case .zhHans, .system: "已是最新版本"
        case .en: "You're on the latest version"
        case .ja: "最新バージョンです"
        case .ko: "최신 버전입니다"
        }
    }
    public static var updateCheckFailed: String {
        switch resolved {
        case .zhHans, .system: "检查失败，请检查网络后重试"
        case .en: "Check failed — check your network and retry"
        case .ja: "確認に失敗。ネットワークを確認してください"
        case .ko: "확인 실패. 네트워크 확인 후 다시 시도하세요"
        }
    }
    public static var updateDevBuild: String {
        switch resolved {
        case .zhHans, .system: "开发模式构建，跳过版本检查"
        case .en: "Dev build — version check skipped"
        case .ja: "開発ビルドのためチェックをスキップ"
        case .ko: "개발 빌드라 버전 확인을 건너뜻니다"
        }
    }
}
