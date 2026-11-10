# 暫停對音訊/Tween 的影響探針 (2026-11-10)

狀態:concluded。對應協調者對 `battle_menu.gd`(`get_tree().paused = true`)與 `MusicPlayerHost`/`SfxPlayerHost`(process_mode 預設 INHERIT)的疑點。
指令:`Godot_v4.7.1 console --headless --audio-driver Dummy --path . -s res://prototypes/audio-pause-probe-2026-11-10/pause_probe.gd`,exit 0,原始輸出 `run_output.txt`。
不引用 production 程式碼;測試節點掛在 `root` 底下的 Node(與 MusicPlayerHost 同為 root 直系、INHERIT)。

## 先決:Dummy 驅動量得到嗎?
量得到 (A)。`T0 baseline unpaused INHERIT: playing=true stream_paused=false pos=0.2880`(real-time 0.5 秒後位置前進,速率低於牆鐘但單調前進,故看「前進與否」有效,不看絕對值)。

## 結果 (A,原始行)
- INHERIT 播放器暫停即停:`T1 +0.5s paused INHERIT: playing=false stream_paused=true pos=0.3040 delta=0.016`(僅暫停前一幀的餘量)
- ALWAYS 不受影響:`T1 +0.5s paused ALWAYS : playing=true stream_paused=false pos=0.6560 delta=0.368`
- 解除暫停後續播:`T6 unpaused again INHERIT: playing=true stream_paused=false pos=0.7680`
- 暫停【中】才呼叫 play() 的 INHERIT 播放器照常播:`T3 play() while paused INHERIT: playing=true stream_paused=false pos=0.3840`
- 節點綁定 Tween 暫停中:INHERIT 卡住 `T4 ... INHERIT-bound: volume_db=-40.0 running=true`;ALWAYS 推進完 `T4 ... ALWAYS-bound : volume_db=0.0 running=false`
- signal 回呼不受暫停影響:`T5 signal callback while paused: hits=1`(⚠️ 回呼是 lambda、發訊號的 Button 為 ALWAYS;**未測**「連到 INHERIT 節點的具名方法」,屬 (C) 推論)

## 未驗 / 限制
- 真實音訊裝置下行為未測(Dummy 驅動)。
- Tween 卡住後解除暫停是否續跑:本探針未測。
- 「暫停中換曲的淡入卡在 -80 dB」是 T3 + T4 的組合推論 (C),未直接量測。
- 真實 BattleMenu 開啟流程未走(探針直接設 `paused`)。
