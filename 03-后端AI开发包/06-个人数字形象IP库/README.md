# 个人数字形象 IP 库后端开发包

## 代码与设计入口

- 后端仓库：`G:\Go\xingyanshu-backend`
- 模块：`internal/modules/avatar`
- 迁移：`internal/database/migrations/000034_avatar_ip_library.sql` 至 `000045_avatar_face_identity_verification.sql`
- 主设计：`M:\工作目录\星恒云创\01-交付文档\v0.5\01-主设计文档\个人数字形象IP库_数据库与API详细设计.md`
- H5 契约：`M:\工作目录\星恒云创\02-原型\H5-个人数字形象采集\个人数字形象采集H5原型-静态版\H5接口契约_v1.0.md`
- 唯一 OpenAPI 源：`M:\工作目录\星恒云创\01-交付文档\v0.5\02-前端AI开发包\07-个人数字形象IP库独立H5开发包\Avatar_H5_OpenAPI_v1.yaml`
- H5 幂等与错误码：`M:\工作目录\星恒云创\01-交付文档\v0.5\02-前端AI开发包\07-个人数字形象IP库独立H5开发包\05-幂等与错误码契约.md`

## 已实现边界

- 全部数据独立于消费者端：`avatar_*` 表、`AVATAR_H5` 会话、验证码与素材元数据；
- 名单三要素匹配、采集授权、受控上传确认、测试环境归档、删除清除；H5 绑定请求提交姓名、性别和二维码短码，后端使用已短信验证手机号共同匹配后台实名核验通过的名单，不依赖 H5 实名核验记录；
- `AVATAR-OPS-01`：仅 `.xlsx` 的职业模特名单导入（无业务人数上限）、逐行错误回执、城市长期二维码短码、城市入口配置、脱敏名单/档案进度列表；
- `AVATAR-OPS-02`：平台管理员人工抽检/风险复核待办、5 分钟单次素材预览令牌、审核决定与审计；驳回后旧名单失效，允许重新导入建立全新档案；
- `AVATAR-H5-02`：加密体型资料、本人随时主动补采（单一进行中版本、无旧素材复用）及最新删除申请状态；
- Avatar H5 写接口已接入 MySQL 持久化幂等：相同键/请求重放首次结果，同键不同请求体返回 `IDEMPOTENCY_CONFLICT`；包括认证、授权、采集、上传凭证、素材确认、取消未确认上传、提交、补采、删除和体型资料。取消上传会立即释放 Redis 并发名额，10 分钟凭证过期仅作为异常退出兜底。
- 错误响应统一支持 `message`、`data.reasonCode`、`data.action` 和 `fieldErrors`。名单导入错误回执会给出行号与具体字段原因；扫码本人绑定可明确显示姓名、手机号、性别、实名状态或与本人导入行关联的校验失败原因，不返回其他人员资料或完整身份证号。
- 城市运营者本城市去标识化进度 CSV 导出；
- 平台管理员归档包导出申请、AES-256 加密 ZIP 生成、一次性密码展示、密码遗失后的撤销与重新生成。

## 严格禁止

- 生产环境注册任何 Mock 短信、实名、质检或归档成功路径；
- 用普通 ZIP、明文密码、公开对象地址或前端 Mock 替代受控归档包；密码仅保存密文且只可展示一次；
- 复用消费者 H5 账户、短信记录、文件公开下载接口，或将 `avatar_asset` 暴露给城市运营者。

## 运营名单模板与生产边界

- 统一模板：`M:\工作目录\星恒云创\01-交付文档\v0.5\01-主设计文档\个人数字形象IP库_运营模板\个人数字形象IP库_职业模特名单导入模板.xlsx`；表头固定为“姓名、身份证号、手机号、性别”，性别仅限男/女。
- 批量导入第一阶段仅做格式和重复校验，并将身份证号加密入库为 `PENDING_IDENTITY`；运营人员点击批次“立即执行实名核验”后，服务端仅在内存中解密姓名、身份证号、手机号并调用腾讯云 `PhoneVerification` 三要素核验（`avatar.roster_identity_provider=tencent_phone_verification`）。结果为 `0` 才转为 `ACTIVE`；不一致或服务异常均不放行。测试环境可保留 Mock。完整身份证号、腾讯云密钥及上游明文响应不得写入日志、错误回执、列表、导出或 H5 响应。
- 导入人数没有业务上限；当前接口在请求内解析 XLSX，部署时仍应按网关、内存和超时配置规划单文件容量。
- 二维码接口返回可供前端生成二维码图的长期短码，不保存或返回人员隐私信息。
- 运营端“发送短信提醒”只在测试环境有受控成功路径；生产环境未配置短信供应商时必须拒绝发送，不能伪造成功。

## 验收基线

## 腾讯云核验配置

名单三要素核验与采集后的人脸本人一致性核验共需以下 6 个环境变量；两类服务可复用同一对腾讯云 `SecretId`/`SecretKey` 值：

```text
XINGYANSHU_FACEID_PROVIDER=tencent_image_recognition_v2
XINGYANSHU_FACEID_SECRET_ID
XINGYANSHU_FACEID_SECRET_KEY
XINGYANSHU_FACEID_RSA_PUBLIC_KEY
XINGYANSHU_ROSTER_IDV_SECRET_ID
XINGYANSHU_ROSTER_IDV_SECRET_KEY
```

在 YAML 中将 `avatar.roster_identity_provider` 改为 `tencent_phone_verification`，并保持 `avatar.roster_identity` 的 `region: ap-guangzhou`、`verify_mode: "0"`、`timeout: 15s` 配置。人脸核验保留 `avatar.face_identity` 的环境变量引用。密钥不得写入 YAML、Git、日志、错误回执或任何前端响应。

在测试环境执行迁移后，设置 `XINGYANSHU_RUN_DB_TESTS=1`，真实 MySQL 8 + Redis 下运行：

```powershell
. .\scripts\use-go125.ps1
go test .\internal\database -run TestAvatarIPLibraryMigrationWithMySQL -count=1 -v
go test .\internal\modules\avatar -count=1 -v
```

至少覆盖二维码/短信 HTTP 注册、三要素绑定、归档、导出、删除清除、一次性密码展示与重新生成。

配置了测试 COS 私有桶时，可额外执行真实对象存储验收；该测试会创建并自动删除唯一临时源素材和结果 ZIP：

```powershell
$env:XINGYANSHU_RUN_COS_TESTS='1'
go test .\internal\modules\avatar -run TestAvatarArchivePackageWithRealCOS -count=1 -v
```
