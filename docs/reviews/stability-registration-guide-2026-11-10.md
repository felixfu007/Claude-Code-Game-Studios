# Stability AI 商用註冊指南(以管理者個人名義)

查詢日期:2026-11-10。作者:audio-director。
**本文不是法律意見。** 它只把查到的條文與白話放在一起,最後一句「我的單位算不算關係企業」要管理者自己判斷,必要時請法務或律師看。

## 〇、先講最重要的限制:本次查證有多可靠

本次只能用「網路搜尋」,看到的是**搜尋引擎產生的摘要**,**沒有能力打開並逐字讀完官方頁面**。所以本文每一條都標記來源類型:

- 【摘要】= 搜尋摘要轉述,不是我親眼讀到的條款全文,可能有誤。
- 【條款原文片段】= 摘要中以引號直接引出的條款字句(仍是經搜尋工具轉出,但字句為原文)。
- 【查不到】= 沒有任何來源給出。

**管理者在註冊當天,請自己打開下面第一條網址,以頁面上實際看到的為準。**

## 一、查證結果

| # | 問題 | 結果 | 等級 | 來源(查詢日 2026-11-10) |
|---|---|---|---|---|
| 1 | 註冊入口網址 | `https://stability.ai/community-license` | 【條款原文片段】條款寫「You must register with Stability AI at (https://stability.ai/community-license)」 | 摘要引自 [Stability AI Community License 副本(Wind River)](https://open.windriver.com/info/uni-license-list/licenses/stability-ai-community-2024.html);另見官方 [Select a license](https://stability.ai/license) |
| 2 | 註冊完成的畫面 | 有一個確認頁,寫「Your Stability AI Community License has been successfully activated」 | 【摘要】 | [community confirmation](https://stability.ai/community-confirmation) |
| 3 | 表單欄位 | 只查到「一份簡短表單,並填寫你最感興趣的模型」。**姓名、信箱、公司等具體欄位:查不到** | 【摘要】+【查不到】 | [Stability AI License Update](https://stability.ai/news/license-update)(經搜尋摘要) |
| 4 | 是否收費 | 年營收低於 100 萬美元者,研究、非商用、商用皆**免費**;超過才需付費的企業授權(Enterprise) | 【摘要】 | [License Update](https://stability.ai/news/license-update)、[Select a license](https://stability.ai/license) |
| 5 | 何時必須註冊 | 條款:若為「商業目的」使用或散布其材料,必須向 Stability AI 註冊 | 【條款原文片段】 | 同第 1 列 Wind River 副本 |
| 6 | 「商業目的」定義 | 研究或非商用以外、「主要意圖是為你或他人取得商業利益或金錢報酬」的目的 | 【摘要】 | 同上 |
| 7 | 營收門檻是否含 Affiliate | 多個來源說**含**:「被授權人或其 Affiliates」年營收超過 100 萬美元,授權即於當日終止,須另向 Stability AI 申請企業授權(對方可自行決定是否核准)。Wind River 副本也提到「licensee and its Affiliate(s)」,但摘要被截斷 | 【摘要】(Hugging Face 上某模型的授權副本 + 第三方整理) | [Hugging Face stable-audio-open-1.0 LICENSE](https://huggingface.co/stabilityai/stable-audio-open-1.0/blob/main/LICENSE.md)、[Licenseware 整理](https://wiki.licenseware.io/wiki/stability-ai-community-and-enterprise-license/) |
| 8 | 門檻怎麼算(只算與模型有關的營收,還是全部) | **兩種說法互相衝突**:Licenseware 說不論營收是否來自該材料都算;Stability 官方公告寫的是「超過 100 萬美元**且**把模型用在商業產品或服務」才需付費。哪一句對,以條款原文為準 | 【摘要】,有衝突 | [License Update](https://stability.ai/news/license-update) vs [Licenseware](https://wiki.licenseware.io/wiki/stability-ai-community-and-enterprise-license/) |
| 9 | 「Affiliate」在 Community License 的定義原文 | **未能確認。** Wind River 副本的定義只看到開頭「any entity that directly or ind…」被截斷。另一個模型(SV4D)的授權副本摘要顯示定義為「直接或間接控制、被控制、或與其處於共同控制下的任何實體,控制指持有超過 50% 表決權」——**這是別的模型的授權,不能直接當成本授權的定義** | 【查不到】完整原文;下方附上的是【摘要】 | [Hugging Face SV4D LICENSE](https://huggingface.co/stabilityai/sv4d/blob/main/LICENSE.md)、[Wind River 副本](https://open.windriver.com/info/uni-license-list/licenses/stability-ai-community-2024.html) |
| 10 | 目前適用的條款版本 | 搜尋結果中的「2024 Community License Agreement」,最後更新 2024-07-05。是否已有更新版:**未確認** | 【摘要】 | [Wind River 副本](https://open.windriver.com/info/uni-license-list/licenses/stability-ai-community-2024.html) |

## 二、請管理者自己判斷的一點:你的任職單位會不會被算成「Affiliate」

**白話先講結論的形狀,不是法律結論:**

1. 條款的 Affiliate 在查到的版本裡,講的是「**有控制關係**的實體」——控制別人、被別人控制、或跟別人受同一方控制,門檻是持有超過一半的表決權(以 SV4D 授權副本為準,待驗證是否與本授權相同)。
2. 營收門檻據稱是「你**加上**你的 Affiliates」合計超過 100 萬美元就失效。
3. 你以**個人名義**註冊。那麼要自問:
   - 你自己有沒有持股超過一半的公司?(那家公司會是你的 Affiliate。)
   - 你的任職單位,是**你控制**的嗎?或者**你被它控制**嗎?一般員工與雇主,在「持股/表決權」的字面意義上,通常不是控制關係——**但這是我的字面推測,不是結論**;條款是否把「雇傭關係」也算進去,要看完整原文。
   - 你的個人營收(薪水不算,通常指個人以遊戲或相關業務取得的收入)是否遠低於 100 萬美元?
4. 還有一個與營收門檻無關、但請管理者留意的問題:**用於商用的遊戲是由誰發行、誰收款**。若未來由公司名義發行,屆時「被授權人」可能就不是你個人了。
5. 另外,你的任職單位是否有規定員工的副業或創作需事先申報,屬公司規章,不是 Stability 條款的範圍,但同樣建議自己確認。

**建議:註冊前,把官方頁面上 Affiliate 那一段原文複製下來存檔(見第四節),必要時請法務或律師對照你的個人持股與任職關係判斷。**

## 三、在家照做的步驟

1. 用**家用電腦與家用網路**(不要用公司設備或公司信箱,以免被誤認為公司名義)。
2. 開啟 `https://stability.ai/community-license`。如果打不開或網址不同,從 `https://stability.ai/license` 找「Community」那一項。
3. **先不要填表。** 找到頁面上的授權全文或連結,把下列三處**整段複製**存成文字檔:
   - 「Affiliate」的定義
   - 「Commercial Purpose」的定義
   - 100 萬美元門檻那一條,以及註冊的規定
   同時記下頁面上標示的**版本日期**(例如是否仍是 2024-07-05)。
4. 讀完這三段,自己判斷第二節的問題。有疑慮就停下來,先問法務。
5. 填表單。已知的只有「要選你感興趣的模型」;其他欄位**我查不到**,請照實填寫,**身分一律填個人姓名、個人信箱**,公司欄若為必填,如實填寫「個人/無」之類並看頁面說明。不確定某一欄的意思就先截圖,不要猜。
6. 若是否收費的畫面出現任何付款要求,**停下來**——查到的資料說 100 萬美元以下免費,出現付款與此不符。
7. 送出後,應該會看到確認頁(寫「successfully activated」),通常也會寄確認信。**立刻截圖整個頁面**。
8. 在註冊表單上選的模型,要與實際打算使用的產品對得上。管理者要用的若是音訊模型(例如 Stable Audio 系列),註冊時要確認**該模型適用的是 Community License**,而不是另一份模型專屬授權(模型頁上會寫)。這一點我沒有查到,請留意。

## 四、做完要留存什麼(只建議,我不建立檔案)

建議在 `production/` 下建一個授權紀錄檔,例如 `production/licenses/stability-ai.md`(**建議路徑,尚不存在**),內容包括:

- 註冊日期、註冊所用的個人姓名與信箱(**不要寫密碼**)
- 註冊入口網址與當天頁面標示的條款版本日期
- 第三節步驟 3 複製下來的三段條款原文(Affiliate、Commercial Purpose、100 萬美元門檻)
- 確認頁截圖與確認信(原信存成檔,放在專案外的私人備份處亦可;截圖若放進專案,注意不要含個人隱私資訊)
- 註冊時選的模型,以及之後**實際用 Stability 模型產出的每一首曲子**的記錄:日期、使用的模型與版本、提示詞、檔名(日後被問「這首哪來的」才答得出來)
- 管理者自己對第二節的判斷與依據(一兩句即可,若諮詢過法務則記下日期與結論)
- 約定一個**每年複查日**:年營收是否接近門檻、條款是否有新版

## 五、查不到清單

- 註冊表單的**具體欄位**(姓名/信箱/公司等):查不到
- Community License 中「Affiliate」的**完整原文**:查不到(只有被截斷的片段與另一模型授權的定義)
- 官方頁面**今天**實際顯示的條款版本日期:未確認
- 「超過 100 萬美元」是否只算與模型相關的營收:**來源互相矛盾**,以條款原文為準
- 以個人名義註冊後,日後改由公司發行時授權如何轉移:查不到

## 六、來源清單

- [Stability AI Select a license](https://stability.ai/license)
- [Stability AI License Update](https://stability.ai/news/license-update)
- [Stability AI community confirmation](https://stability.ai/community-confirmation)
- [Community License 副本(Wind River)](https://open.windriver.com/info/uni-license-list/licenses/stability-ai-community-2024.html)
- [Stable Audio Open 1.0 LICENSE(Hugging Face)](https://huggingface.co/stabilityai/stable-audio-open-1.0/blob/main/LICENSE.md)
- [SV4D LICENSE(Hugging Face,僅作 Affiliate 定義的對照,非本授權)](https://huggingface.co/stabilityai/sv4d/blob/main/LICENSE.md)
- [Licenseware 整理(第三方)](https://wiki.licenseware.io/wiki/stability-ai-community-and-enterprise-license/)
