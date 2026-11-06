# audio story-001 探針(2026-11-06,已結案)

假設:AudioServer bus / linear_to_db / ConfigFile / headless 判斷法 / SettingsFileStore 檔案層。headless 執行,檔案探針注入 OS 暫存目錄,未碰 user://settings.cfg。

執行:`Godot_v4.7.1 --headless --path . -s res://prototypes/audio-story001-probes-2026-11-06/probe_api.gd`;file_store 探針另加 `-- <暫存目錄>`。

## probe_api.gd 原文輸出(run_output_api.txt)
```
PROBE DisplayServer.get_name() = headless
PROBE bus_count(initial) = 1
PROBE bus[0] name=Master send=
PROBE get_bus_index('Music') before = -1
PROBE after add: count=2 idx('Music')=1 send=Master
PROBE readback volume_db = -6.0
PROBE readback mute = true
PROBE linear_to_db(1.0)=0.0 (0.5)=-6.02059991327962 (0.0)=-inf (0.0001)=-80.0
PROBE is_inf(linear_to_db(0.0)) = true
PROBE encode_to_text = [[settings]

egm=true
vol=0.5
]
PROBE parse ok err = 0
PROBE roundtrip egm=true vol=0.5 missing=DEF
ERROR: ConfigFile parse error at <string>:0: Expected value, got ''=''.
   at: _parse (core/io/config_file.cpp:293)
   GDScript backtrace (most recent call first):
       [0] _init (res://prototypes/audio-story001-probes-2026-11-06/probe_api.gd:32)
PROBE parse garbage err = 43
PROBE parse empty err = 0
PROBE parse type-mismatch: 0 vol=abc
```

## probe_file_store.gd 原文輸出(run_output_file_store.txt,AC-14)
```
PROBE path = C:/Users/FELIXF~1/AppData/Local/Temp/1/tmp.X1Z4MUDcUm/probe_settings.cfg  default path untouched = user://settings.cfg
PROBE read missing file -> [] (expect empty)
PROBE write ok = true
PROBE read back text equals written = true
PROBE roundtrip equal = true egm=true master=0.25 muted=true
PROBE write to impossible path -> false (expect false, no crash)
PROBE boot_load(real store, headless=false) = true master=0.25 egm=true
PROBE after setter, file master -> 0.5 (expect 0.5)
PROBE bus count after boot_load = 4 music mute=true
```

## 結論
- headless 判斷:`DisplayServer.get_name() == "headless"` 成立。
- headless 下 AudioServer 可新增/讀回 bus、send、volume、mute,故 AC-5 可自動驗。
- linear_to_db(0.0) = -inf,故 volume_to_db 自行以 -80 dB 為靜音等價值。
- ConfigFile 亂碼 parse 回 43 並由引擎在 stderr 印 ERROR(非本專案 push_error);型別不符的值 parse 仍回 OK,需由 codec 逐鍵檢查型別。
- 注意:探針第二支的 `music mute=true` 是因為載入的暫存設定檔 muted=true。
