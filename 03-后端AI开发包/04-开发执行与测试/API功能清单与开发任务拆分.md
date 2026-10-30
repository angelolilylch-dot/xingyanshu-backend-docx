# 星衍树版权二创平台一期 MVP API 功能清单与开发任务拆分

版本：v0.4  
状态：开发执行基线  
适用对象：后端开发、前端联调、测试、AI 辅助开发  
关联文档：[API接口设计说明.md](API接口设计说明.md)、[数据库设计说明.md](数据库设计说明.md)、[业务状态机与流转规则.md](业务状态机与流转规则.md)、[页面功能与字段清单.md](页面功能与字段清单.md)

## 1. 使用方式

本文件将 API 接口设计拆成可独立开发、测试、联调和验收的任务卡。每张任务卡交给 AI 或开发人员时，应连同本文件引用的 API、状态机和数据库文档一起提供。

### 1.1 任务卡固定交付要求

每个任务必须交付：

1. 路由、请求 DTO、响应 DTO、参数校验与 OpenAPI 注释；
2. 接口权限、数据范围、业务状态和乐观锁校验；
3. 主写表、关联校验表、异步/联动表的服务层事务逻辑；
4. 状态历史、审计日志和必要的敏感内容检测记录；
5. 单元测试、接口测试、主要失败场景测试和幂等测试；
6. 供前端联调的 Mock/测试数据与接口示例；
7. 将实现状态回填到本文件的任务状态列。

### 1.2 表类型说明

| 标记 | 含义 |
| --- | --- |
| 主写表 | 本任务直接创建或更新的核心业务表 |
| 关联校验表 | 只读验证存在性、权限、状态、余额、名额或规则的表 |
| 异步/联动表 | 由事务后事件、回调、定时任务或补偿任务创建/更新的表 |

所有 `*_id` 都是**逻辑关联**；MySQL 不创建 `FOREIGN KEY`。Go 服务层必须在同一事务中验证关联对象、状态和数据范围。

### 1.3 全部写接口通用约束

- 请求身份：后台/创作者/消费者使用 `Authorization: Bearer {accessToken}`；第三方回调使用 HMAC 签名；内部任务使用服务身份。
- 幂等：订单、支付、退款、发货、核销、结算付款等接口必须使用 `Idempotency-Key`。
- 并发：编辑/审核/状态变更使用 `If-Match-Version`；库存、名额和授权名额使用条件更新与预占记录。
- 文本：所有用户主动提交文字必须走第三方敏感内容检测；商品和活动检测不通过、疑似或异常均不可发布。
- 审计：写操作至少写 `biz_status_history` 和 `sys_audit_log`；文件下载、导出、外部回调同样留痕。
- 快照：合同、授权范围、商品/SKU、活动/场次/票种、售后模板、订单、退款、分账与结算均保存创建时快照。

## 2. 开发顺序与依赖

| 阶段 | 任务组 | 前置依赖 | 完成标志 |
| --- | --- | --- | --- |
| P0-1 | 公共基础与鉴权 | 无 | 可登录、鉴权、上传文件、写审计、返回统一错误 |
| P0-2 | 城市 IP 入库与固定方案 | P0-1 | 城市运营可录入、提交并查询本城市 IP，且可配置并绑定固定方案 |
| P0-3 | 版权合规确权与 IP 上架 | P0-2 | 版权/合规可审核、确权、上传报告并完成 IP 上架 |
| P0-4 | 授权购买与作品 | P0-3 | 创作者可实名、购买 IP、生成合同、提交并确权作品 |
| P0-5 | 商品、活动与公开 H5 | P0-4 | 商品二级审核发布、活动自动发布，游客可浏览 |
| P0-6 | 订单、预约、履约与售后 | P0-5 | 测试可模拟支付；生产可真实支付、发货、核销、退货退款 |
| P0-7 | 分账、结算、存证与看板 | P0-6 | 可计算分账、线下结算、真实存证和审计查询 |

## 3. 任务总览

| 编号 | 任务名称 | 优先级 | 主要接口数 | 依赖 | 建议状态 |
| --- | --- | --- | ---: | --- | --- |
| API-FND-01 | 鉴权、会话、RBAC 与数据范围 | P0 | 9 | 无 | 已完成（后台/创作者及消费者 H5 独立会话、刷新、注销、当前用户与权限隔离） |
| API-SYS-01 | 后台账号管理与跨域访问控制 | P0 | 5 + 公共 | API-FND-01 | 已完成 |
| API-SYS-02 | 组织管理、组织下拉与菜单授权初始化 | P0 | 6 + 公共 | API-FND-01、API-SYS-01 | 已完成 |
| API-FND-02 | 通用响应、错误码、幂等、状态与审计基座 | P0 | 公共 | API-FND-01 | 已完成 |
| API-FND-03 | 字典、标签、系统配置与固定规则模板 | P0 | 8 | API-FND-01 | 已完成 |
| API-FND-04 | 文件上传、权限下载与文件关联 | P0 | 3 | API-FND-01 | 已完成 |
| API-FND-05 | 外部服务适配器与安全回调框架 | P0 | 内部 | API-FND-01、API-FND-04 | 测试环境完成（TMS 真实；存证 Mock；真实链待服务商） |
| API-ID-01 | 创作者实名、委托书草稿/留存与账号状态 | P0 | 8 | API-FND-01、API-FND-04、API-FND-05 | 已完成（短信/实名 Mock；企业/工作室 Word 草稿自动生成） |
| API-IP-01 | IP 录入、编辑、提交与查询 | P0 | 6 | API-SYS-02、API-FND-03、API-FND-04 | 已完成 |
| API-IP-02 | IP 合规审核、DCI 处理、确权与存证 | P0 | 6 | API-IP-01、API-FND-05 | 已完成（测试环境 Mock 存证） |
| API-IP-03 | 授权方案与分配方案配置审核 | P0 | 10 | API-FND-03 | 已完成 |
| API-AUT-01 | 创作者 IP 商城与购买预览 | P0 | 3 | API-IP-02、API-IP-03、API-ID-01 | 已完成 |
| API-AUT-02 | 授权待支付订单、取消与名额预占 | P0 | 3 | API-AUT-01、API-FND-02 | 已完成 |
| API-AUT-03 | 测试 Mock 支付、授权生效、合同凭证与存证补偿 | P0 | 6 | API-AUT-02、API-FND-04、API-FND-05 | 已完成（生产微信支付另属 API-FND-05-R1） |
| API-AUT-04 | 授权素材包与下载权限 | P0 | 2 | API-AUT-03、API-FND-04 | 已完成（订单素材 Hash 快照、冻结/存证/授权下载与下载留痕） |
| API-CNT-01 | 二创作品提交、审核与确权 | P0 | 7 | API-AUT-04、API-FND-05 | 已完成（提交、文本检测、两级审核、退回新版本、确权快照与 Mock 存证） |
| API-CNT-02 | 商品提交、自动校验、发布与上下架 | P0 | 6 | API-CNT-01、API-FND-05 | 已完成：商品/SKU、自动检测记录、二级审核、下架新版本及真实 MySQL 验收 |
| API-CNT-03 | 活动提交、自动校验、暂停与下架 | P0 | 6 | API-AUT-04、API-FND-05 | 已完成：活动/场次/固定票种、授权范围与地区校验、文本检测自动发布、暂停/恢复/下架、自动结束及真实 MySQL 回归 |
| API-H5-01 | H5 公开浏览与客服信息 | P0 | 8 | API-CNT-02、API-CNT-03 | 已完成：匿名商品/活动浏览、稳定公开展示图、暂停报名活动展示、客服信息及真实 MySQL HTTP 回归 |
| API-H5-02 | 商品订单预览、库存预占与商品订单 | P0 | 8 | API-FND-01、API-CNT-02 | 待开发 |
| API-H5-03 | 活动预约、免费票与核销码展示 | P0 | 6 | API-FND-01、API-CNT-03 | 待开发 |
| API-FUL-01 | 发货、物流与签收 | P0 | 4 | API-H5-02、API-FND-05 | 已完成；物流回调入口改为后续兼容项 |
| API-FUL-02 | 现场核销与活动订单完成 | P0 | 3 | API-H5-03 | 待开发 |
| API-AFS-01 | 消费者售后申请、撤回与退货物流 | P0 | 6 | API-H5-02、API-H5-03、API-FND-04 | 待开发 |
| API-AFS-02 | 履约售后审核、财务退款与冲销 | P0 | 5 | API-AFS-01、API-AUT-03 | 待开发 |
| API-FIN-01 | 收款账户、自动分账、冻结与解冻 | P0 | 7 | API-FUL-01、API-FUL-02、API-AFS-02 | 待开发 |
| API-FIN-02 | 结算异议、结算批次与线下付款 | P0 | 7 | API-FIN-01、API-FND-04 | 待开发 |
| API-OPS-01 | 存证、检测、审计与导出 | P0 | 7 | API-FND-02、API-FND-04、API-FND-05 | 待开发 |
| API-OPS-02 | 集团经营、城市/IP、风险看板 | P1 | 3 | P0 全部 | 待开发 |
| API-OPS-03 | 定时任务、补偿任务与端到端验收 | P0 | 内部 | P0 全部 | 待开发 |

## 4. 公共基础任务

### API-FND-01 鉴权、会话、RBAC 与数据范围

- **接口范围：** `GET /auth/captcha`、`POST /auth/login`、`POST /auth/refresh`、`POST /auth/logout`、`GET /auth/me`、`POST /consumer/auth/sms/send`、`POST /consumer/auth/login`、`POST /consumer/auth/refresh`、`POST /consumer/auth/logout`、`GET /consumer/me`。
- **调用端/角色：** 管理后台、创作者后台、消费者 H5、游客。
- **主写表：** `sys_user`、`consumer_account`、`sms_code_log`、`sys_audit_log`；新增建议 `auth_session`（会话 ID、用户/消费者 ID、终端、刷新令牌 Hash、Token 版本、过期时间、状态）。
- **关联校验表：** `sys_user_role`、`sys_role`、`sys_permission`、`sys_org`、`creator_profile`。
- **异步/联动表：** `sys_audit_log`、会话缓存/黑名单缓存。
- **核心实现：** 短效 JWT + 刷新令牌轮换；Token 只含用户 ID、会话 ID、终端、Token 版本；服务端每次加载当前角色和数据范围。消费者使用独立 `CONSUMER_H5` 会话，登录必须记录协议同意版本和时间；Cookie 购物车合并随 API-H5-02 实现。
- **验收：** 停用创作者后旧会话立即无法访问写接口；城市运营读取其他城市 IP 返回 `AUTH_FORBIDDEN`；消费者无法调用后台接口；刷新令牌不可重复使用。

### API-SYS-01 后台账号管理与跨域访问控制

- **接口范围：** `GET /admin/accounts`、`POST /admin/accounts`、`GET /admin/accounts/{userId}`、`PATCH /admin/accounts/{userId}`、`PATCH /admin/accounts/{userId}/status`；公共 CORS 中间件无独立业务路由。
- **调用端/角色：** 统一管理后台；仅平台管理员可调用账号管理接口。CORS 仅服务已配置的管理后台和消费者 H5 前端来源。
- **主写表：** `sys_user`、`sys_user_role`。
- **关联校验表：** `sys_org`、`sys_role`、`auth_session`、`sys_audit_log`。
- **核心实现：** 新增账号时校验账号唯一、账号格式、初始密码、组织、唯一角色和数据范围；编辑仅允许修改显示名、手机号、组织、角色和数据范围，不修改登录账号；停用必须填写原因，并撤销该账号全部有效会话。跨域来源、方法和请求头由 `cors.allowed_origins` 控制，测试/开发环境允许 `*`，生产环境禁止 `*` 且必须配置精确来源，当前不启用跨域 Cookie 凭证。
- **验收：** 平台管理员可创建城市运营和版权/合规账号；非平台管理员调用返回 `AUTH_FORBIDDEN`；停用账号后旧访问令牌与刷新令牌均失效；测试环境任意浏览器来源可携带 `Authorization`、`X-Request-Id`、`Idempotency-Key`、`If-Match-Version`；生产环境仅允许配置的来源。

### API-SYS-02 组织管理、组织下拉与菜单授权初始化

- **接口范围：** `GET /admin/orgs`、`POST /admin/orgs`、`GET /admin/orgs/{orgId}`、`PATCH /admin/orgs/{orgId}`、`PATCH /admin/orgs/{orgId}/status`、`GET /admin/orgs/options`。登录后导航继续使用既有 `GET /auth/me`，不新增独立菜单接口。
- **调用端/角色：** 统一管理后台；组织维护仅平台管理员。`GET /admin/orgs/options` 供已登录的平台管理员在账号管理和组织管理页面取值。
- **主写表：** `sys_org`、`sys_audit_log`；补齐 `sys_permission`、`sys_role_permission` 的 MENU 权限种子。
- **关联校验表：** `sys_user`、`sys_user_role`、`sys_role`、`sys_permission`、`sys_org`。
- **核心实现：** 组织编码全局唯一，新增后不可修改；组织类型固定为 `GROUP`、`PLATFORM`、`CITY`。城市组织必须有有效上级组织和 `city_code`，非城市组织不允许填写 `city_code`；不允许形成组织循环。`orgs/options` 仅返回已启用组织的 `id`、`orgName`、`orgType`、`cityCode` 和层级信息，账号接口的 `orgId` 必须来源于此。菜单不由前端按角色写死：`/auth/me` 从角色权限关系返回可见菜单和操作权限；前端以 `resourceCode` 映射已固定的路由、图标、排序。补齐全部一期页面的 `MENU` 权限种子，确保各角色登录后有正确首个可见菜单。
- **验收：** 平台管理员可创建城市组织并将城市运营账号绑定到该组织；城市运营账号的 `CITY` 数据范围读取该组织 `cityCode`；组织编码、层级和城市编码校验可阻止非法数据；有启用账号或启用下级组织的组织不能停用；`/auth/me` 返回当前账号的菜单、权限与数据范围，前端不能仅凭固定角色名称显示菜单。

### API-FND-02 通用响应、错误码、幂等、状态与审计基座

- **接口范围：** 所有 API 的中间件/基础库，无单独业务页面接口。
- **主写表：** `biz_status_history`、`sys_audit_log`、`api_idempotency_record`；后续支付等业务表仍保留其自身业务幂等字段。
- **关联校验表：** 所有核心对象的 `status`、`version` 字段。
- **异步/联动表：** 审计归档、异常监控指标。
- **核心实现：** `000006_add_api_idempotency_record.sql` 与 `000007_allow_pending_idempotency_record.sql` 已建立幂等记录表及处理中状态支持。写接口按“主体 + HTTP 方法 + 路径 + 幂等键”唯一定位；同一请求的 SHA-256 不同即冲突，首次响应快照与主业务写入在同一个 MySQL 事务中提交，记录默认保留 24 小时。`internal/platform/state` 提供显式状态机守卫，`internal/platform/audit` 在业务事务中写状态历史、审计并脱敏敏感字段，`internal/platform/httpx` 统一解析 `If-Match-Version` 及映射幂等/状态错误码。
- **验收：** 真实 MySQL 集成测试已验证首次执行、同键同请求重放和同键不同请求冲突；非法状态流转可统一返回 `422 STATE_TRANSITION_NOT_ALLOWED`。后续订单、支付、退款、发货、核销、结算与存证重试必须调用此执行器，不得自行实现幂等表写入。

### API-FND-03 字典、标签、系统配置与固定规则模板

- **接口范围：** `GET /dictionaries/{dictType}`、`GET /public/regions`、`GET /tags`、`GET/POST/PATCH /admin/tags`、`GET/POST/PATCH /admin/regions`、`GET/PATCH /admin/configs`、`GET/POST/PATCH /admin/after-sale-templates`。
- **主写表：** `sys_dict_item`、`sys_config`、`after_sale_rule_template`。
- **关联校验表：** `sys_user`、`sys_role`、`product_version`、`activity_version`。
- **异步/联动表：** `sys_audit_log`、`biz_status_history`。
- **核心实现：** `bootstrap` 按“字典类型 + 稳定编码”幂等补齐 IP 类型、授权方式、售后类型、DCI 状态等固定枚举，既不覆盖已有值，也不提供后台编辑入口；平台管理员在 A05 的“地区管理”“标签管理”选项卡维护四类 IP 标签和地区主数据，在“平台参数”选项卡维护白名单内的非敏感配置。地区层级由六码行政区划编码推导。外部密钥仍只由私有配置文件管理，不通过接口写入。模板不提供原地编辑：`000008_after_sale_template_versioning.sql` 将唯一约束调整为“模板编号 + 版本号”，新版本创建时自动停用旧版本，历史商品/活动仍通过模板 ID 和规则快照追溯旧规则。
- **验收：** 真实 MySQL 集成测试已验证地区公开查询、标签停用隐藏、平台配置读取、模板新版本创建及旧版本自动停用；商品/活动后续只能选择已启用且适用业务一致的模板。

### API-FND-04 文件上传、权限下载与文件关联

- **接口范围：** `POST /files`、`GET /files/{fileId}`、`POST /files/{fileId}/download-url`。
- **主写表：** `file_object`、`file_relation`、`material_download_log`、`sys_audit_log`。
- **关联校验表：** `creator_authorization`、`auth_contract`、`ip_asset`、`derivative_work`、`after_sale_ticket`、角色与数据范围表。
- **异步/联动表：** `biz_status_history`、`sys_audit_log`；存证和素材授权校验由后续业务模块联动。
- **核心实现：** 使用腾讯云 COS 私有测试桶。上传前按运行时策略校验扩展名、探测 MIME 与单文件大小，图片默认 10MB、文档 30MB、媒体 200MB；ZIP 等白名单外文件在访问 COS 前拒绝。文件流上传时同步计算 SHA-256，并以 `fileId` 生成不暴露给前端的 COS 存储键。上传策略从 YAML 配置文件每 2 秒检查一次，合法变更原子生效，失败配置保留旧策略；Bucket、密钥和连接配置不热加载。业务模块只调用内部 `LinkToObject` 写 `file_relation`，不保存 `storage_key`。下载地址默认有效 10 分钟，每次签发写审计。
- **验收：** 已使用真实 COS 测试桶完成 JPG 上传、测试库元数据写入和短期下载地址签发；超限图片与 ZIP 自动化测试均在存储前被拦截。后续 `API-AUT-04` 将在授权失效时收紧素材包下载权限，`API-H5` 将为公开图片提供消费者可见性校验。

### API-FND-05 外部服务适配器与安全回调框架

- **当前阶段范围与状态：** 部分完成。已交付腾讯云文本内容安全真实 Adapter、存证 Provider 框架，以及供 API-FUL-01 调用的腾讯云云市场物流查询 Adapter；短信、支付、电子签章及物流回调仍在对应业务模块开发。文件存储已由 API-FND-04 接入真实腾讯云 COS 私有测试桶。
- **接口范围：** 内部 `ContentSafetyProvider`（已完成，腾讯云 TMS `TextModeration`）、`EvidenceProvider`（框架已完成，真实链服务商待确定）及 `LogisticsProvider.Query`（已完成，腾讯云云市场快递查询）；存证回调 `POST /integrations/evidence/callbacks` 和物流回调待对应服务商签名规范及业务路由确定后实现。
- **主写表：** 后续 IP 业务调用时写 `content_detection_record`、`evidence_record`、`evidence_retry_log`；当前适配器本身不提供前端可调用路由，也不伪造业务记录。
- **关联校验表：** `sys_config`、`file_object`、所有受检测/存证对象。
- **异步/联动表：** `sys_audit_log`、存证失败重试队列（在 IP 确权模块接入）。
- **核心实现：** 腾讯云 TMS 使用 `BizType=ip_center`、`ap-guangzhou` 和同步 `TextModeration`；`Pass` 映射为 `PASS`，`Review` 或未知建议映射为 `REVIEW`，`Block` 映射为 `BLOCK`。物流 Adapter 请求 `https://ap-guangzhou.cloudmarket-apigw.com/service-d2zdkymg/express/query`，使用 `code=auto`、`no`、`tel`（后四位）及云市场 HMAC-SHA1 `Authorization`；`code="0"` 为成功，`logisticsStatus="SIGN"` 为签收，轨迹时间为毫秒。物流密钥只从 `XINGYANSHU_LOGISTICS_SECRET_ID`、`XINGYANSHU_LOGISTICS_SECRET_KEY` 读取。业务文本、命中词、运单完整手机号和密钥不写普通日志。存证只有收到真实服务的可验证回执且状态为 `SUCCESS` 才可推进业务状态。
- **验收：** 已通过真实腾讯云测试凭据完成正常中文文本检测；物流 Adapter 已使用真实圆通运单返回派送中状态和 9 条轨迹，且未记录密钥或完整个人信息；敏感检测超时或异常必须阻断提交；未配置真实链服务或无回执时不得标记存证成功。

## 5. IP 与授权方案任务

### API-ID-01 创作者实名、委托书与账号状态

- **接口范围：** `POST /creator/auth/sms/send`、`POST /creator/auth/register`、`POST /creator/identity-verifications`、`GET /creator/identity-verifications/latest`、`GET /creator/authorization-letter-draft`、`POST /creator/files`、`POST /creator/authorization-letters`、`GET /creator/authorization-letter-template`、`PATCH /admin/creators/{creatorId}/status`。
- **主写表：** `sys_user`、`creator_profile`、`creator_identity_verification`、`creator_authorization_letter_draft`、`creator_authorization_letter`。
- **关联校验表：** `sms_code_log`、`file_object`、`auth_session`、`sys_org`。
- **异步/联动表：** `content_detection_record`（委托书说明等文字）、`sys_audit_log`、实名适配器回执。
- **核心实现：** 个人/企业/工作室均第三方自动核验；企业/工作室核验通过后，以企业名称、登记证号、主体类型、生成日期自动生成私有 Word 委托书草稿并签发本人短链；草稿仅供补全、盖章、签字，不等同留存。短链过期通过读取接口刷新，复用同一草稿；签署件可选上传留存，不需要平台管理员确认；不支持一期内修改实名主体信息或多账号。
- **验收：** 未认证可浏览 IP 商城但无法购买；企业/工作室认证通过后即可购买，委托书不影响购买；平台停用后所有新增业务写接口拒绝。

### API-IP-01 IP 录入、编辑、提交与查询

- **接口范围：** `GET /ips`、`POST /ips`（可在同一事务创建 DCI 代办）、`GET /ips/{ipId}`、`PATCH /ips/{ipId}`、`POST /ips/{ipId}/dci-assistance-requests`（已保存 IP 的补申请）、`GET /admin/dci-assistance-requests`、`POST /admin/dci-assistance-requests/{requestId}/handle`、`POST /ips/{ipId}/submit`、`GET /ips/{ipId}/review-records`。
- **主写表：** `ip_asset`、`ip_right_holder`、`ip_right_document`、`ip_dci_assistance_request`、`ip_auth_binding`、`ip_review_record`、`file_relation`。
- **关联校验表：** `sys_org`、`auth_plan`、`auth_plan_version`、`finance_distribution_plan`、`file_object`、`creator_profile`。
- **异步/联动表：** `content_detection_record`、`biz_status_history`、`sys_audit_log`。
- **核心实现：** 仅城市运营录入本城市 IP；一个 IP 仅一个原始权利人；DCI 证书缺失时可保存并提交代办联系请求，DCI 未上传不得提交审核；城市运营从已启用模板中初选授权方案和分账结构模板，并为模板全部参与方填写该 IP 的期望比例。草稿初选写入 `ip_draft_auth_selection`，不提前写入确权后的正式 `ip_auth_binding`；提交前检测所有文本、校验版权文件、文件状态、授权方案和模板匹配关系。
- **验收：** 城市运营无法操作其他城市；草稿创建、方案参与方比例保存、DCI 代办、无 DCI 拦截提交、补齐 DCI 后提交合规审核已通过真实 MySQL 集成测试；审核退回后只能在补充材料状态修改。

### API-IP-02 IP 合规审核、DCI 处理、确权与存证

- **接口范围：** `GET /compliance/dci-assistance-requests`、`POST /compliance/dci-assistance-requests/{requestId}/handle`、`POST /compliance/dci-assistance-requests/{requestId}/application-package`、`POST /ips/{ipId}/dci-verifications`、`POST /ips/{ipId}/rights-reviews`；评估报告接口复用 `POST /ips/{ipId}/evaluation-reports`。
- **主写表：** `ip_dci_assistance_request`、`ip_review_record`、`ip_auth_binding`、`ip_distribution_item`、`ip_asset`、`evidence_record`。
- **关联校验表：** `ip_right_document`、`ip_evaluation_report`、`auth_plan_version`、`finance_distribution_plan`、`finance_distribution_plan_item`、`file_relation`、`file_object`。
- **异步/联动表：** `biz_status_history`、`sys_audit_log`、`content_detection_record`；存证服务失败时不推进 `LISTED`。
- **核心实现：** 版权/合规读取完整 DCI 联系方式并记录无明文审计，处理代办状态；可生成私有 ZIP 资料包，内含 Markdown 申请资料、作品说明、权属证明和作品附件，评估报告可选附带。先核验 DCI，再确权或退回补充。退回理由必填。确权时可确认或调整最终方案和比例，先生成快照并获得测试 Mock 存证成功回执及链上交易/存证哈希，再写正式 `ip_auth_binding`，并在同一事务中将 IP 自动置为 `LISTED`、设置商城可见；确权响应返回 `evidenceTransactionHash` 供 B03 展示和复制。
- **验收：** 不存在 IP 直接“审核驳回”终态；退回必须有理由；无存证成功回执不得确权或上架；暂停、恢复、下架接口均已独立实现，风险处置按当前范围暂缓。

### API-IP-03 授权方案与分配方案配置审核

- **接口范围：** `GET/POST /auth-plans`、`GET /auth-plans/{planId}`、`PATCH /auth-plans/{planId}/draft`、`POST /auth-plans/{planId}/submit|reviews|enable|disable`、`GET/POST /distribution-templates`、`GET/PATCH /distribution-templates/{templateId}`、`PATCH /distribution-templates/{templateId}/status`。
- **主写表：** `auth_plan`、`auth_plan_version`、`finance_distribution_plan`、`finance_distribution_plan_item`。
- **关联校验表：** `ip_auth_binding`、`sys_dict_item`、`sys_user_role`。
- **异步/联动表：** `biz_status_history`、`sys_audit_log`、`content_detection_record`。
- **核心实现：** 平台管理员维护固定授权方案草稿、启停和分账结构模板；版权/合规仅审核授权方案。普通授权与独家买断的模板类型必须匹配。模板只保存全部必选的参与方，不填写比例也不需要审核；城市运营在 API-IP-01 选择模板后，为每一方填写该 IP 的期望比例且合计 100%，版权/合规在 API-IP-02 确认或调整 IP 专属比例。授权方案或模板一旦被 IP 绑定，禁止修改、停用、删除。
- **验收：** 已绑定方案或模板操作返回 `AUTH_PLAN_BOUND_LOCKED`；买断费用模板不含创作者；城市运营只能读取/选择启用方案和模板，不能创建；真实 MySQL 集成测试覆盖模板结构、授权模板关联与模板锁定。

## 6. 授权购买与创作任务

### API-AUT-01 创作者 IP 商城与购买预览

- **接口范围：** `GET /creator/ip-mall`、`GET /creator/ip-mall/{ipId}`、`GET /creator/ip-mall/{ipId}/purchase-preview`。
- **主写表：** 无主写表；查询可写访问审计。
- **关联校验表：** `ip_asset`、`ip_auth_binding`、`auth_plan_version`、`finance_distribution_plan_item`、`creator_profile`、`creator_authorization`。
- **异步/联动表：** `sys_audit_log`（敏感详情/合同预览访问可选）。
- **核心实现：** 仅返回已上架、商城可见、未售罄、未暂停、未失效且未买断 IP；筛选不提供“剩余名额”条件；普通授权仅展示创作者与平台比例。
- **验收：** 消费者 H5 不可调用；未认证创作者可浏览但预览 `canPurchase=false`；已买断、售罄 IP 不出现在列表。

### API-AUT-02 授权待支付订单、取消与名额预占

- **接口范围：** `POST /creator/auth-orders`、`GET /creator/auth-orders/{authOrderId}`、`POST /creator/auth-orders/{authOrderId}/cancel`。
- **主写表：** `auth_order`；新增建议 `auth_quota_reservation`（IP/方案、订单、数量、过期时间、预占状态）。
- **关联校验表：** `creator_profile`、`creator_identity_verification`、`creator_authorization_letter`、`ip_asset`、`ip_auth_binding`、`auth_plan_version`、`creator_authorization`。
- **异步/联动表：** `biz_status_history`、`sys_audit_log`、支付超时关闭任务。
- **核心实现：** 校验实名、IP 上架、名额、同一 IP 无有效授权和合同勾选；企业委托书草稿或签署留存均不是购买前置。事务中创建待支付订单、购买快照、30 分钟名额预占。取消/超时释放预占。
- **验收：** 并发下最后一个名额只允许一个订单创建成功；相同幂等键不重复预占；已支付订单不可取消；到期后原购买人可按届时方案再次购买但不能同时有两笔有效授权。

### API-AUT-03 测试 Mock 支付、授权生效、合同凭证与存证补偿

- **接口范围：** `POST /payments/mock/pay`（仅 test 环境）、`GET /creator/authorizations`、`GET /creator/authorizations/{authorizationId}`、`GET .../contract`、`GET .../certificate`，以及合同生成和存证补偿任务。生产微信支付接口、验签回调和主动查单归 `API-FND-05-R1`。
- **主写表：** `payment_transaction`、`auth_order`、`creator_authorization`、`auth_contract`、`auth_certificate`、`auth_scope_snapshot`。
- **关联校验表：** `auth_quota_reservation`、`auth_plan_version`、`ip_asset`、`creator_profile`。
- **异步/联动表：** `evidence_record`、`biz_status_history`、`sys_audit_log`、合同文件生成任务、商城可见性更新（买断）。
- **核心实现：** 下单时将买方、IP、方案、授权范围、分账与权利说明完整写入订单；Mock 支付事务原子完成支付流水、订单 `PAID`、名额转正式占用、授权及范围记录、合同生成任务。事务提交后，任务只读取订单内容生成合同与授权凭证并自动发起存证；生成或存证失败均不回滚支付和授权，按退避策略重试。
- **验收：** 同一微信支付流水或重复回调不会生成两份合同/授权；支付成功后合同不可修改且授权可查；买断后其他创作者无法浏览或下单；待支付满 30 分钟主动关单并释放名额。

### API-IP-04-R 入库素材包、DCI 提交包锁定、确权存证与冻结

- **接口范围：** 在 IP 新增/编辑、DCI 代办申请、版权/合规确权接口中补充素材包提交、状态查询与写入限制；不提供已冻结 IP 的素材包更新接口。
- **主写表：** `ip_material_pack`、新增建议 `ip_material_pack_item`、`ip_dci_assistance_request`、`evidence_record`、`ip_review_record`。
- **关联校验表：** `ip_asset`、`file_object`、`file_relation`、`ip_right_document`、`ip_auth_binding`。
- **异步/联动表：** 文件 Hash、素材包清单 Hash、存证提交/回执、`biz_status_history`、`sys_audit_log`。
- **核心实现：** 入库阶段一次性提交完整素材包及素材项；对固定排序后的文件 Hash 与交付范围生成清单 Hash。申请 DCI 代办时锁定提交包及该 Hash；补正必须退回/终止后新建请求。DCI `VERIFIED`、IP 确权通过以及 IP 关键材料/素材包存证均 `SUCCESS` 后，在状态推进中将素材包冻结并上架 IP。冻结后禁止原 IP、素材包和素材项的修改、删除、替换、追加或版本覆盖；新增/修正素材只能新建 IP 确权记录。
- **验收：** 代办中无法提交审核或上架；清单 Hash 与素材项可复算一致；无回执不得冻结/上架；已冻结 IP 的所有写入口均拒绝；合同/授权范围可追溯引用素材包清单 Hash。

### API-AUT-04 合同、凭证、范围快照与素材下载

- **接口范围：** `GET /creator/authorizations`、`GET /creator/authorizations/{authorizationId}`、`GET /creator/authorizations/{authorizationId}/contract`、`GET /creator/authorizations/{authorizationId}/certificate`、`GET /creator/authorizations/{authorizationId}/material-packs`、`POST /creator/authorizations/{authorizationId}/material-downloads`。
- **主写表：** `material_download_log`、`sys_audit_log`。
- **关联校验表：** `creator_authorization`、`auth_contract`、`auth_certificate`、`auth_scope_snapshot`、`ip_material_pack`、`ip_material_pack_item`、`file_object`。
- **异步/联动表：** `evidence_record`、文件签名 URL 服务。
- **核心实现：** 只返回当前用户的授权；合同、凭证和范围读取不可修改；素材只在授权 `ACTIVE`、素材包 `FROZEN` 且素材包存证 `SUCCESS` 时可下载，短期签名 URL 不暴露存储键；下载响应和日志携带素材包清单 Hash。
- **验收：** 授权到期/解除后历史合同仍可查看，但素材下载接口返回 `AUTHORIZATION_EXPIRED`；素材包未冻结或未存证成功时拒绝下载；下载日志包含授权、合同、文件、素材包清单 Hash、用户、IP、时间和结果。

### API-CNT-01 二创作品提交、审核与确权

- **接口范围：** `GET /creator/works`、`POST /creator/works`、`GET /creator/works/{workId}`、`POST /creator/works/{workId}/resubmit`、`GET /copyright/works/pending`、`POST /copyright/work-versions/{workVersionId}/reviews`、`POST /copyright/works/{workId}/rights-confirmations`。
- **主写表：** `derivative_work`、`work_version`、`work_file`、`work_review_record`、`work_rights_confirmation`、`file_relation`。
- **关联校验表：** `creator_authorization`、`ip_asset`、`auth_scope_snapshot`、`file_object`、`content_detection_record`。
- **异步/联动表：** `content_detection_record`、`evidence_record`、`biz_status_history`、`sys_audit_log`。
- **核心实现：** 无草稿；每次退回/驳回/异常后新建版本。作品文本检测通过进入版权初审；疑似风险允许版权/合规人工复核；确权后生成编号、Hash 和真实存证。
- **验收：** 无有效授权无法提交；原创与权利声明未全部确认不能提交；商品查询候选作品时只返回已确权作品；检测不通过不能绕过进入人工审核。

### API-CNT-02 商品提交、自动校验、发布与上下架

- **接口范围：** `GET/POST /creator/products`、`GET/PATCH /creator/products/{productId}`、`POST /creator/products/{productId}/delist`、`GET /copyright/products/pending`、`POST /copyright/product-versions/{productVersionId}/reviews`。
- **主写表：** `product`、`product_version`、`product_sku`、`content_publish_record`、`file_relation`。
- **关联校验表：** `creator_authorization`、`auth_scope_snapshot`、`derivative_work`、`work_rights_confirmation`、`after_sale_rule_template`、`file_object`。
- **异步/联动表：** `content_detection_record`、`evidence_record`、`biz_status_history`、`sys_audit_log`。
- **核心实现：** 商品必须关联有效授权和已确权作品；服务端校验授权边界、作品、SKU、价格、库存、运费和售后模板，并同步审核提交文本及封面、详情、SKU 配图和图片类附件。检测 `PASS/REVIEW` 进入版权初审，初审通过进入合规复核，仅复核通过发布；`BLOCK` 或调用异常进入 `CHECK_REJECTED/CHECK_ERROR` 且不进入人工待办。退回、驳回、检测失败可覆盖当前未发布版本；下架后重提新建版本。
- **验收：** 提供版权初审、合规复核接口；检测拦截或异常不进入人工审核；售罄商品保留公开展示但不可下单；发布后的历史订单仍读取下单版本快照。

### API-CNT-03 活动提交、自动校验、暂停与下架

- **接口范围：** `GET /creator/activities`、`POST /creator/activities`、`GET /creator/activities/{activityId}`、`POST /creator/activities/{activityId}/pause-booking`、`POST /creator/activities/{activityId}/resume-booking`、`POST /creator/activities/{activityId}/delist`。
- **主写表：** `activity`、`activity_version`、`activity_session`、`activity_ticket_type`、`content_publish_record`、`file_relation`。
- **关联校验表：** `creator_authorization`、`auth_scope_snapshot`、`after_sale_rule_template`、`activity_booking`、`file_object`。
- **异步/联动表：** `content_detection_record`、`evidence_record`、`biz_status_history`、`sys_audit_log`、活动结束任务。
- **核心实现：** 活动无需关联二创作品，但授权必须有效、允许活动且覆盖实际举办城市；举办地区不可全国。票种从固定字典 ACTIVITY_TICKET_TYPE 选择，票种名额和不得超过场次总名额。文本检测 PASS 自动发布；不做图片检测或人工发布审核；发布后名称、地点、日期、场次、票种、票价、名额和规则锁定。
- **验收：** 真实 MySQL 回归已覆盖付费/免费早鸟票、暂停/恢复、有成功报名禁止下架、无成功报名下架和活动自动结束；免费票价格必须为 0。

## 7. 消费者交易与履约任务

### API-H5-01 H5 公开浏览与客服信息

- **接口范围：** `GET /public/home`、`GET /public/products`、`GET /public/products/{productId}`、`GET /public/activities`、`GET /public/activities/{activityId}`、`GET /public/service-contact`、`GET /public/media/{fileId}`；消费者 H5 不提供 IP 资源或 IP 字段。
- **主写表：** 无；可选写公开访问统计/审计。
- **关联校验表：** `ip_asset`、`product`、`product_version`、`product_sku`、`activity`、`activity_version`、`activity_session`、`activity_ticket_type`、`sys_config`。
- **异步/联动表：** 公开访问指标、`sys_audit_log`（异常/限流时）。
- **核心实现：** 仅返回公开且有效对象；商品地区筛选显示指定地区与全国商品，不限制购买；活动按实际地区显示。消费者只看通俗版权说明。
- **验收：** 公开接口不泄露合同、权利证明、实名、内部分账、审核意见、存证技术回执；下架/暂停/失效内容不出正常列表。

### API-H5-02 消费者商品订单、微信支付与确认收货

- **接口范围：** `POST /consumer/product-orders/preview`、`POST /consumer/product-orders`、`GET /consumer/product-orders`、`GET /consumer/product-orders/{orderId}`、`POST /consumer/product-orders/{orderId}/cancel`、`POST /consumer/product-orders/{orderId}/confirm-receipt`、`GET /consumer/product-orders/{orderId}/logistics`、共用生产接口 `POST /payments/wechat-h5/initiate`；`POST /payments/mock/pay` 仅测试环境使用。
- **主写表：** `product_order`、`product_order_item`、`product_stock_reservation`、`payment_transaction`、`consumer_address`。
- **关联校验表：** `consumer_account`、`product`、`product_version`、`product_sku`、`after_sale_rule_template`、`delivery_order`、`logistics_event`。
- **异步/联动表：** `biz_status_history`、`sys_audit_log`、支付超时任务、订单自动完成/分账任务。
- **核心实现：** 预览/下单都重算价格、库存、运费和规则；创建待支付订单时原子预占 SKU 库存，30 分钟超时释放。支付成功进入待发货，签收后消费者确认或售后保护期结束自动完成。
- **验收：** Cookie 购物车不锁库存；同一幂等键不重复预占；售后中不能确认收货；订单快照保存商品、SKU、价格、运费、地区和售后规则。

### API-H5-03 活动预约、免费票、支付与核销码展示（已完成）

- **接口范围：** `POST /consumer/activity-bookings/preview`、`POST /consumer/activity-bookings`、`GET /consumer/activity-bookings`、`GET /consumer/activity-bookings/{bookingId}`、`GET /consumer/activity-bookings/{bookingId}/verification-code`、`POST /consumer/activity-bookings/{bookingId}/cancel-pending-payment`、共用生产接口 `POST /payments/wechat-h5/initiate`；`POST /payments/mock/pay` 仅测试环境使用。
- **主写表：** `activity_booking`、`activity_quota_reservation`、`payment_transaction`、`verification_code`。
- **关联校验表：** `consumer_account`、`activity`、`activity_version`、`activity_session`、`activity_ticket_type`、`after_sale_rule_template`。
- **异步/联动表：** `biz_status_history`、`sys_audit_log`、支付超时任务、活动结束过期任务。
- **核心实现：** 收费票创建预占；免费票直接占用名额并生成核销码；支付成功预占转正式占用。核销码只对待核销预约展示。
- **验收：** 预约可跨地区但仅实际地点参加；已核销不展示可退款入口；活动结束未核销转已过期，不退款、不分账；票种名额并发不超卖。

### API-FUL-01 发货、物流与签收回调

- **接口范围：** `GET /fulfillment/shipments`、`POST /fulfillment/product-orders/{orderId}/shipments`、`GET /fulfillment/delivery-orders/{deliveryId}`、`POST /integrations/logistics/callbacks`。
- **主写表：** `delivery_order`、`logistics_event`、`product_order`。
- **关联校验表：** `product_order_item`、`product`、`creator_profile`、`sys_user`、`file_object`。
- **异步/联动表：** `evidence_record`、`biz_status_history`、`sys_audit_log`、订单自动完成任务。
- **接口范围：** `GET /fulfillment/shipments`、`POST /fulfillment/product-orders/{orderId}/shipments`、`GET /fulfillment/delivery-orders/{deliveryId}`、`GET /consumer/product-orders/{orderId}/logistics`、`POST /consumer/product-orders/{orderId}/confirm-receipt`。
- **核心实现：** 仅待发货订单可由具有 `FULFILLMENT_SHIPMENT_MANAGE` 的履约客服发货；发货写入 `delivery_order` 并更新订单为 `SHIPPED`。Worker 用已验证的腾讯云云市场 Adapter 轮询、对 `delivery_id + event_no` 幂等落 `logistics_event`；`SIGN` 推进发货单和订单为 `SIGNED`。消费者只能查询本人订单，确认收货和同键重放均被后端校验；签收 7 天且无进行中售后自动完成。后台列表一律脱敏地址和运单号。
- **验收：** 已完成真实 MySQL 发货→模拟物流签收→消费者查询→确认收货，以及签收超过 7 天自动完成测试；腾讯云云市场真实圆通单号查询已返回派送中 9 条轨迹。当前生产路径为后端轮询；`POST /integrations/logistics/callbacks` 未实现，不得对外开放。

### API-FUL-02 现场核销与活动订单完成

- **接口范围：** `GET /fulfillment/activity-bookings`、`POST /fulfillment/verifications/preview`、`POST /fulfillment/verifications`。
- **主写表：** `verification_record`、`verification_code`、`activity_booking`。
- **关联校验表：** `activity`、`activity_session`、`activity_ticket_type`、`consumer_account`、`sys_user`、`file_object`。
- **异步/联动表：** `finance_share_record`、`finance_share_item`、`evidence_record`、`biz_status_history`、`sys_audit_log`。
- **核心实现：** 校验核销码、预约状态、活动、场次、票种和未使用状态；成功后核销码永久失效，预约完成并触发普通授权分账。
- **验收：** 重复核销返回已核销且不重复分账；核销失败可记录异常但不改变预约完成状态；核销人员、地点、时间和凭证完整留痕。

## 8. 售后、退款与财务任务

### API-AFS-01 消费者售后申请、撤回与退货物流

- **接口范围：** `POST /consumer/after-sales/product`、`POST /consumer/after-sales/activity`、`GET /consumer/after-sales`、`GET /consumer/after-sales/{afterSaleId}`、`POST /consumer/after-sales/{afterSaleId}/withdraw`、`POST /consumer/after-sales/{afterSaleId}/return-logistics`。
- **主写表：** `after_sale_ticket`、`after_sale_evidence`、`return_logistics`。
- **关联校验表：** `product_order`、`product_order_item`、`activity_booking`、`after_sale_rule_template`、`delivery_order`、`verification_record`、`file_object`。
- **异步/联动表：** `finance_share_record` 冻结、`biz_status_history`、`sys_audit_log`、`evidence_record`。
- **核心实现：** 商品仅取消退款/退货退款；活动仅取消退款且已核销/已过期拒绝。创建售后时锁定规则、订单、退货地址和可退金额快照；同一对象的冲突售后不允许并行。
- **验收：** 已发货商品不能直接仅退款；退货地址由履约方式自动锁定；消费者只能查看本人售后；撤回后正确恢复订单可继续履约状态和可解冻金额。

### API-AFS-02 履约售后审核、财务退款与分账冲销

- **接口范围：** `GET /fulfillment/after-sales`、`POST /fulfillment/after-sales/{afterSaleId}/review`、`POST /fulfillment/after-sales/{afterSaleId}/return-receipt-confirmation`、`GET /finance/refunds`、`POST /finance/refunds/{refundId}/review`、内部 `PaymentProvider.refund`（测试 Mock、生产微信支付 V3 退款 API）。
- **主写表：** `after_sale_ticket`、`refund_order`、`finance_reversal_record`、`finance_share_record`、`finance_share_item`。
- **关联校验表：** `return_logistics`、`after_sale_rule_template`、`payment_transaction`、`product_order`、`activity_booking`、`finance_share_record`。
- **异步/联动表：** `payment_transaction`、库存/名额恢复任务、`evidence_record`、`biz_status_history`、`sys_audit_log`。
- **核心实现：** 履约客服审核并确认退货收件；财务复核最终金额并发起微信支付退款；退款成功更新售后、订单/预约，生成同比例分账冲销。退款失败不得完成售后。
- **验收：** 客服不可绕过财务直接退款；部分退款只冲销对应订单项/票种；退款幂等；已核销活动预约不能进入退款流程。

### API-FIN-01 收款账户、自动分账、冻结与解冻

- **接口范围：** `GET /creator/payout-accounts`、`POST /creator/payout-accounts`、`GET /admin/creator-payout-accounts`、`POST /admin/creator-payout-accounts/{accountId}/verify`、`GET /creator/revenue-shares`、`GET /finance/revenue-shares`、`POST /finance/revenue-shares/{shareId}/freeze`、`POST /finance/revenue-shares/{shareId}/unfreeze`。
- **主写表：** `creator_payout_account`、`finance_share_record`、`finance_share_item`。
- **关联校验表：** `creator_profile`、`creator_authorization`、`product_order`、`activity_booking`、`finance_distribution_plan`、`finance_distribution_plan_item`、`refund_order`。
- **异步/联动表：** `finance_reversal_record`、`biz_status_history`、`sys_audit_log`、分账计算任务。
- **核心实现：** 商品订单完成或活动核销成功自动计算普通授权分账；运费排除；退款同比例冲销；售后/风险/异议冻结。独家买断只处理买断费用分配，后续商品/活动仅记录创作者自有收入。
- **验收：** 创作者只看自己的明细及创作者/平台展示比例；城市运营保留收益分成但不参与内容创建/审核；冻结明细无法入结算批次；金额四舍五入差额归平台服务费。

### API-FIN-02 结算异议、结算批次与线下付款

- **接口范围：** `POST /creator/settlement-disputes`、`GET /finance/settlement-disputes`、`POST /finance/settlement-disputes/{disputeId}/resolve`、`POST /finance/settlement-batches`、`GET /finance/settlement-batches`、`GET /finance/settlement-batches/{batchId}`、`POST /finance/settlement-batches/{batchId}/review`、`POST /finance/settlement-batches/{batchId}/payments`。
- **主写表：** `settlement_dispute`、`finance_settlement_batch`、`finance_settlement_item`、`finance_share_item`。
- **关联校验表：** `finance_share_record`、`creator_payout_account`、`creator_profile`、`file_object`、`refund_order`。
- **异步/联动表：** `sys_audit_log`、`biz_status_history`、`evidence_record`。
- **核心实现：** 仅待结算、未冻结、未冲销且收款账户已核验的分账项可入批；财务复核后线下付款，上传凭证后更新明细已结算。创作者异议可冻结关联金额。
- **验收：** 创建批次不等于已付款；付款凭证缺失不能标记完成；部分付款批次正确返回部分完成；异议解决后按结论解冻或调整。

## 9. 运维、存证与验收任务

### API-OPS-01 存证、检测、审计与导出

- **接口范围：** `GET /evidence-records`、`POST /admin/evidence-records/{evidenceId}/retry`、`POST /integrations/evidence/callbacks`、`GET /content-detections`、`GET /audit-logs`、`POST /exports`、`GET /exports/{exportId}`。
- **主写表：** `evidence_record`、`evidence_retry_log`、`content_detection_record`、`sys_audit_log`、`sys_export_record`。
- **关联校验表：** `file_object`、`file_relation`、所有 IP/合同/作品/商品/活动/订单/售后/分账对象、`sys_role_permission`。
- **异步/联动表：** 文件 Hash、上链提交/回执、导出文件生成、下载记录。
- **核心实现：** 存证状态严格区分待摘要、待上链、上链中、成功、失败；成功必须有回执。检测列表只显示类别和脱敏摘要。导出按权限、范围、脱敏等级和有效期生成短期文件。
- **验收：** 无回执不允许标记上链成功；重试完整记录；普通用户不可读取审计日志；导出、下载、重试均留痕。

### API-OPS-02 经营、城市/IP 与风险看板

- **接口范围：** `GET /dashboard/overview`、`GET /dashboard/city-ip`、`GET /dashboard/risks`。
- **主写表：** 无主写表；可写查询审计、报表缓存。
- **关联校验表：** `ip_asset`、`creator_authorization`、`derivative_work`、`product`、`activity`、`product_order`、`activity_booking`、`after_sale_ticket`、`refund_order`、`finance_share_record`、`finance_settlement_batch`、`evidence_record`、`content_detection_record`。
- **异步/联动表：** 聚合任务/缓存、`sys_export_record`。
- **核心实现：** 指标口径统一以状态机为准：商品完成、活动核销、退款、冻结、结算、上链成功/失败都按状态字段聚合。城市运营只能读本城市，集团管理层全平台只读。
- **验收：** 聚合金额与订单/分账明细抽样可对账；角色无法看到越权城市或敏感个人数据；筛选条件不允许任意 SQL 字段。

### API-OPS-03 定时任务、补偿任务与端到端验收

- **接口范围：** 无公开接口；内部服务任务与健康检查接口。
- **主写表：** `auth_order`、`product_order`、`activity_booking`、`auth_quota_reservation`、`product_stock_reservation`、`activity_quota_reservation`、`creator_authorization`、`activity`、`evidence_record`、`evidence_retry_log`、`finance_share_record`。
- **关联校验表：** 支付流水、库存/名额、授权状态、售后/退款、分账和存证对象。
- **异步/联动表：** `biz_status_history`、`sys_audit_log`、重试队列、告警指标。
- **核心实现：** 待支付 30 分钟关闭与释放；授权到期；活动结束未核销过期；商品签收售后保护期自动完成；敏感检测/存证补偿；订单完成和核销后的分账计算。
- **验收：** 每个任务可重复执行且不重复释放/扣减/分账；可模拟时间推进；失败可重试并有告警；端到端覆盖 IP→授权→作品→商品/活动→交易→履约→退款→结算→存证主链路。

## 10. AI/开发人员单任务提示词模板

以下模板用于把单张任务卡交给 AI 或开发人员，方括号替换为本文件实际内容：

```text
请实现 [任务编号]：[任务名称]。

先阅读：
1. API功能清单与开发任务拆分.md 中 [任务编号]；
2. API接口设计说明.md 中列出的接口及第 2.6、3、14 章；
3. 业务状态机与流转规则.md 中关联对象状态机；
4. 数据库设计说明.md 和 数据库字段字典.xlsx 中涉及的数据表和字段。

实现要求：
- 只实现本任务列出的接口与直接依赖；不要扩展一期外功能。
- 数据库不使用物理外键；在 Go 服务事务中校验全部逻辑关联。
- 严格实现角色、数据范围、状态前置、乐观锁、幂等、审计与敏感数据脱敏。
- 所有用户提交文本按要求调用敏感内容检测；商品应进入版权初审、合规复核，活动不得加入人工发布审核。
- 为成功、权限拒绝、状态冲突、并发/幂等和主要业务失败场景写测试。
- 输出：变更文件清单、接口示例、测试结果、未解决的外部配置项。
```

## 11. 完成定义与联调顺序

### 11.1 单任务完成定义

任务只有同时满足以下条件才可从“待开发”更新为“已完成”：

1. 所列接口都能在本地/测试环境访问；
2. 主写表、关联校验表和异步联动表逻辑完整；
3. 权限、数据范围、状态机、幂等和审计测试通过；
4. 前端页面可完成对应操作并正确展示状态/错误；
5. 不引入草稿、人工活动审核、发票、改期、真实支付等一期外能力；商品采用已确认的二级审核；
6. OpenAPI 注释、错误码和 Mock 示例同步更新。

### 11.2 最小联调主链路

```text
后台登录
→ 城市运营录入 IP
→ 版权/合规确权并自动上架
→ 创作者注册、实名、购买授权、微信支付
→ 合同/凭证/素材可查
→ 创作者提交作品并确权
→ 创建商品并经二级审核发布
→ 消费者登录、下单、微信支付
→ 发货、签收、确认收货
→ 自动分账、财务结算、付款凭证
```

活动分支：

```text
有效授权
→ 创作者创建活动并自动发布
→ 消费者收费或免费预约
→ 生成核销码
→ 履约客服现场核销
→ 自动分账与结算
```

## 2026-10-29：API-H5-公共接口与订单契约修复（已实现）

- `GET /public/regions` 的 `level` 统一归一为大写层级，兼容旧 H5 的小写和 `1/2/3/4`；`parentCode` 去首尾空格后再过滤。
- `GET /consumer/product-orders` 和 `GET /consumer/activity-bookings` 接受可选 `status` 精确过滤，返回对象统一为 `data.items`、`data.total`，禁止继续返回裸数组。
- 公共商品/SKU 的可购买字段被强制序列化为 JSON boolean；SKU `spec` 归一为对象，历史 `null`/`"null"` 转为 `{}`。
- 商品订单与活动预约的 HTTP 集成测试增加：缺少 `Idempotency-Key` 返回 400、`status` 真正过滤列表、列表对象封装；基础数据测试增加地区过滤参数兼容。普通模块测试不连接数据库，真实 MySQL 验收仍需显式设置 `XINGYANSHU_RUN_DB_TESTS=1`。

## 2026-10-29：API-FND-DICT-01 活动票种字典（已实现）

- 新增迁移 `000046_seed_activity_ticket_types.sql` 与 Bootstrap 默认值：`GENERAL` 普通票、`VIP` VIP票、`STUDENT` 学生票、`FREE` 免费票。升级时旧的默认票种统一停用，不删除历史数据。
- 平台管理员新增 `ACTIVITY_TICKET_TYPE_MANAGE` 权限与 A10 菜单 `MENU_PLATFORM_ACTIVITY_TICKETS`；接口为 `GET /admin/activity-ticket-types`、`PATCH /admin/activity-ticket-types/{ticketTypeCode}`。更新只允许启停和排序，要求乐观锁版本及操作理由。
- 基础数据真实 MySQL 集成测试覆盖票种全量查询、大小写编码更新、停用和排序；Bootstrap 单测锁定四个初始票种和 A10 菜单。

售后分支：

```text
消费者申请售后/取消退款
→ 履约客服审核或确认退货
→ 财务复核并发起微信支付退款
→ 库存/名额恢复（适用时）
→ 分账冲销
→ 售后完成
```
