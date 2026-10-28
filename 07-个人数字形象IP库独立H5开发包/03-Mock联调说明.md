# Mock 联调说明

## 环境边界

Mock 仅在后端 `test` 环境注册。前端通过部署环境配置启用测试联调页；不得凭客户端开关在生产环境伪造成功。

| 能力 | 当前 Mock 行为 | 前端处理 |
| --- | --- | --- |
| 短信 | `POST /avatar/auth/sms/send` 返回 `data.mockCode="123456"` | 测试页可回填，生产 UI 不显示。 |
| 实名 | 创建 `PENDING` 后调用 test 完成接口，传姓名、性别 | 仅用于与后端名单三要素绑定联调。 |
| 质检 | 后端 worker 在 test 环境执行归档状态流转 | 前端只轮询档案状态，不本地改状态。 |
| 提交后本人一致性核验 | 已配置腾讯云人脸核身时，自动质检 worker 优先以确认的 `FACE_01` 串行执行 | H5 只轮询 `realNameStatus`，不调用腾讯云、不伪造通过。 |

> 生产环境提示：H5 不调用 Mock 实名接口。名单已由后台在导入时完成实名核验，H5 提交姓名、性别，后端结合已短信验证的手机号完成绑定。采集提交后的正面照一致性核验仅由后端 worker 调用腾讯云；H5 不传身份证号，也不直连该服务。所有写操作均必须携带 `Idempotency-Key`；重试须复用键和原请求体。

测试用例必须覆盖：二维码无效或城市暂停、短信限频（读取 `retryAfter`）、姓名/手机号/性别不匹配、授权未同意、照片或视频未齐（读取 `missingSlots`）、质检处理中、补采、删除处理中、token 刷新失效和重复点击；同时验证成功外层码为字符串 `OK`、照片槽位为 `FACE_01` 至 `FACE_08`、视频为 `VOICE_VIDEO`、上传凭证字段为 `uploadURL`、照片仅 `image/jpeg` 且最大 8 MiB、视频仅 `video/mp4` 或 `video/webm` 且最大 60 MiB。相同键和请求体须返回 `Idempotency-Replayed: true`，不同请求体同键必须为 `409 IDEMPOTENCY_CONFLICT`。

本地联调可使用后端 `test.yaml` 的 `file.storage.provider: mock`。若服务器测试需要让后台通用文件继续使用 COS、但仅个人形象素材绕过 COS CORS，则保留 `file.storage.provider: cos`，并在 `avatar.asset_storage` 配置 `provider: mock`、服务器磁盘目录和浏览器可访问的 `mock_upload_base_url`。此时上传凭证会返回 `http://服务器地址/api/v1/mock-storage/upload?...`；H5 仍按 `PUT + headers.Content-Type + 原始 File/Blob` 上传。后端测试 CORS 已允许 `http://localhost:5273` 与 `http://127.0.0.1:5273`。该 Mock 仅用于测试，不能作为生产 COS 直传或生产验收依据。
