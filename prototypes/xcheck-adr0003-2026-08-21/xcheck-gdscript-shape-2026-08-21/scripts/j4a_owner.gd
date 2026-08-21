# J4a —— 模擬 ADR-0002 的 AffinityDataPool:enum 巢狀在擁有者類別內
class_name JOwner extends RefCounted

enum ReadRejection { NONE, DATA_CORRUPTED, VERSION_TOO_NEW }
