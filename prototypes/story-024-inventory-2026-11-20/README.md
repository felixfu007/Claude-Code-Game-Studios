# story-024 盤點表(2026-11-20)

## 原始 grep 輸出:grep -rln "affinity" tests --include=*.gd(共 106 檔)
```
tests/helpers/real_battle_driver.gd
tests/integration/cursor/frame_buffer_ordering_test.gd
tests/integration/gameplay/affinity/affinity_roster_character_mapper_test.gd
tests/integration/gameplay/affinity/position_chain_reads_relation_state_test.gd
tests/integration/gameplay/affinity_pool/affinity_pool_wiring_test.gd
tests/integration/gameplay/cards/affinity_pool_write_port_test.gd
tests/integration/gameplay/cards/card_cost_pair_state_test.gd
tests/integration/gameplay/cards/card_named_target_restriction_test.gd
tests/integration/gameplay/cards/card_play_session_test.gd
tests/integration/gameplay/cards/card_play_wiring_test.gd
tests/integration/gameplay/combat/lone_guard_relation_state_test.gd
tests/integration/gameplay/narrative/support_conversation_pool_write_port_test.gd
tests/integration/ui/battle/battle_screen_affinity_tuning_curve_and_badfile_test.gd
tests/integration/ui/battle/battle_screen_affinity_tuning_wiring_test.gd
tests/integration/ui/battle/battle_screen_battle_outcome_test.gd
tests/integration/ui/battle/battle_screen_campaign_affinity_ledger_seeding_test.gd
tests/integration/ui/battle/battle_screen_campaign_mission_outcome_wiring_test.gd
tests/integration/ui/battle/battle_screen_campaign_sequence_path_resolution_test.gd
tests/integration/ui/battle/battle_screen_card_confirm_cost_panel_test.gd
tests/integration/ui/battle/battle_screen_card_cost_wiring_test.gd
tests/integration/ui/battle/battle_screen_card_deck_wiring_test.gd
tests/integration/ui/battle/battle_screen_card_face_template_test.gd
tests/integration/ui/battle/battle_screen_card_play_wiring_test.gd
tests/integration/ui/battle/battle_screen_card_strike_confirm_test.gd
tests/integration/ui/battle/battle_screen_card_unplayable_reason_test.gd
tests/integration/ui/battle/battle_screen_egm_guess_selector_test.gd
tests/integration/ui/battle/battle_screen_enemy_phase_playback_test.gd
tests/integration/ui/battle/battle_screen_fixed_target_card_test.gd
tests/integration/ui/battle/battle_screen_guard_display_test.gd
tests/integration/ui/battle/battle_screen_hide_affinity_test.gd
tests/integration/ui/battle/battle_screen_pair_wear_wiring_test.gd
tests/integration/ui/battle/battle_screen_relation_minimap_test.gd
tests/integration/ui/battle/battle_sfx_wiring_test.gd
tests/integration/ui/battle/board_affinity_line_render_test.gd
tests/integration/ui/battle/relation_state_display_test.gd
tests/integration/ui/battle_cursor_navigation_convergence_test.gd
tests/integration/ui/battle_input_gaps_test.gd
tests/integration/ui/battle_screen_objective_and_menu_test.gd
tests/integration/ui/board_view_piece_label_backdrop_test.gd
tests/integration/ui/card_confirm_panel_test.gd
tests/integration/ui/card_target_selection_test.gd
tests/integration/ui/input/battle_new_actions_registration_test.gd
tests/integration/ui/shell/battle_abandon_rollback_test.gd
tests/integration/ui/shell/campaign_all_missions_load_test.gd
tests/integration/ui/shell/campaign_complete_test.gd
tests/integration/ui/shell/campaign_defeat_retry_same_mission_test.gd
tests/integration/ui/shell/campaign_single_source_seeding_test.gd
tests/integration/ui/shell/campaign_support_conversation_carryover_test.gd
tests/integration/ui/shell/scene_router_test.gd
tests/integration/ui/shell/support_conversation_transition_flow_test.gd
tests/integration/ui/shell/title_screen_scene_switch_test.gd
tests/integration/ui/shell/tutorial_sequence_test.gd
tests/perf/affinity_query_perf_benchmark.gd
tests/unit/core/audio/sfx_cue_table_test.gd
tests/unit/core/campaign/campaign_progress_test.gd
tests/unit/core/i18n/i18n_migrated_strings_test.gd
tests/unit/core/settings/game_settings_hide_affinity_test.gd
tests/unit/core/settings/game_settings_persistence_guard_test.gd
tests/unit/core/settings/settings_codec_test.gd
tests/unit/cursor/write_read_interface_test.gd
tests/unit/gameplay/affinity/affinity_link_no_direct_return_test.gd
tests/unit/gameplay/affinity/affinity_link_test.gd
tests/unit/gameplay/affinity/affinity_manhattan_implementation_count_test.gd
tests/unit/gameplay/affinity/affinity_phi_provider_test.gd
tests/unit/gameplay/affinity/affinity_rules_test.gd
tests/unit/gameplay/affinity/pair_cost_phi_deduction_test.gd
tests/unit/gameplay/affinity/relation_state_of_pair_test.gd
tests/unit/gameplay/affinity_pool/affinity_data_pool_campaign_tick_test.gd
tests/unit/gameplay/affinity_pool/affinity_data_pool_death_marks_test.gd
tests/unit/gameplay/affinity_pool/affinity_data_pool_read_gate_test.gd
tests/unit/gameplay/affinity_pool/affinity_data_pool_weighted_reads_test.gd
tests/unit/gameplay/affinity_pool/affinity_data_pool_write_path_test.gd
tests/unit/gameplay/affinity_pool/affinity_record_list_test.gd
tests/unit/gameplay/affinity_pool/affinity_types_test.gd
tests/unit/gameplay/battle/battle_state_guard_test.gd
tests/unit/gameplay/battle/battle_state_lone_guard_conditional_test.gd
tests/unit/gameplay/battle/battle_state_lone_guard_if_at_test.gd
tests/unit/gameplay/battle/battle_state_straddle_hold_back_test.gd
tests/unit/gameplay/campaign/campaign_affinity_ledger_test.gd
tests/unit/gameplay/campaign/campaign_sequence_test.gd
tests/unit/gameplay/cards/card_ally_proximity_test.gd
tests/unit/gameplay/cards/card_combo_damage_test.gd
tests/unit/gameplay/cards/card_cost_settlement_test.gd
tests/unit/gameplay/cards/card_data_model_fields_test.gd
tests/unit/gameplay/cards/card_deck_test.gd
tests/unit/gameplay/cards/card_direct_damage_payer_reach_test.gd
tests/unit/gameplay/cards/card_direct_damage_test.gd
tests/unit/gameplay/cards/card_from_csv_test.gd
tests/unit/gameplay/cards/card_heal_and_buff_test.gd
tests/unit/gameplay/cards/card_permanent_write_test.gd
tests/unit/gameplay/cards/card_play_session_commit_entry_test.gd
tests/unit/gameplay/cards/card_unplayable_reason_engine_test.gd
tests/unit/gameplay/combat/combat_rules_guard_test.gd
tests/unit/gameplay/narrative/support_conversation_record_test.gd
tests/unit/gameplay/narrative/support_conversation_write_call_site_count_test.gd
tests/unit/gameplay/tuning/affinity_tuning_test.gd
tests/unit/gameplay/tuning/card_modifier_tuning_test.gd
tests/unit/gameplay/tuning/combat_tuning_test.gd
tests/unit/gameplay/tuning/deck_tuning_test.gd
tests/unit/ui/affinity_line_shape_test.gd
tests/unit/ui/battle/battle_screen_guard_line_test.gd
tests/unit/ui/battle_screen_hand_bar_wiring_test.gd
tests/unit/ui/battle_screen_load_guard_test.gd
tests/unit/ui/battle_screen_preview_test.gd
tests/unit/ui/hand_bar_test.gd
tests/unit/ui/relation_minimap_line_shape_test.gd
```

## 判準
- 受影響 = 斷言把「真實資料只有 藍亭萱-徐培恩、董振豪-秦亦柔 兩條關係」當成行為規則或期望值寫死(字面 2、麥子健必無配對、legal 集合恰 2 條)。
- 不受影響 = 只是名稱含 affinity;或用合成夾具/注入資料;或斷言的是資料檔本身內容(canon 守門);或已由 story-012/013/014 覆蓋非人設與麥子健配對。
- 注意:此為關鍵字掃描加人工讀碼的分類,不是逐檔逐行讀完 106 檔;不受影響欄的理由是類別理由。

## 逐檔標記
| 檔案 | 標記 | 理由 |
|---|---|---|
| tests/helpers/real_battle_driver.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/cursor/frame_buffer_ordering_test.gd | 不受影響 | 池/旋鈕/設定/本地化/游標/音效,affinity 僅為名稱或鍵名 |
| tests/integration/gameplay/affinity/affinity_roster_character_mapper_test.gd | 不受影響 | 關鍵字掃描未見把兩對當規則的斷言 |
| tests/integration/gameplay/affinity/position_chain_reads_relation_state_test.gd | 不受影響 | 合成/注入池資料;story-012/013/014 已含非人設與麥子健配對斷言 |
| tests/integration/gameplay/affinity_pool/affinity_pool_wiring_test.gd | 不受影響 | 池/旋鈕/設定/本地化/游標/音效,affinity 僅為名稱或鍵名 |
| tests/integration/gameplay/cards/affinity_pool_write_port_test.gd | **受影響(候選)** | 見「受影響明細」 |
| tests/integration/gameplay/cards/card_cost_pair_state_test.gd | 不受影響 | 關鍵字掃描未見把兩對當規則的斷言 |
| tests/integration/gameplay/cards/card_named_target_restriction_test.gd | 不受影響 | 關鍵字掃描未見把兩對當規則的斷言 |
| tests/integration/gameplay/cards/card_play_session_test.gd | 不受影響 | 關鍵字掃描未見把兩對當規則的斷言 |
| tests/integration/gameplay/cards/card_play_wiring_test.gd | 不受影響 | 關鍵字掃描未見把兩對當規則的斷言 |
| tests/integration/gameplay/combat/lone_guard_relation_state_test.gd | 不受影響 | 合成/注入池資料;story-012/013/014 已含非人設與麥子健配對斷言 |
| tests/integration/gameplay/narrative/support_conversation_pool_write_port_test.gd | 不受影響 | 關鍵字掃描未見把兩對當規則的斷言 |
| tests/integration/ui/battle/battle_screen_affinity_tuning_curve_and_badfile_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/battle/battle_screen_affinity_tuning_wiring_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/battle/battle_screen_battle_outcome_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/battle/battle_screen_campaign_affinity_ledger_seeding_test.gd | **受影響(候選)** | 見「受影響明細」 |
| tests/integration/ui/battle/battle_screen_campaign_mission_outcome_wiring_test.gd | **受影響(候選)** | 見「受影響明細」 |
| tests/integration/ui/battle/battle_screen_campaign_sequence_path_resolution_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/battle/battle_screen_card_confirm_cost_panel_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/battle/battle_screen_card_cost_wiring_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/battle/battle_screen_card_deck_wiring_test.gd | **受影響(候選)** | 見「受影響明細」 |
| tests/integration/ui/battle/battle_screen_card_face_template_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/battle/battle_screen_card_play_wiring_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/battle/battle_screen_card_strike_confirm_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/battle/battle_screen_card_unplayable_reason_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/battle/battle_screen_egm_guess_selector_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/battle/battle_screen_enemy_phase_playback_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/battle/battle_screen_fixed_target_card_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/battle/battle_screen_guard_display_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/battle/battle_screen_hide_affinity_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/battle/battle_screen_pair_wear_wiring_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/battle/battle_screen_relation_minimap_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/battle/battle_sfx_wiring_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/battle/board_affinity_line_render_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/battle/relation_state_display_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/battle_cursor_navigation_convergence_test.gd | 不受影響 | 池/旋鈕/設定/本地化/游標/音效,affinity 僅為名稱或鍵名 |
| tests/integration/ui/battle_input_gaps_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/battle_screen_objective_and_menu_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/board_view_piece_label_backdrop_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/card_confirm_panel_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/card_target_selection_test.gd | **受影響(候選)** | 見「受影響明細」 |
| tests/integration/ui/input/battle_new_actions_registration_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/shell/battle_abandon_rollback_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/shell/campaign_all_missions_load_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/shell/campaign_complete_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/shell/campaign_defeat_retry_same_mission_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/shell/campaign_single_source_seeding_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/shell/campaign_support_conversation_carryover_test.gd | **受影響(候選)** | 見「受影響明細」 |
| tests/integration/ui/shell/scene_router_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/shell/support_conversation_transition_flow_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/shell/title_screen_scene_switch_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/integration/ui/shell/tutorial_sequence_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/perf/affinity_query_perf_benchmark.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/unit/core/audio/sfx_cue_table_test.gd | 不受影響 | 池/旋鈕/設定/本地化/游標/音效,affinity 僅為名稱或鍵名 |
| tests/unit/core/campaign/campaign_progress_test.gd | 不受影響 | 關鍵字掃描未見把兩對當規則的斷言 |
| tests/unit/core/i18n/i18n_migrated_strings_test.gd | 不受影響 | 池/旋鈕/設定/本地化/游標/音效,affinity 僅為名稱或鍵名 |
| tests/unit/core/settings/game_settings_hide_affinity_test.gd | 不受影響 | 池/旋鈕/設定/本地化/游標/音效,affinity 僅為名稱或鍵名 |
| tests/unit/core/settings/game_settings_persistence_guard_test.gd | 不受影響 | 池/旋鈕/設定/本地化/游標/音效,affinity 僅為名稱或鍵名 |
| tests/unit/core/settings/settings_codec_test.gd | 不受影響 | 池/旋鈕/設定/本地化/游標/音效,affinity 僅為名稱或鍵名 |
| tests/unit/cursor/write_read_interface_test.gd | 不受影響 | 池/旋鈕/設定/本地化/游標/音效,affinity 僅為名稱或鍵名 |
| tests/unit/gameplay/affinity/affinity_link_no_direct_return_test.gd | 不受影響 | 關鍵字掃描未見把兩對當規則的斷言 |
| tests/unit/gameplay/affinity/affinity_link_test.gd | **受影響(候選)** | 見「受影響明細」 |
| tests/unit/gameplay/affinity/affinity_manhattan_implementation_count_test.gd | 不受影響 | 關鍵字掃描未見把兩對當規則的斷言 |
| tests/unit/gameplay/affinity/affinity_phi_provider_test.gd | 不受影響 | 合成/注入池資料;story-012/013/014 已含非人設與麥子健配對斷言 |
| tests/unit/gameplay/affinity/affinity_rules_test.gd | 不受影響 | 合成/注入池資料;story-012/013/014 已含非人設與麥子健配對斷言 |
| tests/unit/gameplay/affinity/pair_cost_phi_deduction_test.gd | 不受影響 | 關鍵字掃描未見把兩對當規則的斷言 |
| tests/unit/gameplay/affinity/relation_state_of_pair_test.gd | 不受影響 | 合成/注入池資料;story-012/013/014 已含非人設與麥子健配對斷言 |
| tests/unit/gameplay/affinity_pool/affinity_data_pool_campaign_tick_test.gd | 不受影響 | 池/旋鈕/設定/本地化/游標/音效,affinity 僅為名稱或鍵名 |
| tests/unit/gameplay/affinity_pool/affinity_data_pool_death_marks_test.gd | 不受影響 | 池/旋鈕/設定/本地化/游標/音效,affinity 僅為名稱或鍵名 |
| tests/unit/gameplay/affinity_pool/affinity_data_pool_read_gate_test.gd | 不受影響 | 池/旋鈕/設定/本地化/游標/音效,affinity 僅為名稱或鍵名 |
| tests/unit/gameplay/affinity_pool/affinity_data_pool_weighted_reads_test.gd | 不受影響 | 池/旋鈕/設定/本地化/游標/音效,affinity 僅為名稱或鍵名 |
| tests/unit/gameplay/affinity_pool/affinity_data_pool_write_path_test.gd | 不受影響 | 池/旋鈕/設定/本地化/游標/音效,affinity 僅為名稱或鍵名 |
| tests/unit/gameplay/affinity_pool/affinity_record_list_test.gd | 不受影響 | 池/旋鈕/設定/本地化/游標/音效,affinity 僅為名稱或鍵名 |
| tests/unit/gameplay/affinity_pool/affinity_types_test.gd | 不受影響 | 池/旋鈕/設定/本地化/游標/音效,affinity 僅為名稱或鍵名 |
| tests/unit/gameplay/battle/battle_state_guard_test.gd | 不受影響 | 關鍵字掃描未見把兩對當規則的斷言 |
| tests/unit/gameplay/battle/battle_state_lone_guard_conditional_test.gd | 不受影響 | 合成/注入池資料;story-012/013/014 已含非人設與麥子健配對斷言 |
| tests/unit/gameplay/battle/battle_state_lone_guard_if_at_test.gd | 不受影響 | 合成/注入池資料;story-012/013/014 已含非人設與麥子健配對斷言 |
| tests/unit/gameplay/battle/battle_state_straddle_hold_back_test.gd | 不受影響 | 關鍵字掃描未見把兩對當規則的斷言 |
| tests/unit/gameplay/campaign/campaign_affinity_ledger_test.gd | 不受影響 | 關鍵字掃描未見把兩對當規則的斷言 |
| tests/unit/gameplay/campaign/campaign_sequence_test.gd | 不受影響 | 關鍵字掃描未見把兩對當規則的斷言 |
| tests/unit/gameplay/cards/card_ally_proximity_test.gd | 不受影響 | 關鍵字掃描未見把兩對當規則的斷言 |
| tests/unit/gameplay/cards/card_combo_damage_test.gd | 不受影響 | 關鍵字掃描未見把兩對當規則的斷言 |
| tests/unit/gameplay/cards/card_cost_settlement_test.gd | 不受影響 | 關鍵字掃描未見把兩對當規則的斷言 |
| tests/unit/gameplay/cards/card_data_model_fields_test.gd | 不受影響 | 關鍵字掃描未見把兩對當規則的斷言 |
| tests/unit/gameplay/cards/card_deck_test.gd | 不受影響 | 關鍵字掃描未見把兩對當規則的斷言 |
| tests/unit/gameplay/cards/card_direct_damage_payer_reach_test.gd | 不受影響 | 關鍵字掃描未見把兩對當規則的斷言 |
| tests/unit/gameplay/cards/card_direct_damage_test.gd | 不受影響 | 關鍵字掃描未見把兩對當規則的斷言 |
| tests/unit/gameplay/cards/card_from_csv_test.gd | 不受影響 | 關鍵字掃描未見把兩對當規則的斷言 |
| tests/unit/gameplay/cards/card_heal_and_buff_test.gd | 不受影響 | 關鍵字掃描未見把兩對當規則的斷言 |
| tests/unit/gameplay/cards/card_permanent_write_test.gd | **受影響(候選)** | 見「受影響明細」 |
| tests/unit/gameplay/cards/card_play_session_commit_entry_test.gd | 不受影響 | 關鍵字掃描未見把兩對當規則的斷言 |
| tests/unit/gameplay/cards/card_unplayable_reason_engine_test.gd | 不受影響 | 關鍵字掃描未見把兩對當規則的斷言 |
| tests/unit/gameplay/combat/combat_rules_guard_test.gd | 不受影響 | 關鍵字掃描未見把兩對當規則的斷言 |
| tests/unit/gameplay/narrative/support_conversation_record_test.gd | 不受影響 | 關鍵字掃描未見把兩對當規則的斷言 |
| tests/unit/gameplay/narrative/support_conversation_write_call_site_count_test.gd | 不受影響 | 關鍵字掃描未見把兩對當規則的斷言 |
| tests/unit/gameplay/tuning/affinity_tuning_test.gd | 不受影響 | 池/旋鈕/設定/本地化/游標/音效,affinity 僅為名稱或鍵名 |
| tests/unit/gameplay/tuning/card_modifier_tuning_test.gd | 不受影響 | 池/旋鈕/設定/本地化/游標/音效,affinity 僅為名稱或鍵名 |
| tests/unit/gameplay/tuning/combat_tuning_test.gd | 不受影響 | 池/旋鈕/設定/本地化/游標/音效,affinity 僅為名稱或鍵名 |
| tests/unit/gameplay/tuning/deck_tuning_test.gd | 不受影響 | 池/旋鈕/設定/本地化/游標/音效,affinity 僅為名稱或鍵名 |
| tests/unit/ui/affinity_line_shape_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/unit/ui/battle/battle_screen_guard_line_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/unit/ui/battle_screen_hand_bar_wiring_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/unit/ui/battle_screen_load_guard_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/unit/ui/battle_screen_preview_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/unit/ui/hand_bar_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |
| tests/unit/ui/relation_minimap_line_shape_test.gd | 不受影響 | 畫面/輔助程式;affinity 為欄位或呼叫名,斷言不依賴關係數量 |

## 受影響明細(8 支候選,實際改寫 6 支 + 新增 1 個 helper;2 支判定「不改」)
基線(改動前,同 worktree、HEAD 501cd75):2554 test cases | 0 errors | 0 failures | 0 orphans,ENGINE EXIT 0。

| 檔案 | 處置 | 原本保護什麼 | 改後仍保護 |
|---|---|---|---|
| battle_screen_card_deck_wiring_test | 改寫 | 開局灌入後 `_phi.links()` 與種子檔逐條一致(曾因弱斷言轉紅) | 同,期望由 `tests/helpers/affinity_seed_expectation.gd` 解析種子檔推導(條數+配對+極性),不寫死「2 條、1-2 正、3-4 負」;+1 敏感度證明(多一條麥子健線、極性反轉皆被比對器抓到) |
| battle_screen_campaign_affinity_ledger_seeding_test | 改寫 | ledger 注入為 null 時守衛整個跳過,links 恰為靜態種子 | 同,期望由種子檔推導;敏感度由 helper 的比對器證明(見上列,同一比對器) |
| battle_screen_campaign_mission_outcome_wiring_test | 改寫 | 第一次開局只有靜態種子關係 | 同,條數 = 種子檔解析條數 |
| campaign_support_conversation_carryover_test | 改寫 | 勝利前累積記錄只有起始關係、勝利後恰多 1 筆 SC-01 | 同,起始筆數 = 種子檔條數;`records[2]` 改 `records[seed_count]` |
| card_permanent_write_test | 改寫 + 新增 | 無關係線的配對(含戊)不在合法集合;合法集合恰 2 條 | 「10 組配對:合法 ⇔ 資料有線」逐組核對;`legal.size()==links.size()`;原本含戊/甲丙 5 條個別斷言保留。新增:含戊線的合成表上戊配對合法(對照,規格驗收(2))、非人設甲丙仍不合法。敏感度證明 3 條:真實實作通過、名字式排除戊 mutant 被抓、寫死兩對 mutant 被抓 |
| affinity_pool_write_port_test | 新增 | (既有 8c:無線配對含戊 → INVALID_PAIR,不動) | 新增對照:表裡有甲戊時經真實埠寫入 C1_C5 恰 1 筆、其餘 9 對 0 筆。敏感度證明不了:A 類(static 純函式 play,無繼承鏈可覆寫),理由寫在檔內 |
| affinity_link_test | 不改 | 斷言對象是種子檔內容(canon 守門:恰 2 條、戊無線,檔內明寫目的是讓人去讀 characters.md) | 屬 A′ 類(真實資料檔內容);它守的是種子資料而非「執行期只有兩對」,故保留 |
| card_target_selection_test | 不改 | 命中的「只有 2 張」是牌數、不是關係數;用合成 AffinityLink | 不受影響 |

另:story-012/013/014 已有非人設與含麥子健配對的斷言(relation_state_of_pair_test、position_chain_reads_relation_state_test 的 C2_C5),盤點確認其涵蓋,不重複新增。

## 揭露
- 不受影響欄的理由多為類別理由,**不是**逐檔逐行讀完 106 檔;依據是關鍵字掃描(兩對/只有 2/WU/legal_pairs/恰有 等)加對候選檔的讀碼。
- 新增 helper 與測試檔皆屬唯讀讀取 `assets/data/affinity/`(甲類例外),不證明種子檔內容正確性。
