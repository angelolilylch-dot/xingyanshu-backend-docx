# 个人数字形象 IP 库：数据库与 API 详细设计

> 版本：设计稿 v1.5（表结构迁移、AVATAR_H5 第一阶段、`AVATAR-OPS-01` 城市运营接口、`AVATAR-OPS-02` 人工质检闭环及提交后腾讯云正面照本人一致性核验已实现）  
> 前置设计：[个人数字形象IP库_功能设计说明.md](./个人数字形象IP库_功能设计说明.md)  
> 首期范围：职业模特名单导入、短信通知、通用二维码、独立 H5 短信登录/名单绑定/采集授权、采集/质检/归档、本人补采和删除申请。  
> 不在首期：对外使用授权、公开发布、商业合作、模型训练、衍生内容生成。

> 已实现迁移：`G:\Go\xingyanshu-backend\internal\database\migrations\000034_avatar_ip_library.sql` 至 `000045_avatar_face_identity_verification.sql`。`000045` 为既有 `avatar_identity_verification` 补充档案、采集会话、素材、提供方结果码和相似度关联字段；已在本地 MySQL 8 测试库应用。

## 1. 建模约定

- 使用独立 `avatar_*` 表组；不复用 `consumer_account`、`auth_session`、`file_object` 和 `file_relation`。
- 沿用现有 MySQL 8、InnoDB、`utf8mb4`、雪花 ID、统一状态/版本/审计字段；不创建外键，逻辑关联在服务事务中校验。
- `sys_org.id` 只作为城市归属引用，`sys_user.id` 只作为后台操作人/审核人引用；不得因此获得原始素材访问权。
- 姓名、手机号、实名核验摘要、存储键等敏感字段使用密文列；检索使用不可逆哈希列；列表只返回脱敏值。
- `avatar_asset` 是唯一的敏感素材元数据入口。底层可复用对象存储能力，但不向普通文件模块登记，也不返回永久存储地址。
- 所有写接口均要求 `Idempotency-Key`，上传分片/直传凭证除外；同一键只可重放相同请求体。

### 1.1 通用状态与审计字段

下列核心表统一包含：`id`、`status`、`status_reason_code`、`status_reason`、`version`、`created_by`、`created_at`、`updated_by`、`updated_at`、`status_changed_at`、`status_changed_by_type`、`status_changed_by_id`。

核心对象状态变化同时写入既有 `biz_status_history`；敏感查看、签名 URL 签发、导出尝试和删除操作另写 `avatar_access_audit`。

## 2. 数据表字段设计

### 2.1 名单与注册入口

| 表 | 关键字段 | 约束、索引与说明 |
| --- | --- | --- |
| `avatar_roster_batch` | `batch_no`、`city_org_id`、`city_code`、`source_file_name`、`source_file_hash`、`total_count`、`success_count`、`failed_count`、`imported_by`、`imported_at` | `batch_no` 唯一；索引 `(city_org_id, created_at)`；状态：`IMPORTING/COMPLETED/PARTIAL_FAILED/FAILED`。`error_summary_json` 仅存概要。 |
| `avatar_roster_import_error` | `roster_batch_id`、`row_no`、`error_code`、`error_message` | 每个失败行一条受控错误明细；仅同城市运营者可下载为 XLSX 回执，不保存原始单元格内容。 |
| `avatar_roster_member` | `roster_batch_id`、`city_org_id`、`city_code`、`person_no`、`person_type`、`name_cipher`、`name_hash`、`id_number_cipher`（待实现）、`id_number_hash`（待实现）、`id_number_last4`（待实现）、`mobile_cipher`、`mobile_hash`、`mobile_masked`、`gender`、`import_identity_status`（待实现）、`bound_account_id`、`registration_status`、`profile_id` | `person_no` 唯一；活跃记录在同城市内 `(city_org_id, mobile_hash)` 唯一；目标规则是导入姓名、身份证号、性别、手机号并完成后台实名 Mock 后才导入。当前代码仅支持姓名、手机号、性别，身份证号字段与导入前实名核验待后端实现。跨城市同手机号不自动绑定，转平台人工处理。 |
| `avatar_sms_notification` | `notification_no`、`roster_member_id`、`mobile_hash`、`template_code`、`send_channel`、`send_status`、`provider_request_no`、`sent_at`、`retry_count`、`expire_at` | `notification_no` 唯一；发送内容仅含建档提醒与入口，不写实名或素材信息；索引 `(roster_member_id, created_at)`、`(mobile_hash, created_at)`。状态：`PENDING/SENT/DELIVERED/FAILED/CANCELLED`。 |
| `avatar_city_registration_config` | `city_org_id`、`city_code`、`support_contact_name`、`support_phone_cipher`、`support_phone_masked`、`updated_by` | 每城市一条当前有效配置；`city_org_id` 唯一；H5 仅返回脱敏联系电话与平台统一的保存期限说明。 |
| `avatar_registration_qrcode` | `qrcode_no`、`city_registration_config_id`、`city_org_id`、`city_code`、`code_hash`、`status`、`expires_at`、`scan_count`、`created_by` | `qrcode_no`、`code_hash` 唯一；城市长期通用码，默认 `expires_at=NULL`；二维码仅携带随机短码，不携带姓名、手机号或身份证信息；同城市同一时刻仅一条 `ACTIVE`；状态：`ACTIVE/PAUSED/REVOKED`，轮换后旧码撤销。 |
| `avatar_qrcode_scan_log` | `qrcode_id`、`scan_at`、`result_code`、`request_id`、`client_ip_hash`、`device_hash` | 只存摘要，不存完整 IP 或设备明文；索引 `(qrcode_id, scan_at)`；用于扫码次数、风控和异常排查。 |
| `avatar_h5_sms_code_log` | `mobile_hash`、`code_hash`、`scene`、`provider_request_no`、`expires_at`、`verified_at`、`attempt_count` | 独立 H5 登录验证码记录；不复用 `sms_code_log`；`scene` 首期固定 `AVATAR_LOGIN`；状态：`PENDING/SENT/VERIFIED/EXPIRED/FAILED/CANCELLED`。 |

### 2.2 独立 H5 账户与实名

| 表 | 关键字段 | 约束、索引与说明 |
| --- | --- | --- |
| `avatar_h5_account` | `account_no`、`mobile_cipher`、`mobile_hash`、`mobile_masked`、`last_login_at`、`current_roster_member_id` | `account_no`、`mobile_hash` 唯一；状态：`ACTIVE/SUSPENDED/DELETED`；该账户只用于 `AVATAR_H5`。 |
| `avatar_h5_session` | `account_id`、`session_no`、`refresh_token_hash`、`token_version`、`client_type`、`device_hash`、`last_used_at`、`expires_at`、`revoked_at` | `session_no`、`refresh_token_hash` 唯一；`client_type` 固定 `AVATAR_H5`；索引 `(account_id, status, expires_at)`；支持当前设备退出和刷新令牌轮换。 |
| `avatar_identity_verification` | `verification_no`、`roster_member_id`、`account_id`、`profile_id`、`collection_session_id`、`asset_id`、`provider_code`、`provider_request_no`、`provider_result_code`、`verification_type`、`face_similarity`、`response_digest`、`verified_at` | `verification_no` 唯一；不保存身份证正反面、姓名/身份证明文或人脸图片副本。导入名单核验与提交后 `FACE_IMAGE_1V1` 人脸核验保留独立历史；结果状态：`PENDING/PROCESSING/PASSED/REJECTED/ERROR`。``FACE_IMAGE_1V1`` 仅关联已确认的 `FACE_01`。 |

### 2.3 授权、档案与采集

| 表 | 关键字段 | 约束、索引与说明 |
| --- | --- | --- |
| `avatar_consent` | `consent_no`、`profile_id`、`account_id`、`consent_type`、`agreement_version`、`agreement_digest`、`purpose_snapshot`、`retention_days`、`retention_until`、`retention_notice_snapshot`、`signed_at`、`revoked_at`、`sign_ip_hash`、`device_hash` | `consent_no` 唯一；首期 `consent_type=COLLECT_AND_ARCHIVE`；首期 `retention_days` 固定为 `365`，`retention_until` 在首次归档时写入；每次补采沿用有效授权，授权撤回后禁止新采集；不创建对外使用授权记录。 |
| `avatar_profile` | `profile_no`、`roster_member_id`、`account_id`、`city_org_id`、`city_code`、`current_collection_session_id`、`current_version_no`、`real_name_status`、`collection_status`、`quality_status`、`archive_status`、`retention_until` | `profile_no` 唯一，`roster_member_id` 唯一；索引 `(city_org_id, archive_status, retention_until)`；到期转入清除/匿名化处理；档案状态：`NOT_STARTED/REAL_NAME_PENDING/CONSENT_PENDING/COLLECTING/SUBMITTED/AUTO_QUALITY_CHECKING/MANUAL_REVIEW/ARCHIVED/RESHOOT_REQUIRED/SUSPENDED/DELETION_REQUESTED/DELETED`。 |
| `avatar_collection_session` | `collection_no`、`profile_id`、`version_no`、`photo_required_count`、`photo_uploaded_count`、`video_required`、`video_uploaded`、`body_data_json_cipher`、`submitted_at`、`expires_at` | `(profile_id, version_no)` 唯一；状态：`DRAFT/COLLECTING/SUBMITTED/PROCESSING/PASSED/REJECTED/EXPIRED`；三围等资料存加密 JSON，不用于实名核验。 |
| `avatar_asset` | `asset_no`、`profile_id`、`collection_session_id`、`asset_type`、`capture_slot`、`storage_key_cipher`、`cipher_algorithm`、`key_reference`、`content_hash`、`mime_type`、`file_size`、`duration_seconds`、`quality_status`、`retention_until`、`purged_at` | `asset_no` 唯一；同一采集会话 `(asset_type, capture_slot)` 唯一；`asset_type=FACE_PHOTO/VOICE_VIDEO/BODY_DATA`；照片槽位 `FACE_01` 至 `FACE_08`；到期后由清理任务物理清除或不可逆匿名化；禁止查询返回 `storage_key_cipher`。 |

### 2.4 处理、审核、删除与访问审计

| 表 | 关键字段 | 约束、索引与说明 |
| --- | --- | --- |
| `avatar_processing_task` | `task_no`、`profile_id`、`collection_session_id`、`task_type`、`input_digest`、`provider_code`、`provider_request_no`、`attempt_count`、`next_retry_at`、`started_at`、`finished_at`、`error_summary` | `task_no` 唯一；任务类型：`PHOTO_QUALITY/VIDEO_QUALITY/ARCHIVE_ENCRYPTION`；索引 `(status, next_retry_at)`；状态：`PENDING/RUNNING/SUCCEEDED/FAILED/RETRY_WAIT/CANCELLED`。 |
| `avatar_quality_review` | `review_no`、`profile_id`、`collection_session_id`、`asset_id`、`review_type`、`review_result`、`reason_code`、`reason`、`reviewer_type`、`reviewer_id`、`reviewed_at` | `review_no` 唯一；自动审核可多条，人工终审每采集会话仅一条有效记录；结果：`PASSED/REJECTED/RESHOOT_REQUIRED`。 |
| `avatar_deletion_request` | `request_no`、`profile_id`、`account_id`、`request_reason`、`requested_at`、`decision`、`retention_exception_code`、`approved_by`、`approved_at`、`purged_at` | `request_no` 唯一；同一档案仅一张进行中申请；状态：`PENDING/APPROVED/REJECTED/PROCESSING/COMPLETED`；若依法保留，必须写入例外原因和截止时间。 |
| `avatar_access_audit` | `audit_no`、`actor_type`、`actor_id`、`actor_role`、`action`、`object_type`、`object_id`、`purpose_code`、`result`、`request_id`、`client_ip_hash`、`device_hash`、`created_at` | `audit_no` 唯一；索引 `(object_type, object_id, created_at)`、`(actor_id, created_at)`；必须记录素材预览、签名 URL 签发、实名结果查看、删除与审核操作。 |
| `avatar_export_job` | `job_no`、`export_type`、`requester_id`、`requester_role`、`city_org_id`、`purpose_code`、`filter_snapshot_json`、`file_key_cipher`、`file_hash`、`encryption_key_reference`、`password_cipher`、`password_revealed_at`、`replaces_export_job_id`、`invalidated_at` | 导出类型：`PROGRESS_LIST/ARCHIVE_PACKAGE`。城市运营者只能创建本城市 `PROGRESS_LIST`；`ARCHIVE_PACKAGE` 仅平台管理员且用途必填。归档包使用 AES-256 加密 ZIP，密码仅保存密文，首次展示即写入 `password_revealed_at`，不允许再次读取。重生成时旧任务转 `REVOKED`、旧下载立即失效，新任务独立生成密码。 |
| `avatar_export_item` | `export_job_id`、`profile_id`、`include_status`、`masked_snapshot_json`、`skip_reason_code` | 逐档案记录导出范围、脱敏快照和跳过原因；城市进度清单不包含姓名、手机号、实名结果或原始素材。 |

## 3. 关键逻辑约束

1. 扫通用二维码不创建账户、不改变名单状态；后台导入名单时完成 Mock 实名核验。H5 短信登录后提交姓名、性别，后端以姓名 + 登录手机号 + 性别与同一城市有效名单三项一致后创建/绑定 `avatar_h5_account`。任何一项不一致均返回统一拒绝结果和城市运营方完整联系电话，不暴露具体不一致项或他人名单信息。
2. 同一名单人员只能绑定一个有效 `avatar_h5_account`；同一账户不得自动跨城市绑定，跨城市冲突返回 `AVATAR_ROSTER_CITY_CONFLICT`。
3. 有效 `COLLECT_AND_ARCHIVE` 授权、三项名单绑定成功，二者同时满足才允许创建采集会话；名单的 Mock 实名核验由后台导入流程负责。
4. 自动质检通过即直接归档；仅质量异常、抽检命中或风控命中时创建人工复核任务，且仅平台管理员可受控预览。
5. 不采用永久保存：首期全部城市统一 `retention_days=365`，自档案首次归档时起算并固化至授权、档案和素材的 `retention_until`；到期自动进入清除或不可逆匿名化流程，授权撤回或删除申请可提前触发该流程。上线前须在个人信息保护影响评估和授权文本中明确处理必要性、留存规则及法定例外。
6. 每一采集版本必须完整拥有 8 个合格照片槽位和 1 个合格朗读视频，才允许提交；体型资料可空。
7. `ARCHIVED` 只在全部异步任务成功且质量审核通过时产生；审核驳回转 `RESHOOT_REQUIRED`，旧素材按保留策略隔离，不能被运营者访问。
8. 人工质检仅平台管理员可创建、预览和决定。预览令牌绑定管理员与单个素材，Redis 保存 5 分钟且使用一次即失效；不下发对象存储永久或预签名地址。
9. 人工质检 `REJECTED` 时，旧名单转为 `INACTIVE/REJECTED` 并保留审计；同城市同手机号随后可重新导入为新 ACTIVE 名单，再经过完整三要素匹配建立新档案，绝不复用旧档案或旧素材。
10. 删除申请生效后立即撤销素材访问签名；完成物理清除或不可逆匿名化后才转 `COMPLETED`。
11. 原始归档包生成使用私有对象存储读写：worker 以唯一测试/任务键读取已确认素材，写入 AES-256 加密 ZIP，包内所有素材与清单均加密；密码不进入对象、日志或返回下载接口。真实 COS 验收须使用显式环境开关并在测试结束后删除源对象与结果对象。
12. 所有九个必需槽位直传完成且已确认后，H5 才能提交采集。提交事务只创建一条自动质检任务；启用了 `avatar.face_identity` 时，同时创建 `FACE_IMAGE_1V1` 审计明细并将档案 `real_name_status` 置为 `PENDING`。自动质检 worker 优先在同一任务内原子领取该审计明细，在内存中解密名单姓名、身份证号和素材存储键，读取 `FACE_01`，调用腾讯云 `ImageRecognitionV2`，再继续素材质检；H5 不参与、也不接收这些明文。仅两步都通过才归档。
13. 调用腾讯云前，服务端对姓名和身份证号采用腾讯云配置的 RSA 公钥封装随机 AES-256-CBC 密钥和 IV，并通过 `Encryption` 传输密文；不记录明文、密钥、图片 Base64 或第三方完整响应。`Result=Success` 且相似度不低于 `70` 时为 `PASSED`，其他业务结果为 `REJECTED`，存储/参数/服务异常为 `ERROR`。H5 只从本人档案读取 `realNameStatus=PENDING/PASSED/REJECTED/ERROR`，不得显示相似度或底层原因。
14. 该能力通过 `avatar.face_identity` 配置启用，要求提供方为 `tencent_image_recognition_v2`、腾讯云凭据、RSA 公钥和超时配置。配置值仅从运行进程环境变量读取，配置模板、文档、日志和 Git 均不得写入密钥或真实身份数据；未配置时不创建人脸一致性任务，保留导入名单实名状态。

## 4. API 详细设计

接口前缀：`/api/v1`。后台接口使用既有后台鉴权与城市数据范围；H5 接口使用独立 `AVATAR_H5` JWT。除查询、上传凭证和刷新令牌外，写接口均要求 `Idempotency-Key`。

### 4.1 城市运营者后台

| 接口 | 请求关键字段 | 返回/规则 |
| --- | --- | --- |
| `GET /avatar/rosters/template` | 无 | **已实现（旧模板）**。当前模板为姓名、手机号、性别；待后端同步为姓名、身份证号、性别、手机号。 |
| `POST /avatar/roster-batches/import` | `multipart file` | **已实现（旧字段）**。当前仅校验姓名、手机号、性别及城市内手机号重复。目标规则：逐行完成后台实名 Mock，只有姓名、身份证号、性别、手机号一致且实名成功的行才导入；完整身份证号只存密文、不可逆哈希及末四位，绝不回传 H5。 |
| `GET /avatar/roster-batches` | 无 | **已实现**。返回最近 100 个本城市导入批次。 |
| `GET /avatar/roster-batches/{batchId}` | 无 | **已实现**。返回本城市批次统计、错误概要和处理状态。 |
| `GET /avatar/roster-batches/{batchId}/errors` | 无 | **已实现**。下载仅含原始行号、错误代码、错误说明的 XLSX 回执。 |
| `GET /avatar/roster-members` | 无 | **已实现**。返回最近 100 条本城市名单及脱敏姓名、手机号、注册状态、档案编号；不返回原始素材。 |
| `GET /avatar/roster-members/{memberId}` | 无 | 返回本城市人员详情和进度，不返回原始素材。 |
| `POST /avatar/roster-members/{memberId}/sms-notifications` | `templateCode?` | **已实现受限边界**。每人 24 小时限发一次并写通知记录；测试环境返回受控成功，生产环境未配置真实供应商时明确拒绝。 |
| `PUT /avatar/city-registration-config` | `supportContactName`、`supportContactPhone` | **已实现**。维护本城市长期建档入口和不匹配提示电话；号码加密存储，H5 返回完整联系电话与统一 1 年保存期说明。 |
| `POST /avatar/registration-qrcodes` | 无 | **已实现**。创建或轮换本城市长期通用二维码短码，默认无到期日；轮换时撤销旧有效码。前端以返回的短码渲染二维码图。 |
| `GET /avatar/registration-qrcodes` | 无 | **已实现**。查看最近 100 条本城市二维码及扫码统计。 |
| `POST /avatar/registration-qrcodes/{qrcodeId}/pause` | 无 | **已实现**。暂停二维码。 |
| `POST /avatar/registration-qrcodes/{qrcodeId}/resume` | 无 | **已实现**。恢复已暂停的城市长期二维码。 |
| `GET /avatar/profiles` | 无 | **已实现**。查看最近 100 条本城市档案进度，仅返回档案号、状态和保存截止时间。 |
| `POST /avatar/exports` | `exportType=PROGRESS_LIST`、筛选条件 | **已实现**。仅导出本城市去标识化进度清单；异步生成 CSV、文件 24 小时有效且单次下载。 |
| `GET /avatar/exports` / `GET /avatar/exports/{id}` | 分页 / 无 | **已实现**。城市运营者仅看本城市任务；平台管理员可查看全量任务。 |

### 4.2 平台管理员

| 接口 | 请求关键字段 | 返回/规则 |
| --- | --- | --- |
| `GET /avatar/quality-reviews/pending` | 无 | **已实现**。仅具备 `AVATAR_QUALITY_REVIEW` 权限的平台管理员查看最近 100 条待办。 |
| `POST /avatar/collection-sessions/{sessionId}/quality-reviews` | `reviewType=SAMPLE/RISK`、`reasonCode`、`reason?` | **已实现**。仅平台管理员可将已提交会话加入人工抽检/风险复核，并取消未执行自动质检任务。 |
| `POST /avatar/quality-reviews/{reviewId}/previews` | 无 | **已实现**。签发素材级、绑定管理员、5 分钟有效且仅可使用一次的预览令牌；经后台受控流读取私有对象。 |
| `GET /avatar/quality-previews/{token}` | 无 | **已实现**。消耗一次性预览令牌并返回素材流；前端应以带后台认证的请求读取，不缓存。 |
| `POST /avatar/quality-reviews/{reviewId}/decision` | `version`、`decision`、`reasonCode?`、`reason?` | **已实现**。`PASSED/REJECTED/RESHOOT_REQUIRED`；非通过必须填写原因码，决定、预览均审计。 |
| `GET /avatar/deletion-requests` | `status`、分页 | 删除申请待办。 |
| `POST /avatar/deletion-requests/{requestId}/decision` | `version`、`decision`、`retentionExceptionCode`、`reason` | 决定删除、拒绝或进入法定保留处理。 |
| `POST /avatar/exports` | `exportType=ARCHIVE_PACKAGE`、`purposeCode`、筛选条件 | **已实现**。仅平台管理员；worker 读取本城市已归档且可访问的原始素材，生成 AES-256 加密 ZIP、受控写入私有对象存储，并写入逐档案纳入/跳过审计。无可用素材或存储异常时任务失败，不生成 Mock 包。 |
| `POST /avatar/exports/{id}/password/reveal` | 无 | **已实现**。仅已成功生成的归档包、仅平台管理员；密码只返回一次，并写审计。 |
| `POST /avatar/exports/{id}/regenerate` | 无 | **已实现**。撤销旧包下载，创建替代归档任务；新任务完成后产生新的仅展示一次密码。 |

### 4.3 独立 AVATAR_H5

| 接口 | 请求关键字段 | 返回/规则 |
| --- | --- | --- |
| `GET /avatar/public/registration-context` | `code`（城市二维码短码） | **已实现**。返回城市编码、入口状态、完整运营方联系电话和 `retentionDays=365`；不泄露名单信息。 |
| `POST /avatar/auth/sms/send` | `mobile`、`scene=AVATAR_LOGIN` | **已实现**。独立 H5 登录码、Redis 60 秒限频；当前测试环境返回 `mockCode=123456`，非测试环境不注册 Mock 成功。 |
| `POST /avatar/auth/login` | `mobile`、`smsCode` | **已实现**。返回独立 `AVATAR_H5` access/refresh token；尚未匹配名单不等于登录失败。 |
| `POST /avatar/auth/refresh` | `refreshToken` | **已实现**。刷新并轮换独立会话令牌版本。 |
| `POST /avatar/auth/logout` | 无 | **已实现**。仅注销当前设备会话。 |
| `GET /avatar/profiles/me` | 无 | **已实现**。返回本人绑定后的档案、实名、授权与状态摘要；`summary.bodyDataFilled` 以当前会话已加密保存的体型资料为准，`submittedAt` 为当前会话提交时间；替代历史设计中的 `/avatar/me`。 |
| `POST /avatar/identity-verifications` | `verificationMethod=MOCK` | **仅测试辅助接口**。不再作为 H5 名单绑定前置条件；生产环境不注册 Mock 完成接口。 |
| `POST /avatar/test/identity-verifications/{id}/complete` | `name`、`gender`、`idNumberLast4?` | **仅 test 环境**。用于单独验证 Mock 实名接口，不接受完整身份证号。 |
| `GET /avatar/identity-verifications/latest` | 无 | **已实现**。返回本人最新 Mock 实名记录，不是绑定前置条件。 |
| `POST /avatar/roster-binding/confirm` | `registrationCode`、`name`、`gender` | **已实现**。以姓名、登录手机号、性别三项匹配已通过后台 Mock 实名核验的导入名单；成功绑定，失败不暴露具体不一致项或他人名单，并返回完整运营电话。 |
| `GET /avatar/consents/current` | 无 | 返回当前有效采集与入库协议版本、摘要和保存期限。 |
| `POST /avatar/consents` | `consentType`、`agreementVersion`、`accepted=true` | 仅允许 `COLLECT_AND_ARCHIVE`；保存协议摘要和签署证据。 |
| `POST /avatar/collection-sessions` | 无 | 创建/恢复当前采集版本；必须实名通过且授权有效。 |
| `POST /avatar/collection-sessions/{sessionId}/assets/upload-credentials` | `assetType`、`captureSlot`、`contentHash`、`mimeType`、`fileSize` | 签发一次性短时直传凭证，不返回永久对象地址。 |
| `POST /avatar/collection-sessions/{sessionId}/assets/confirm` | `assetType`、`captureSlot`、`uploadToken`、`contentHash` | 服务端校验对象大小、Hash、类型并写 `avatar_asset`。 |
| `PATCH /avatar/collection-sessions/{sessionId}/body-data` | `gender`、`heightCm`、`bodyType`、`bustCm?`、`waistCm?`、`hipsCm?` | **已实现**。可选资料加密写入当前会话；不用于实名。 |
| `POST /avatar/collection-sessions/{sessionId}/submit` | `version` | 校验 8 张照片与视频齐全，创建自动质检任务；通过即归档，异常/抽检/风控才创建人工复核。 |
| `GET /avatar/profiles/me` | 无 | 返回本人档案状态、当前版本、可补采原因、授权摘要，以及当前会话的照片数、视频数、体型资料已填写标记和提交时间。 |
| `POST /avatar/profiles/me/reshoot` | `reason` | **已实现**。仅 `RESHOOT_REQUIRED` 可补采；创建新的进行中版本，不复用旧素材。 |
| `POST /avatar/profiles/me/deletion-requests` | `reason` | 创建删除申请并立即停止新增采集与访问签名。 |
| `GET /avatar/profiles/me/deletion-requests/latest` | 无 | **已实现**。返回本人最新删除处理进度。 |

## 5. 错误码与并发规则

| 错误码 | 含义 |
| --- | --- |
| `AVATAR_QRCODE_INVALID` | 二维码无效、暂停、撤销或过期 |
| `AVATAR_ROSTER_FILE_REQUIRED` / `AVATAR_ROSTER_FILE_INVALID` / `AVATAR_ROSTER_HEADER_INVALID` | 未提交文件、非 `.xlsx`、或表头不是“姓名/手机号/性别” |
| `AVATAR_ROSTER_BATCH_NOT_FOUND` | 导入批次不存在或不属于当前城市 |
| `AVATAR_CITY_CONFIG_REQUIRED` | 尚未维护本城市建档入口联系电话，不能生成二维码 |
| `AVATAR_INVITATION_RATE_LIMITED` | 同一名单成员 24 小时内已发送提醒 |
| `AVATAR_ROSTER_MATCH_NOT_FOUND` | 姓名、手机号或性别无法完成三项名单匹配；响应不泄露具体不一致项或名单存在性，仅携带脱敏运营方联系电话 |
| `AVATAR_ROSTER_ALREADY_BOUND` | 名单已绑定其他有效 H5 账户 |
| `AVATAR_ROSTER_CITY_CONFLICT` | 账户已有其他城市有效绑定，需平台处理 |
| `AVATAR_CONSENT_REQUIRED` | 尚未同意当前采集与入库协议 |
| `AVATAR_COLLECTION_NOT_READY` | 照片/视频未齐全或质量未达标 |
| `AVATAR_ASSET_SLOT_CONFLICT` | 同采集版本同一素材槽位并发上传冲突 |
| `AVATAR_PROFILE_STATE_INVALID` | 当前档案状态不允许该操作 |
| `AVATAR_SENSITIVE_ACCESS_DENIED` | 无权访问实名结果或敏感素材 |
| `AVATAR_DELETION_IN_PROGRESS` | 删除申请处理中，禁止新采集/预览 |
| `AVATAR_EXPORT_PASSWORD_UNAVAILABLE` | 密码已展示、任务未完成或无可用密码；必须重新生成归档包 |
| `VERSION_CONFLICT` | 乐观锁版本不一致，前端刷新后重试 |

并发要求：同一名单绑定、同一采集版本的素材槽位确认、提交采集、质检终审、删除审批均在事务中按主记录加锁并校验 `version`；重复请求必须复用首次结果，不重复创建账户、素材、任务或删除单。

## 6. 开发前仍需固定的技术项

1. 第三方实名服务商、活体能力、回调验签和失败重试方案。
2. 素材加密方式与密钥托管方案；明确密钥轮换、失效和审计策略。
3. 照片、视频、音频的格式/大小/时长上限与质量算法供应商。
4. 统一 1 年保存期的个人信息保护影响评估、授权文本、删除申请 SLA 与依法保留例外清单。
5. 城市运营者、平台管理员对应的真实角色码和权限菜单。
