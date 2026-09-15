# AffinityRecord —— Delta Log 單筆記錄的型別化容器(恰 5 個欄位)。
#
# 設計文件:design/gdd/affinity-data-pool.md
#   - Core Rules #1(資料結構,五欄定義)
# 治理 ADR:docs/architecture/adr-0002-affinity-data-pool-data-structure-and-concurrency-contract.md
#   - 機制二(Delta Log 儲存,欄位表)
#   - 機制八(欄位型別與型別檢查順序——序列化時的邊界)
# Story:production/epics/affinity-data-pool/story-002-affinity-record.md(S-002)
#
# 🔴 本 story 只交付欄位本身,直接回應 TR-affinity-001 對「須用具型別類別而非
# Array[Dictionary]」的要求。to_dict()/from_dict() 序列化方法屬 S-013(持久化,
# 切片外),本檔刻意不實作 —— 但欄位須與 ADR-0002 機制八的欄位表(pair/m/t/c/source
# 恰 5 個)完全一致,避免 S-013 落地時發現欄位對不上。
#
# 驗收依據:ADR-0002 Validation Criteria 第 11 項(見 EPIC.md「三張零 AC 的
# story」段落)—— 本類別不對應本系統 GDD 的任一條 AC,那是 ADR 層構造。
class_name AffinityRecord
extends RefCounted

## 這筆記錄所屬的配對(見 [AffinityTypes.Pair])。寫入前的合法性檢查
## (非法序數拒絕)屬池的職責(S-004),本類別本身不驗證任何欄位。
var pair: AffinityTypes.Pair

## 帶號幅度——非零有限浮點數。正負號承載好感度變化的方向,絕對值承載幅度。
var m: float

## 全域好感度寫入計數器值——寫入時由池指派,恆 ≥ 1。
var t: int

## 戰役刻度計數器值——寫入當下的現值,恆 ≥ 0。
var c: int

## 這筆記錄的來源類別(見 [AffinityTypes.Source])。
var source: AffinityTypes.Source
