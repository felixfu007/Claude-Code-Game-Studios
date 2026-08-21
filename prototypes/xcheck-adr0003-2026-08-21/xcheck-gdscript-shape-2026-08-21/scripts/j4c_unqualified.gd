# J4c(隔離,預期失敗)—— ADR-0002 機制五第 415-416 行的逐字寫法,
#   若該類別被搬到自己的檔案並升為 class_name,ReadRejection 就是未限定名稱。
class_name JReadResultUnqualified extends RefCounted

var rejection: ReadRejection = ReadRejection.NONE
