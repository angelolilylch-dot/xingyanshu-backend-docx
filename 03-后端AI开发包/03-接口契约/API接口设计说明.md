# 星衍树版权二创平台一期 MVP API 接口设计说明

版本：v0.4  
协议：HTTPS + REST JSON；文件上传使用 `multipart/form-data`  
API 前缀：`/api/v1`  
依据：[一期MVP需求基线与范围说明.md](一期MVP需求基线与范围说明.md)、[业务状态机与流转规则.md](业务状态机与流转规则.md)、[页面功能与字段清单.md](页面功能与字段清单.md)、[数据库设计说明.md](数据库设计说明.md)

## 1. 目标与范围

本说明定义一期 MVP 的前后端 API 契约、权限边界、请求/响应结构、主要 DTO、业务接口与外部服务适配边界。它是后端 Go 服务、前端页面联调、OpenAPI 文件、Mock 数据和测试用例的共同依据。

- 管理后台、创作者工作台共用后台 API；消费者使用独立 H5 API。
- 所有跨表关系由 Go 服务层在事务内校验，不依赖 MySQL 物理外键。
- 商品与活动仅允许系统自动校验并自动发布，**不得提供人工内容发布审核接口**。
- 测试环境提供模拟支付和模拟退款；生产环境必须接入真实支付与退款 API。数字人民币为后续可选支付渠道，支付适配层保持统一接口。
- 所有用户提交的文字通过第三方敏感内容检测；商品/活动检测疑似、不通过或异常均禁止发布。

## 2. 通用约定

### 2.1 请求头

| 请求头 | 是否必填 | 说明 |
| --- | --- | --- |
| `Authorization` | 登录接口除外 | `Bearer {accessToken}` |
| `X-Request-Id` | 建议 | 客户端请求追踪号；服务端不存在时生成 |
| `Idempotency-Key` | 创建订单、支付、退款、核销、发货、结算付款必填 | 16-128 位字母、数字、点、下划线或连字符；同一业务动作在 24 小时内重复请求返回同一处理结果 |
| `If-Match-Version` | 编辑、审核、状态变更建议必填 | 对应对象乐观锁 `version`，不一致返回并发冲突 |
| `X-Client-Type` | 建议 | `ADMIN_WEB`、`CREATOR_WEB`、`CONSUMER_H5`、`SYSTEM` |

### 2.2 统一响应体

成功响应：

```json
{
  "code": "OK",
  "message": "success",
  "data": {},
  "requestId": "req_20260902_xxx",
  "timestamp": "2026-09-02T10:00:00.000+08:00"
}
```

失败响应：

```json
{
  "code": "AUTHORIZATION_QUOTA_SOLD_OUT",
  "message": "授权名额已用完",
  "data": {
    "objectType": "AUTH_ORDER",
    "objectId": "AUTH-202609-000001",
    "currentStatus": "PENDING_PAYMENT"
  },
  "requestId": "req_20260902_xxx",
  "timestamp": "2026-09-02T10:00:00.000+08:00"
}
```

HTTP 状态码仅反映协议层结果：`200` 查询/成功、`201` 创建成功、`202` 已受理异步处理、`400` 参数错误、`401` 未登录、`403` 无权限、`404` 不存在、`409` 并发或状态冲突、`422` 业务校验失败、`429` 频率限制、`500` 服务异常。业务原因必须使用 `code` 返回。

### 2.2.1 已实现的幂等、版本与状态基座

1. 后端以 `api_idempotency_record` 保存调用主体、方法、路径、幂等键、请求 SHA-256、首次响应快照、完成时间与过期时间；记录与主业务写入使用同一个 MySQL 事务。
2. 同一“主体 + 方法 + 路径 + 幂等键”在 24 小时内携带相同请求内容时，服务端不再执行业务逻辑，直接重放首次响应；请求内容不同返回 `409 IDEMPOTENCY_CONFLICT`。
3. 编辑、审核和状态变更通过 `If-Match-Version` 传递正整数版本号；缺失或格式非法返回 `400 VALIDATION_REQUIRED`，版本不一致返回 `409 VERSION_CONFLICT`。
4. 领域服务必须使用显式状态机规则判断“当前状态 -> 目标状态”；不允许的转换返回 `422 STATE_TRANSITION_NOT_ALLOWED`，并在成功流转的同一事务内写入 `biz_status_history` 和 `sys_audit_log`。
5. 审计与幂等快照写入前须脱敏 `password`、`token`、`secret`、证件号、银行账号、手机号等字段；不得持久化明文敏感信息。

### 2.3 分页、筛选与排序

列表接口统一使用：

```text
pageNo=1&pageSize=20&keyword=...&sortBy=createdAt&sortOrder=desc
```

- `pageNo` 从 1 开始，默认 1；`pageSize` 默认 20，最大 100。
- 时间范围使用 `createdFrom`、`createdTo`，ISO 8601 日期时间或 `yyyy-MM-dd` 日期。
- 只允许接口定义的 `sortBy`；后端不接收原生 SQL 排序字段。
- 分页响应 `data` 统一为：

```json
{
  "items": [],
  "pageNo": 1,
  "pageSize": 20,
  "total": 0,
  "totalPages": 0
}
```

### 2.4 标识、金额、时间与敏感数据

- 所有内部 `id` 以字符串返回，避免 JavaScript 精度丢失；业务编号如 `IP-202609-000001` 另行返回。
- 金额字段 JSON 使用字符串，例如 `"199.00"`；比例使用字符串，例如 `"0.250000"`。
- 时间使用 ISO 8601 +08:00；日期使用 `yyyy-MM-dd`。
- 身份证、统一社会信用代码、银行卡、地址、手机号和文件存储键不在普通列表完整返回。
- 密码、验证码、敏感检测原始命中词、外部服务密钥、长期下载链接绝不在响应中返回。

### 2.5 文件接口约定

1. 前端先调用上传接口取得 `fileId`，业务提交接口只传 `fileId` 或文件 ID 数组；前端不得保存或拼接 COS `storageKey`。
2. 上传请求只提交 multipart 字段 `file`。当前后台上传默认按私有文件保存；图片允许 `jpg/jpeg/png/webp` 且最大 10MB，文档允许 `pdf/doc/docx/xls/xlsx` 且最大 30MB，媒体允许 `mp4/mp3/wav` 且最大 200MB。服务端同时校验文件扩展名与探测到的 MIME 类型。
3. 下载接口返回短期签名 URL 与过期时间；当前默认有效期为 10 分钟。素材包下载须在后续授权模块中二次校验授权状态。
4. 文件权限由对象、角色、数据范围和业务状态共同决定，不能仅通过文件 ID 判断。当前通用接口允许上传者本人或平台管理员读取；IP、合同、作品、售后等对象绑定后的细粒度规则由相应业务模块追加校验。

### 2.6 接口鉴权与会话安全

#### 2.6.1 鉴权分层

一期采用“身份认证 → 接口权限 → 数据范围 → 业务状态”四层校验。Token 证明调用者身份，不单独决定业务权限；每一次受保护请求仍由 Go 服务端根据当前账号状态、角色、数据范围和对象状态进行授权判断。

| 层级 | 校验内容 | 实现责任 |
| --- | --- | --- |
| 身份认证 | 访问令牌签名、会话状态、令牌过期、终端类型、令牌版本 | 认证中间件 |
| 接口权限 | 角色是否有访问接口、菜单或动作权限 | RBAC 中间件 |
| 数据范围 | 全平台、本城市、本组织、本人及文件下载范围 | 数据权限查询构造器/服务层 |
| 业务状态 | 对象存在、当前状态、版本号、前置条件、授权范围、幂等键 | 领域服务事务 |

任何一层不满足均终止后续处理。前端按钮可见性只用于体验，不能替代后端权限校验。

#### 2.6.2 用户登录与令牌模型

| 调用端 | 登录方式 | 访问令牌 | 刷新令牌 | 备注 |
| --- | --- | --- | --- |
| 管理后台 | 账号、密码、图形验证码；首次登录绑定手机号 | 短效 JWT | 长效随机刷新令牌 | 平台管理员、城市运营、版权/合规、创作者、财务、履约客服、集团管理层 |
| 创作者后台 | 账号、密码、图形验证码 | 短效 JWT | 长效随机刷新令牌 | 实名状态不影响登录，但影响购买和创作权限 |
| 消费者 H5 | 手机号、短信验证码 | 短效 JWT | 长效随机刷新令牌 | 仅注册/登录发送短信，不做业务通知 |
| 游客 H5 | 不登录 | 无 | 无 | 仅允许公开浏览接口 |

推荐默认配置：`accessToken` 有效期 2 小时；`refreshToken` 有效期 7 天，可在系统配置中调整。刷新令牌仅保存服务端哈希值，采用单次轮换：每次刷新成功后旧令牌立即作废、签发新刷新令牌。具体时长属于安全配置，不改变业务规则。

`accessToken` 的最小声明建议为：

```json
{
  "sub": "9000000000001",
  "sid": "session_xxx",
  "clientType": "CREATOR_WEB",
  "tokenVersion": 3,
  "iat": 1788316800,
  "exp": 1788324000,
  "jti": "jwt_xxx"
}
```

- `sub`：用户/消费者内部 ID；不放身份证、手机号、角色详情或数据范围等敏感可变数据。
- `sid`：服务端会话 ID，用于登出、强制失效和审计。
- `clientType`：限制令牌不能跨后台、创作者端和消费者 H5 混用。
- `tokenVersion`：账号停用、密码变更、重大风险处置时递增；旧 Token 即刻失效。
- 角色、菜单和数据范围由后端从缓存/数据库读取当前值，避免角色调整后旧 Token 继续拥有过期权限。

#### 2.6.3 Token 传递、存储与会话失效

- 受保护业务接口通过 `Authorization: Bearer {accessToken}` 传递访问令牌；不得通过 URL 参数传递 Token。
- 当前后台与创作者 Web 将 `accessToken`、`refreshToken` 均保存在前端运行时会话中；`refreshToken` 通过登录/刷新响应体返回，不使用 Cookie。刷新时只提交 `{ "refreshToken": "当前最新令牌" }`，成功后原子替换两个令牌。未来如切换 `HttpOnly`、`Secure`、`SameSite=Lax` Cookie，须同步增加精确 Origin 与 CSRF 校验。
- 服务端保存会话表/缓存：会话状态、用户 ID、终端类型、刷新令牌哈希、过期时间、最近活动时间、Token 版本和客户端 IP 摘要。
- 退出登录、账号停用、密码重置、平台管理员强制退出、创作者重大风险处置时，服务端将会话置为失效或递增 Token 版本；认证中间件每次请求校验会话状态。
- 同一账号的最大并发会话数、异常 IP 策略和空闲超时由系统安全配置决定；超过限制时按最早会话失效。

创作者被停用后，即使已有 `accessToken` 尚未自然过期，也不得继续购买授权、下载素材、提交作品、创建商品/活动、发货或修改收款信息；历史合同、订单和结算记录仍可按授权范围查询。

#### 2.6.4 角色、数据范围与文件授权

1. 认证中间件取得用户 ID 和终端后，RBAC 中间件加载当前角色和按钮权限。
2. 数据服务从当前会话生成 `DataScope`，禁止从请求体信任 `creatorId`、`cityOrgId`、`consumerId` 等归属参数。
3. 城市运营查询与写入必须自动附加本城市条件；创作者和消费者自动附加本人主体条件。
4. 履约客服可读取授权摘要，但认证、版权证明、评估报告、授权委托书和内部合规意见必须被字段级剔除。
5. 文件下载接口先校验业务对象、文件用途、角色、数据范围和授权/合同状态，再签发几分钟有效的下载 URL；素材包还须校验授权为 `ACTIVE`。
6. 集团管理层默认只读；平台管理员也不能通过普通接口直接修改创作者 IP 衍生内容或绕过商品/活动自动发布校验。

#### 2.6.5 游客与公开接口防护

`/public/**`、`/consumer/auth/**` 等接口不要求业务 Token，但必须执行：

- 基于 IP、设备摘要、手机号哈希和接口维度的频率限制；
- 参数白名单、分页上限、关键词长度限制和输入清洗；
- 公开对象状态过滤：只返回已发布商品、报名中的活动和允许公开展示的 IP 内容；
- 不返回实名资料、版权证明、合同、内部分账、内部审核意见、存证技术回执或长期文件地址；
- 对登录、验证码、支付预览和下单接口记录安全审计与异常行为指标。

#### 2.6.6 第三方回调与内部服务身份

物流、存证、实名等第三方回调不使用用户 JWT，统一采用“服务商签名 + 时间戳 + 请求唯一号”鉴权：

```text
X-Provider-Code: logistics-provider
X-Request-Id: provider_event_123
X-Timestamp: 2026-09-03T10:00:00+08:00
X-Signature: HMAC-SHA256(method + path + timestamp + requestId + bodyHash)
```

服务端必须校验服务商代码、签名、时间窗口、请求唯一号和回调对象状态；重复回调按幂等结果返回，验签失败只写安全审计，不更新业务状态。可按供应商能力配置 IP 白名单，但白名单不能替代签名验证。

内部定时任务、支付模拟器、存证补偿任务使用独立服务身份（服务账号 JWT 或 mTLS），并带 `X-Request-Id`、`Idempotency-Key`。服务身份只能调用预先白名单中的内部接口，不可冒用用户 Token。

#### 2.6.7 鉴权失败与审计

| 场景 | 返回错误码 | 审计要求 |
| --- | --- | --- |
| 未带/格式错误 Token | `AUTH_TOKEN_MISSING` | 记录请求路径、客户端 IP、请求号 |
| Token 过期或会话失效 | `AUTH_TOKEN_EXPIRED` | 记录会话 ID、失效原因 |
| 角色无接口权限 | `AUTH_FORBIDDEN` | 记录用户、角色、接口、对象摘要 |
| 数据范围越界 | `AUTH_FORBIDDEN` | 记录请求归属参数和实际范围，不泄露对象详情 |
| Token 版本过期/账号停用 | `CREATOR_SUSPENDED` 或 `AUTH_TOKEN_EXPIRED` | 记录强制失效来源和时间 |
| 回调签名失败 | `EXTERNAL_LOGISTICS_CALLBACK_INVALID` | 记录服务商、请求号、IP、签名摘要 |

## 3. 鉴权、数据权限与状态校验

### 3.1 后台角色编码

| 角色编码 | 角色 | 数据范围 |
| --- | --- | --- |
| `PLATFORM_ADMIN` | 平台管理员 | 全平台 |
| `GROUP_MANAGER` | 集团管理层 | 全平台只读 |
| `CITY_OPERATOR` | 城市运营 | 本城市 IP 数据 |
| `COPYRIGHT_COMPLIANCE` | 版权/合规 | 全平台版权合规范围 |
| `CREATOR` | 创作者 | 本人主体、授权、作品、商品、活动、订单、分账 |
| `FINANCE` | 财务 | 全平台资金、退款、分账、结算 |
| `FULFILLMENT_CS` | 履约客服 | 全平台履约、核销、售后，授权仅摘要 |

消费者 H5 使用 `CONSUMER` 权限域，不进入后台 API。游客仅能调用 `/public/**` 接口。

### 3.2 服务端统一校验顺序

对所有写操作，服务端按以下顺序处理：

1. 校验 Token、角色、数据范围与接口权限；
2. 校验请求字段格式、必填项、文件权限和 `If-Match-Version`；
3. 校验对象存在、逻辑关联、当前状态和业务前置条件；
4. 需要时执行敏感内容检测、实名/物流/支付/存证等外部调用；
5. 在数据库事务中写业务数据、状态历史和审计日志；
6. 返回最新状态、版本号、可执行动作和必要的异步任务编号。

前端隐藏按钮不构成权限控制；后端必须重复执行所有校验。状态机未列出的流转返回 `STATE_TRANSITION_NOT_ALLOWED`。

### 3.3 通用状态返回模型

核心对象详情统一包含：

```json
{
  "id": "9000000000001",
  "businessNo": "IP-202609-000001",
  "status": "LISTED",
  "statusName": "已上架",
  "statusReasonCode": null,
  "statusReason": null,
  "version": 6,
  "availableActions": ["VIEW", "PAUSE", "DELIST"],
  "statusChangedAt": "2026-09-02T10:00:00.000+08:00"
}
```

`availableActions` 由后端根据角色、数据范围和当前状态计算，前端不得自行推导。

## 4. 公共 DTO 与字典接口

### 4.1 标准引用对象

```json
{
  "id": "9000000000001",
  "no": "IP-202609-000001",
  "name": "梅花蔡夫人",
  "status": "LISTED",
  "statusName": "已上架"
}
```

### 4.2 地区、标签、枚举

| 方法 | 路径 | 角色 | 请求参数 | 返回数据 |
| --- | --- | --- | --- | --- |
| GET | `/dictionaries/{dictType}` | 公开 | `enabledOnly` | 仅服务端固定白名单枚举（如 `IP_TYPE`）；返回 `code`、`name`、`sortNo`、`enabled`，不提供字典维护能力 |
| GET | `/public/regions` | 游客 | `keyword`、`level`（`NATION/PROVINCE/CITY/DISTRICT`）、`parentCode` | 已启用地区编码、名称、层级、上级编码 |
| GET | `/tags` | 后台已登录 | `tagType`、`keyword` | 已启用标签 ID、名称、类型、状态 |
| GET/POST/PATCH | `/admin/tags`、`/admin/tags/{tagId}/status` | 平台管理员 | 标签类型、名称、排序、启停原因 | 仅维护地域/文化/品类/商业化四类标签 |
| GET/POST/PATCH | `/admin/regions`、`/admin/regions/{regionId}/status` | 平台管理员 | 六码地区编码、名称、排序、启停原因 | 公开接口仅返回启用地区 |
| GET/PATCH | `/admin/configs`、`/admin/configs/{configKey}` | 平台管理员 | 非敏感配置值、原因、`If-Match-Version` | A05 的“客服信息”页签维护 `PLATFORM_SERVICE_PHONE`、`PLATFORM_SERVICE_HOURS`、`PLATFORM_SERVICE_DESCRIPTION`；保存后 `/public/service-contact` 返回最新公开值。密钥不经接口读写，仅私有配置文件管理 |
| GET/POST/PATCH | `/admin/after-sale-templates`、`/admin/after-sale-templates/{templateId}/versions`、`/admin/after-sale-templates/{templateId}/status` | 平台管理员 | 商品/活动规则 JSON、退货费用承担方、启停原因 | 原模板不可编辑；新版本自动停用旧版本 |

固定枚举以 [页面功能与字段清单.md](页面功能与字段清单.md) 第 11.8 节和 `数据库字段字典.xlsx` 的“枚举字典”工作表为准；服务启动时由 `bootstrap` 幂等写入 `sys_dict_item`，仅允许通过字典查询接口只读获取。地区、标签为平台管理员可维护主数据，统一放在 A05 的对应选项卡。前端不得写死中文状态文字。

## 5. 登录、账号与实名认证接口

### 5.1 管理后台登录

| 方法 | 路径 | 请求字段 | 返回字段 | 规则 |
| --- | --- | --- | --- | --- |
| GET | `/auth/captcha` | 无 | `captchaId`、`imageBase64`、`expiresAt` | 图形验证码 |
| POST | `/auth/login` | `account`、`password`、`captchaId`、`captchaCode` | `accessToken`、`refreshToken`、`expiresIn`；登录后通过 `/auth/me` 返回角色、菜单和数据范围 | 登录页不选择角色；服务端根据账号识别账号类型并加载 RBAC 权限；消费者不使用本接口。 |
| POST | `/auth/refresh` | `refreshToken` | 新 `accessToken`、新 `refreshToken`、`expiresIn`，按会话类型返回 `user` 或 `creator` | 无需 `Authorization`；适用于后台与创作者，单次轮换，前端必须立即覆盖两个令牌；旧令牌或并发重复刷新返回 `401 AUTH_TOKEN_EXPIRED` |
| POST | `/auth/logout` | 无 | 空对象 | 统一注销当前后台或创作者会话 |
| GET | `/auth/me` | 无 | 后台：用户、角色、权限、数据范围、可见菜单；创作者：档案、实名状态、`CREATOR` 角色、权限及可见菜单 | 页面初始化；创作者当前只返回 C01 工作台/注册实名认证与 C02 IP 商城，前端不得展示 C03 及后续菜单。 |

### 5.1.1 平台管理员后台账号管理

| 方法 | 路径 | 请求字段 | 返回字段 | 规则 |
| --- | --- | --- | --- | --- |
| GET | `/admin/accounts` | `keyword`、`orgId`、`roleCode`、`status`、分页 | 账号、显示名、手机号脱敏、组织、唯一角色、数据范围、状态、最近登录时间 | 仅平台管理员；列表使用 `data.items` |
| POST | `/admin/accounts` | `username`、`initialPassword`、`displayName`、`mobile`、`orgId`、`roleCode`、`dataScope` | 新账号 ID、状态、版本 | 账号唯一；初始密码只写不回显；一期不强制幂等键 |
| GET | `/admin/accounts/{userId}` | 无 | 完整账号资料、手机号、组织、唯一角色、数据范围、版本 | 仅账号管理权限持有者可获取完整手机号用于编辑回显；不返回密码 Hash 或 Token |
| PATCH | `/admin/accounts/{userId}` | 显示名、手机号、组织、角色、数据范围、版本 | 最新账号资料 | 一期不修改登录账号；角色变更后旧会话失效 |
| PATCH | `/admin/accounts/{userId}/status` | `status`、`reason`、版本 | 最新状态 | 停用必须填写原因，撤销全部有效会话 |

### 5.1.2 组织管理与菜单初始化

| 方法 | 路径 | 请求字段 | 返回字段 | 规则 |
| --- | --- | --- | --- | --- |
| GET | `/admin/orgs/options` | 无 | 已启用组织的 ID、名称、类型、上级 ID、城市编码 | 账号“所属组织”下拉唯一数据来源；不返回停用组织 |
| GET | `/admin/orgs` | `keyword`、`orgType`、`status`、分页 | 组织编码、名称、类型、上级组织、城市编码、状态、版本 | 仅平台管理员 |
| POST | `/admin/orgs` | `orgCode`、`orgName`、`orgType`、`parentId`、`cityCode` | 新组织资料 | 组织编码唯一；城市组织必须有上级和城市编码 |
| GET | `/admin/orgs/{orgId}` | 无 | 完整组织资料、版本 | 仅平台管理员 |
| PATCH | `/admin/orgs/{orgId}` | 组织名称、上级组织、城市编码、版本 | 最新组织资料 | 不可修改组织编码、组织类型；不允许形成循环 |
| PATCH | `/admin/orgs/{orgId}/status` | `status`、`reason`、版本 | 最新状态 | 有启用账号或启用下级组织时拒绝停用 |

登录后不新增独立菜单接口，统一由 `GET /auth/me` 返回 `menus[]` 和 `permissions[]`。每个菜单至少含 `code`、`name`、`resourceCode`；前端以 `resourceCode` 映射一期固定路由、图标和排序，只展示后端返回的菜单。创作者 `CREATOR_WEB` 当前固定返回 `MENU_CREATOR_WORKSPACE`（C01）、`MENU_CREATOR_ONBOARDING`（C01）和 `MENU_CREATOR_IP_MALL`（C02）；菜单显示只用于体验，所有接口仍必须由后端 RBAC 校验。

### 5.2 消费者注册与登录

| 方法 | 路径 | 请求字段 | 返回字段 | 规则 |
| --- | --- | --- | --- | --- |
| POST | `/consumer/auth/sms/send` | `mobile` | `expiresIn`；测试环境另有 `mockCode` | 同手机号 60 秒限发、同 IP 每小时限次；不透露是否已注册 |
| POST | `/consumer/auth/login` | `mobile`、`smsCode`、`agreementAccepted=true`、`agreementVersion` | `accessToken`、`refreshToken`、`consumer`、`registered` | 自动注册或登录；首次与每次登录均记录协议同意版本和时间；Cookie 购物车合并待 API-H5-02 |
| POST | `/consumer/auth/refresh` | `refreshToken` | 新 Token | 轮换刷新令牌 |
| POST | `/consumer/auth/logout` | 无 | 空对象 | 注销会话 |
| GET | `/consumer/me` | 无 | 脱敏手机号、协议版本/同意时间、订单/预约/售后数量 | 仅接受 `CONSUMER_H5` 会话；不返回敏感原文 |

### 5.3 创作者注册、实名与委托书

| 方法 | 路径 | 请求字段 | 返回字段 | 规则 |
| --- | --- | --- | --- | --- |
| POST | `/creator/auth/sms/send` | `mobile` | `expiresIn`；测试环境另有 `mockCode` | 创作者注册验证码；当前为 Mock |
| POST | `/creator/auth/register` | `mobile`、`password`、`smsCode`、`displayName` | 创作者会话、创作者档案、实名状态 | 注册后初始为个人未认证；主体类型在实名时提交 |
| POST | `/creator/identity-verifications` | `subjectType`、`legalName`、`credentialType`、`credentialNo` | `verificationNo`、`identityStatus`；企业/工作室另返回 `authorizationLetterDraftFileId`、`fileName`、`downloadUrl`、`expiresAt` | 服务端保存实名资料并调用 Mock 实名适配器；企业/工作室通过后自动生成一份仅本人可下载的 Word 委托书草稿，不等同签署留存文件 |
| GET | `/creator/identity-verifications/latest` | 无 | 实名状态、结果摘要、第三方结果编号、可执行动作 | 不返回证件完整值 |
| POST | `/creator/authorization-letters` | `fileId` | 委托书版本、`FILED` 留存状态 | 企业/工作室可提交；只作资料留存，不需要管理员确认，也不影响购买资格 |
| GET | `/creator/authorization-letter-template` | 无 | 模板名称、正文、`${variables}` 占位符 | 获取标准模板正文 |
| GET | `/creator/authorization-letter-draft` | 无 | `authorizationLetterDraftFileId`、`fileName`、`downloadUrl`、`expiresAt` | 仅已认证企业/工作室本人；短链失效后重新请求，复用同一草稿，不产生新的签署留存记录 |
| PATCH | `/admin/creators/{creatorId}/status` | 平台管理员 | `status`（`ACTIVE`/`SUSPENDED`）、`reason` | 创作者账号状态 | 停用后禁止新增操作 |

## 6. IP 入库、确权与授权方案接口

### 6.1 IP 资产

| 方法 | 路径 | 角色 | 请求字段/筛选 | 返回数据与规则 |
| --- | --- | --- | --- | --- |
| GET | `/ips` | 城市运营、版权/合规、管理员、集团只读 | `keyword`、`pageNo`、`pageSize` | 权限范围内 IP 列表；城市运营始终限制本人组织。返回素材包状态、素材包存证状态与冻结时间摘要，不返回完整 Hash |
| POST | `/ips` | 城市运营 | `ipName`、`ipType`、`sourceType`、展示资料、权利人、版权证明、**`materialPack`**、DCI 证书或 `dciAssistanceRequested/dciAssistanceRequest`、方案及分配 | 点击“保存 IP”后创建 `DRAFT` IP 和完整素材包；素材项固化文件 Hash、角色、排序、交付标识及范围并生成清单 Hash。勾选代办时同一事务锁定素材清单与 DCI 代办申请；代办与 DCI 证书互斥。 |
| GET | `/ips/{ipId}` | 有权限角色 | 无 | IP 全量详情；按角色脱敏。确权完成后返回 `rightsEvidence`（确权快照 `hashValue`、存证号、回执号、链上 `transactionHash`、存证时间）、`materialPack`（`manifestHash`、锁定/冻结/素材包存证信息）、`materialItems`（文件 SHA-256、角色、排序、交付范围）和 `dciAssistance` 的锁定申报包 Hash；不返回私有存储键或下载链接 |
| PATCH | `/ips/{ipId}` | 城市运营 | 允许编辑字段、`version` | 仅 `DRAFT`/`SUPPLEMENT_REQUIRED` 且本城市 |
| POST | `/ips/{ipId}/dci-certificate` | 城市运营 | `certificateNo`、`certificateFileId`、`If-Match-Version`、`Idempotency-Key` | DCI 代办取得证书后的独立回填；只新增证书关联，不修改已经锁定的 IP 内容或素材包 |
| POST | `/ips/{ipId}/dci-assistance-requests` | 城市运营 | `contactName`、`contactMobile`、`preferredContactTime`、`requestNote`、`idempotencyKey` | 仅用于已保存 IP 后补申请 DCI 代办；创建联系请求，IP 的 DCI 状态改为 `ASSISTANCE_REQUESTED`；不得提交审核 |
| GET | `/compliance/ips/pending` | 版权/合规 | `keyword`、`dciCertificateStatus`（仅 `UPLOADED`/`VERIFIED`）、分页 | 合规日常主队列；只返回 `PENDING_COMPLIANCE`，给出城市、脱敏权利人、初选方案、评估报告是否已传和 `nextAction` |
| GET | `/compliance/dci-assistance-requests` | 版权/合规 | `handlingStatus`、`keyword`、分页 | DCI 代办待办；返回完整联系人姓名和手机号，仅合规可读，读取写审计且不得缓存/导出 |
| POST | `/compliance/dci-assistance-requests/{requestId}/handle` | 版权/合规 | `handlingStatus`、`handlingNote`、`If-Match-Version`、`Idempotency-Key` | 更新 `CONTACTED`/`PROCESSING`/`COMPLETED`/`CLOSED` 及处理轨迹，不代替证书核验 |
| POST | `/compliance/dci-assistance-requests/{requestId}/application-package` | 版权/合规 | `includeEvaluationReport`、`Idempotency-Key` | 服务端生成私有 ZIP；含代办申请 Markdown、IP 作品说明、权属证明、锁定素材清单 Hash 和全部素材附件，勾选时附带有效评估报告；返回短期 `downloadUrl`，不返回联系人明文 |
| POST | `/ips/{ipId}/submit` | 城市运营 | `comment`、`If-Match-Version`、`Idempotency-Key` | 仅 DCI 已上传且资料完整、文字检测通过时进入 `PENDING_COMPLIANCE` |
| POST | `/ips/{ipId}/dci-verifications` | 版权/合规 | `result`（`PASS`/`RETURN`）、`comment`、版本、幂等键 | 通过仅使 DCI 变为 `VERIFIED`；退回将 IP 转为 `SUPPLEMENT_REQUIRED` |
| POST | `/ips/{ipId}/rights-reviews` | 版权/合规 | `result`（`CONFIRM`/`RETURN`）、`comment`、`supplementItems`、确认时最终 `suggestedTransactionPriceAmount`、最终 `authPlanVersionId/distributionTemplateId/distributionItems`、版本、幂等键 | 退回理由必填；确认时交易价必填并锁定；确认前 DCI 必须已核验，商城资料和方案条件满足。成功返回 `evidenceReceiptNo` 与可展示的 `evidenceTransactionHash`，随后直接进入 `LISTED` |
| POST | `/ips/{ipId}/evaluation-reports` | 城市运营（仅本城市、`DRAFT`/`SUPPLEMENT_REQUIRED`）、版权/合规 | `reportNo`、`institutionName`、`reportDate`、`validTo`、`fileId`、可选 `evaluationSuggestedPriceAmount` | 非必填；填写后随评估报告保存，仅作定价参考，不直接作为交易价 |
| POST | `/ips/{ipId}/pause` | 平台管理员 | 已完成 | `LISTED → PAUSED`，隐藏商城并停止新购买；历史授权不受影响 |
| POST | `/ips/{ipId}/resume` | 平台管理员 | 已完成 | `PAUSED → LISTED`，重新校验前置条件后恢复商城和新购买 |
| POST | `/ips/{ipId}/delist` | 平台管理员 | 已完成 | `LISTED/PAUSED → DELISTED`，隐藏商城并停止新购买，历史授权不受影响 |
| POST | `/ips/{ipId}/risk-revocations` | 平台管理员 | 暂缓 | 待授权、订单和分账模块完成后实现 |

商城上架不再设置独立人工接口，由确权成功事务自动完成。IP 详情中的主归属城市、权利人和已绑定方案在确权后不允许普通编辑。

### 6.2 授权方案与分配方案

| 方法 | 路径 | 角色 | 请求字段/筛选 | 返回数据与规则 |
| --- | --- | --- | --- | --- |
| GET | `/auth-plans` | 平台管理员、版权/合规、城市运营只读 | `enabledOnly`（默认 `true`） | 已启用或全部固定授权方案；不含分账模板 |
| POST | `/auth-plans` | 平台管理员 | `planNo`、方案名称、授权方式、期限、地区、场景、权限、内容类型、名额 | 创建 `DRAFT` 权利方案和版本；不绑定分账模板，也不配置 IP 交易价格 |
| GET | `/auth-plans/{planId}` | 有权限角色 | 无 | 方案、版本、绑定 IP 摘要、审核记录 |
| PATCH | `/auth-plans/{planId}/draft` | 平台管理员 | 可编辑方案字段、`version` | 仅草稿/退回且未绑定 IP |
| POST | `/auth-plans/{planId}/submit` | 平台管理员 | `submitComment` | 进入 `PENDING_COMPLIANCE` |
| POST | `/auth-plans/{planId}/reviews` | 版权/合规 | `result`（`PASS`/`RETURN`）、`comment` | 确认或退回方案 |
| POST | `/auth-plans/{planId}/enable` | 平台管理员 | `version` | 已确认方案启用 |
| POST | `/auth-plans/{planId}/disable` | 平台管理员 | `reason`、`version` | 已绑定 IP 必须拒绝 |
| GET | `/distribution-templates` | 平台管理员、版权/合规、城市运营只读 | `enabledOnly`（默认 `true`） | 分账结构模板及参与方；不返回比例 |
| GET | `/distribution-templates/{templateId}` | 平台管理员、版权/合规、城市运营只读 | 无 | 模板及排序后的必选参与方 |
| POST | `/distribution-templates` | 平台管理员 | `distributionNo`、`distributionName`、`distributionType`、`items[].participantType/sortNo` | 创建启用模板；模板参与方全部必选，不配置比例 |
| PATCH | `/distribution-templates/{templateId}` | 平台管理员 | 模板名称、参与方、`If-Match-Version` | 仅未被 IP 使用的模板可修改 |
| PATCH | `/distribution-templates/{templateId}/status` | 平台管理员 | `enabled`、`reason`、`If-Match-Version` | 已被 IP 使用的模板必须拒绝停用 |

授权方案与分账结构模板是独立可复用主数据。`authorizationMode` 固定为 `NORMAL_SHARE` 或 `EXCLUSIVE_BUYOUT`；城市运营在 IP 入库、版权/合规在 IP 确权时，才选择同类型模板：普通授权选择 `NORMAL_SHARE`，独家买断选择 `BUYOUT_FEE`。模板只定义全部必选的参与方，IP 为每一方填写专属比例并确保合计 100%；版权/合规确认或调整该比例，绝不回写模板。

## 7. 创作者 IP 商城、授权、合同与素材接口

### 7.1 创作者 IP 商城

| 方法 | 路径 | 角色 | 请求字段/筛选 | 返回数据 |
| --- | --- | --- | --- | --- |
| GET | `/creator/ip-mall` | 创作者 | `keyword`、`regionCode`、`ipType`、`tagCodes`、`authorizationMode`、`contentType`、`term`、`minPrice`、`maxPrice`、`sortBy`、分页 | 在售、未售罄、可见 IP 卡片 |
| GET | `/creator/ip-mall/{ipId}` | 创作者 | 无 | IP 公共详情、授权范围、价格、名额规则、普通授权创作者/平台比例、购买须知 |
| GET | `/creator/ip-mall/{ipId}/purchase-preview` | 创作者 | 无 | 主体摘要、方案、价格、合同主要条款、是否可购买、不可购买原因 |

未认证或认证中的创作者可浏览商城，但购买预览返回 `canPurchase=false`；暂停、下架、失效、售罄或已买断 IP 不返回于商城列表。

### 7.2 授权购买、微信支付 V3、合同和素材

| 方法 | 路径 | 角色 | 请求字段 | 返回数据与规则 |
| --- | --- | --- | --- | --- |
| POST | `/creator/auth-orders` | 创作者 | `ipId`、`contractAgreed`、`idempotencyKey` | 待支付订单、金额、支付截止时间、合同预览摘要；锁定名额 |
| GET | `/creator/auth-orders/{authOrderId}` | 创作者本人、财务/管理员按权限 | 无 | 授权订单详情与支付状态 |
| POST | `/payments/wechat-h5/initiate` | 订单所有人 | `bizType`（`AUTH_ORDER`/`PRODUCT_ORDER`/`ACTIVITY_BOOKING`）、`bizOrderId`、`idempotencyKey` | 微信支付流水号、`h5Url`、支付截止时间 | 生产环境唯一支付发起接口；前端跳转 `h5Url` |
| POST | `/integrations/wechat-pay/notifications` | 微信支付服务 | 微信支付 V3 签名通知报文 | `200/204` 接收确认 | 无 JWT；验签、解密、幂等处理后更新业务订单 |
| POST | `/payments/mock/pay` | 订单所有人 | 同上 | 模拟支付结果 | 仅 `test` 环境启用，生产环境禁止注册该路由 |
| POST | `/creator/auth-orders/{authOrderId}/cancel` | 创作者 | `reason`、`idempotencyKey` | 已关闭订单 | 仅待支付；释放名额 |
| GET | `/creator/authorizations` | 创作者 | `status`、`ipId`、分页 | 授权编号、IP、方案、合同、有效期、状态、素材摘要 |
| GET | `/creator/authorizations/{authorizationId}` | 创作者本人、按权限后台 | 无 | 完整授权、范围快照、合同/凭证、下载权限、可执行动作 |
| GET | `/creator/authorizations/{authorizationId}/contract` | 创作者本人 | 无 | 合同详情、文件下载短链、存证摘要 |
| GET | `/creator/authorizations/{authorizationId}/certificate` | 创作者本人 | 无 | 授权凭证与下载短链 |
| GET | `/creator/authorizations/{authorizationId}/material-packs` | 创作者本人 | 无 | 仅返回订单快照引用、已冻结且已存证的素材包和可交付素材项 |
| POST | `/creator/authorizations/{authorizationId}/material-downloads` | 创作者本人 | `materialItemId` | 临时下载 URL、`expiresAt`、`manifestHash` | 仅授权 `ACTIVE`、未到期且素材项允许交付；订单快照 Hash 不一致拒绝 |

支付成功必须在事务/补偿流程中生成授权、合同、凭证、范围快照和存证任务。成功授权后不得提供取消或退款接口；到期后可按届时有效方案重新下单，不是自动续期。

## 8. 作品、商品与活动接口

### 8.1 二创作品

| 方法 | 路径 | 角色 | 请求字段/筛选 | 返回数据与规则 |
| --- | --- | --- | --- | --- |
| GET | `/creator/works` | 创作者 | `keyword`、`ipId`、`status`、`rightsStatus`、分页 | 本人作品列表 |
| POST | `/creator/works` | 创作者 | `authorizationId`、`workName`、`workType`、作品说明、完成时间、公开版权声明、五项 `declarations`、AI/共同创作说明、`newExpressionRatio`（51–100）、新增表达维度/说明、原始 IP 使用说明、预览/源文件/过程文件、冻结素材项 `materialItemIds` | 校验本人有效且允许二创的授权、已冻结已存证素材包及购买时清单 Hash；提交后不可直改 |
| GET | `/creator/works/{workId}` | 创作者本人、版权/合规 | 无 | 作品、版本、文件、检测和审核记录 |
| POST | `/creator/works/{workId}/resubmit` | 创作者 | 与提交作品相同的字段 | 仅 `RETURNED`、`REJECTED`、`TEXT_REJECTED`、`TEXT_CHECK_ERROR` 可创建新版本；历史版本保留、不得换原始 IP；已确权作品禁止覆盖 |
| GET | `/copyright/works/pending` | 版权/合规 | `reviewNode`、`status`、分页 | 待版权初审/合规复核队列 |
| POST | `/copyright/work-versions/{workVersionId}/reviews` | 版权/合规 | `reviewNode`、`result`（`PASS`/`RETURN`/`REJECT`）、`comment`、`supplementItems`、`version` | 推进/退回/驳回作品 |
| POST | `/copyright/works/{workId}/rights-confirmations` | 版权/合规 | `reviewedNewExpressionRatio`（51–100）、`comment` | 生成包含作品版本、文件 Hash、冻结素材引用、IP/授权依据和审核记录的确权快照 Hash；提交存证，成功后进入 `RIGHTS_CONFIRMED` |

作品疑似敏感文本可以进入人工版权/合规复核；作品没有草稿保存接口、撤回接口或原版本直接编辑接口。`newExpressionRatio ≥ 51%` 是平台确权准入标准，不改变原始 IP 的权属，也不构成法定著作权比例判定；平台审核认定不足 51% 的内容不得进入 `RIGHTS_CONFIRMED`，仅可按授权使用内容处理。

### 8.2 商品

| 方法 | 路径 | 角色 | 请求字段/筛选 | 返回数据与规则 |
| --- | --- | --- | --- | --- |
| GET | `/creator/products` | 创作者 | `keyword`、`ipId`、`status`、`fulfillmentMode`、`pageNo`、`pageSize` | 本人商品列表；返回 `items/pageNo/pageSize/total`，单页最大 100 |
| POST | `/creator/products` | 创作者 | 商品基础字段、`authorizationId`、`workId`、销售地区、履约方式、运费、售后模板、`skus`、可选 `attachments` | 服务端由授权反查 IP；文本及全部商品图片审核通过后进入版权初审 |
| GET | `/creator/products/{productId}` | 创作者本人 | 无 | 商品、当前版本、SKU、审核记录与历史版本 |
| PATCH | `/creator/products/{productId}` | 创作者 | 完整商品字段、`Idempotency-Key` | 退回、驳回、检测失败可覆盖未发布版本重新提交；下架后生成新版本 |
| POST | `/creator/products/{productId}/delist` | 创作者 | `Idempotency-Key` | 仅已发布商品可下架；停止新下单，历史订单不受影响 |
| GET | `/copyright/products/pending` | 版权合规 | `reviewNode=COPYRIGHT_INITIAL|COMPLIANCE_REVIEW` | 获取对应节点待办 |
| POST | `/copyright/product-versions/{productVersionId}/reviews` | 版权合规 | `reviewNode`、`result`、审核意见、`Idempotency-Key` | 版权初审通过才进入合规复核；复核通过才上架 |

商品创建 DTO：

```json
{
  "authorizationId": "...",
  "workId": "...",
  "productName": "海上平安冰箱贴",
  "productIntro": "...",
  "productType": "CULTURAL_SOUVENIR",
  "brand": "可选",
  "manufacturer": "可选",
  "barcode": "可选",
  "taxRate": "可选，0-1",
  "coverFileId": "...",
  "detailFileIds": ["..."],
  "attachments": [{"fileId":"...","fileType":"QUALITY_REPORT"}],
  "publicCopyrightNotice": "...",
  "saleRegionMode": "SPECIFIED",
  "saleRegionCodes": ["350100"],
  "fulfillmentMode": "CREATOR_SHIP",
  "freightMode": "FIXED",
  "freightAmount": "8.00",
  "afterSaleTemplateId": "...",
  "skus": [{"skuName":"标准款","spec":{"材质":"金属"},"salePrice":"39.90","stockTotal":100,"skuFileId":"..."}]
}
```

商品提交后校验授权、确权作品、SKU、价格、库存、运费、售后模板，并同步检测商品名称、介绍、版权声明及封面、详情、SKU 配图和图片类附件。检测 `BLOCK` 进入 `CHECK_REJECTED`，检测调用异常进入 `CHECK_ERROR`，均不进入人工待办；`REVIEW` 与 `PASS` 进入 `PENDING_COPYRIGHT_REVIEW`，由版权初审 → 合规复核两级审核，复核通过才为 `PUBLISHED`。SKU 编码由后端生成，格式为 `SKU-{IP资产编号}-{关联作品编号}-{商品编号末6位}-{两位顺序号}`。

### 8.3 文旅活动

| 方法 | 路径 | 角色 | 请求字段/筛选 | 返回数据与规则 |
| --- | --- | --- | --- | --- |
| GET | `/creator/activities` | 创作者 | `keyword`、`ipId`、`cityCode`、`status`、`pageNo`、`pageSize` | 分页活动管理摘要：活动/授权/IP、封面、场次时间与总名额、已报名/剩余名额、成功报名数、检测状态及可暂停/恢复/下架标识；不返回场次和票种数组 |
| POST | `/creator/activities` | 创作者 | 活动字段、`authorizationId`、场次和票种、固定退款模板 | 授权须允许活动并覆盖举办城市；文本检测 `PASS` 后自动发布，无图片或人工审核 |
| GET | `/creator/activities/{activityId}` | 创作者本人 | 无 | 活动、场次、票种、规则、校验结果、预约摘要 |
| POST | `/creator/activities/{activityId}/pause-booking` | 创作者 | `Idempotency-Key` | 有报名时暂停后续报名 |
| POST | `/creator/activities/{activityId}/resume-booking` | 创作者 | `Idempotency-Key` | 授权和活动仍有效才恢复 |
| POST | `/creator/activities/{activityId}/delist` | 创作者 | `Idempotency-Key` | 仅无任何成功报名时允许 |

活动创建 DTO：

```json
{
  "authorizationId": "...",
  "activityName": "文化研学体验活动",
  "activityIntro": "...",
  "coverFileId": "...",
  "venueName": "...",
  "mapPointName": "...",
  "longitude": "119.2965000",
  "latitude": "26.0745000",
  "actualCityCode": "350100",
  "notice": "...",
  "publicCopyrightNotice": "...",
  "refundTemplateId": "...",
  "sessions": [{
    "sessionNo": "S001",
    "sessionName": "上午场",
    "startAt": "2026-10-01T09:00:00.000+08:00",
    "endAt": "2026-10-01T11:00:00.000+08:00",
    "quotaTotal": 50,
    "tickets": [{"ticketTypeCode":"ADULT","chargeType":"PAID","price":"68.00","quotaTotal":50}]
  }]
}
```

`actualCityCode` 不得为全国；授权必须允许活动且覆盖举办城市。票种必须从 `GET /dictionaries/ACTIVITY_TICKET_TYPE` 选择，同一场次类型唯一，票种名额和不得超过场次总名额；免费票价格固定为 0。文本检测通过后自动发布，无图片及人工审核。活动发布后名称、地点、日期、场次、票种、价格、名额和规则均不可修改；有成功报名只能暂停/恢复报名，不能下架或改期；全部场次结束后系统自动结束活动。

## 9. 消费者 H5 公共浏览、商品交易与活动预约接口

### 9.1 公开浏览

| 方法 | 路径 | 访问 | 请求字段/筛选 | 返回数据 |
| --- | --- | --- | --- | --- |
| GET | `/public/home` | 游客 | `regionCode` | 按最新发布时间各取 6 条商品、活动及平台服务信息；不展示 IP |
| GET | `/public/products` | 游客 | `keyword`、`regionCode`、`productType`、价格区间、`sortBy`、分页 | 已发布商品；不返回 IP 字段；售罄商品可返回但 `purchasable=false` |
| GET | `/public/products/{productId}` | 游客 | 无 | 商品、SKU、配送、售后规则、版权说明；隐藏内部授权与分账 |
| GET | `/public/activities` | 游客 | `keyword`、`cityCode`、日期范围、价格区间、分页 | 已发布活动；暂停报名活动仍可展示并返回 `bookingPaused=true`，但不可预约 |
| GET | `/public/activities/{activityId}` | 游客 | 无 | 活动、地点、场次及其 `tickets[]`、预约规则、取消/退款规则、版权说明；`sessions[].startAt/endAt` 由后端直接输出东八区展示时间 `YYYY-MM-DD HH:mm:ss`，无票种时返回 `[]` |
| GET | `/public/service-contact` | 游客 | 无 | 平台电话、服务时间、服务说明 |
| GET | `/public/media/{fileId}` | 游客 | 无 | 已发布商品、有效活动引用的封面/详情/SKU 展示图稳定地址；内容下架后立即拒绝访问，不公开附件、源文件、版权材料或存储键 |

### 9.2 商品订单与微信支付 V3

| 方法 | 路径 | 角色 | 请求字段 | 返回数据与规则 |
| --- | --- | --- | --- | --- |
| GET/POST | `/consumer/addresses` | 消费者 | 地址字段 / 幂等键 | 本人地址簿，最多 10 条 |
| PATCH/DELETE | `/consumer/addresses/{addressId}` | 消费者本人 | 地址字段、乐观锁 / 幂等键 | 编辑或删除，不影响历史快照 |
| POST | `/consumer/addresses/{addressId}/default` | 消费者本人 | 乐观锁 / 幂等键 | 设置默认地址 |
| POST | `/consumer/product-orders/preview` | 消费者 | `items`（`skuId`、`quantity`）、`addressId` | 最新价格、运费、库存校验、售后规则、应付金额 |
| POST | `/consumer/product-orders` | 消费者 | `items`、`addressId`、`Idempotency-Key` | 商品订单、支付截止时间、支付金额；原子预占库存 |
| GET | `/consumer/product-orders`、`/{orderId}` | 消费者本人 | 无 | 本人订单及完整收货地址快照 |
| POST | `/consumer/product-orders/{orderId}/cancel` | 消费者本人 | `Idempotency-Key` | 仅待支付，立即释放预占 |
| POST | `/consumer/product-orders/{orderId}/mock-pay` | 消费者本人 | `outcome=SUCCESS|FAILURE`、幂等键 | **仅 test 注册**；失败保留待支付，成功转待发货 |
| POST | `/consumer/product-orders/{orderId}/confirm-receipt` | 消费者本人 | `Idempotency-Key` | 仅已签收且无进行中售后；转已完成 |

购物车仅由 H5 浏览器本地状态管理；后端不建立购物车库存锁定接口。每次预览和创建订单都重新校验 SKU 状态、库存、价格、运费和商品发布状态。平台统一履约，默认单包裹；发货、拆包、物流、签收、确认收货和售后不属于 API-H5-02。

### 9.3 活动预约、免费票与核销码

| 方法 | 路径 | 角色 | 请求字段 | 返回数据与规则 |
| --- | --- | --- | --- | --- |
| POST | `/consumer/activity-bookings/preview` | 消费者 | `activityId`、`sessionId`、`ticketTypeId`、`quantity` | 名额、价格、规则、是否可预约 |
| POST | `/consumer/activity-bookings` | 消费者 | `activityId`、`sessionId`、`ticketTypeId`、`quantity`、`rulesAgreed`、`idempotencyKey` | 收费票返回待支付预约；免费票直接返回待核销预约和核销码摘要 |
| GET | `/consumer/activity-bookings` | 消费者 | `status`、分页 | 本人预约列表 |
| GET | `/consumer/activity-bookings/{bookingId}` | 消费者本人 | 无 | 活动/场次/票种、状态、规则快照、核销码状态 |
| GET | `/consumer/activity-bookings/{bookingId}/verification-code` | 消费者本人 | 无 | `displayCode`、二维码内容、有效期、状态 | 仅待核销状态 |
| POST | `/consumer/activity-bookings/{bookingId}/cancel-pending-payment` | 消费者本人 | `reason`、`idempotencyKey` | 已关闭预约 | 仅待支付 |

收费预约创建时锁定名额，微信支付成功回调或主动查单确认后正式占用并生成核销码；免费预约确认后直接正式占用。活动结束未核销时系统转为已过期，不退款、不产生完成分账。

## 10. 履约、核销、售后与退款接口

### 10.1 发货与物流

| 方法 | 路径 | 角色 | 请求字段 | 返回数据与规则 |
| --- | --- | --- | --- | --- |
| GET | `/fulfillment/shipments` | 具备 `FULFILLMENT_SHIPMENT_MANAGE` 的履约客服 | `status`（可选） | 待发货/已发货订单列表；地址和运单号始终脱敏 |
| POST | `/fulfillment/product-orders/{orderId}/shipments` | 具备 `FULFILLMENT_SHIPMENT_MANAGE` 的履约客服 | `carrierCode`、`trackingNo`、`shippedAt`（可选）、`proofFileId`、`remark`；`Idempotency-Key` | 发货单、物流状态 | 仅待发货订单；同键重放、异体冲突 |
| GET | `/fulfillment/delivery-orders/{deliveryId}` | 具备 `FULFILLMENT_SHIPMENT_MANAGE` 的履约客服 | 无 | 发货详情与物流轨迹 |
| GET | `/consumer/product-orders/{orderId}/logistics` | 消费者本人 | 无 | 自己订单的物流状态与轨迹 |
| POST | `/consumer/product-orders/{orderId}/confirm-receipt` | 消费者本人 | `Idempotency-Key` | 仅已签收且无进行中售后；转已完成 |
| POST | `/integrations/logistics/callbacks` | 物流服务 | 签名、运单号、事件编号、状态、时间、说明 | **后续兼容项，当前未注册** | 未来验签 + 事件幂等；非前端调用 |

### 10.2 现场核销

| 方法 | 路径 | 角色 | 请求字段 | 返回数据与规则 |
| --- | --- | --- | --- | --- |
| GET | `/fulfillment/activity-bookings` | 履约客服 | `activityId`、`sessionId`、`verificationStatus`、日期范围、分页 | 待核销预约列表 |
| POST | `/fulfillment/verifications/preview` | 履约客服 | `displayCode` 或扫码内容 | 预约、活动、场次、票种、可核销状态 |
| POST | `/fulfillment/verifications` | 履约客服 | `bookingId`、`displayCode`、`verificationPoint`、`result`、`exceptionType`、`exceptionComment`、`evidenceFileId`、`idempotencyKey` | 核销记录、预约最新状态 | 成功仅一次；重复返回已核销 |

`result=SUCCESS` 时服务端必须校验预约为待核销、核销码有效、活动/场次/票种一致；成功后完成预约并触发普通授权分账计算。

### 10.3 商品售后与活动取消退款

| 方法 | 路径 | 角色 | 请求字段 | 返回数据与规则 |
| --- | --- | --- | --- | --- |
| POST | `/consumer/after-sales/product` | 消费者 | `orderId`、`orderItemId`、`afterSaleType`、`reasonCode`、`reasonText`、`evidenceFileIds`、`idempotencyKey` | 售后单、状态、退货地址摘要 | 商品仅取消退款/退货退款 |
| POST | `/consumer/after-sales/activity` | 消费者 | `bookingId`、`reasonCode`、`reasonText`、`evidenceFileIds`、`idempotencyKey` | 售后单、状态 | 已核销/已过期拒绝 |
| GET | `/consumer/after-sales` | 消费者 | `status`、`bizType`、分页 | 本人售后列表 |
| GET | `/consumer/after-sales/{afterSaleId}` | 消费者本人、处理角色 | 无 | 规则快照、处理轨迹、退货地址、退款/冲销状态 |
| POST | `/consumer/after-sales/{afterSaleId}/withdraw` | 消费者本人 | `reason`、`version` | 已撤销 | 仅客服未处理时 |
| POST | `/consumer/after-sales/{afterSaleId}/return-logistics` | 消费者本人 | `carrierCode`、`trackingNo`、`shippedAt`、`version` | 待确认售后 | 仅退货中 |
| GET | `/fulfillment/after-sales` | 履约客服 | `status`、`bizType`、日期范围、分页 | 待审核/退货中/待确认队列 |
| POST | `/fulfillment/after-sales/{afterSaleId}/review` | 履约客服 | `result`、`comment`、`returnFeeBearer`、`suggestedRefundAmount`、`version` | 最新售后状态 | 商品：同意仅退款/退货退款/驳回；活动：同意退款/驳回 |
| POST | `/fulfillment/after-sales/{afterSaleId}/return-receipt-confirmation` | 履约客服 | `receiptResult`、`conditionResult`、`evidenceFileIds`、`comment`、`version` | 进入退款处理中 | 仅待确认 |
| GET | `/finance/refunds` | 财务 | `status`、`bizType`、日期范围、分页 | 待复核退款列表 |
| POST | `/finance/refunds/{refundId}/review` | 财务 | `result`（`APPROVE`/`REJECT`）、`refundAmount`、`comment`、`idempotencyKey` | 退款单、售后/订单最新状态 | 通过后调用微信支付退款并生成冲销 |
| 内部调用 | `PaymentProvider.refund` | 仅财务服务调用 | `refundId`、`idempotencyKey` | 退款流水 | 测试环境 Mock；生产环境调用微信支付 V3 退款 API，不对前端暴露 |

平台管理员只处理特殊异常/争议，不代替履约客服审核或财务金额复核：`POST /admin/after-sales/{afterSaleId}/exceptions`，请求字段为 `decision`、`comment`、`evidenceFileIds`，结果必须记录审计与状态历史。

## 11. 分账、结算与收款账户接口

| 方法 | 路径 | 角色 | 请求字段/筛选 | 返回数据与规则 |
| --- | --- | --- | --- | --- |
| GET | `/creator/payout-accounts` | 创作者 | 无 | 本人脱敏收款账户与核验状态 |
| POST | `/creator/payout-accounts` | 创作者 | 账户名、账号、开户行、主体资料确认、`idempotencyKey` | 新收款账户，状态待核验 |
| GET | `/admin/creator-payout-accounts` | 平台管理员 | `verificationStatus`、`creatorKeyword`、分页 | 待核验账户列表 |
| POST | `/admin/creator-payout-accounts/{accountId}/verify` | 平台管理员 | `result`（`VERIFIED`/`RETURNED`）、`comment` | 主体一致性状态 |
| GET | `/creator/revenue-shares` | 创作者 | `status`、`ipId`、日期范围、分页 | 本人分账明细、应分/冲销/付款状态 |
| GET | `/finance/revenue-shares` | 财务 | `status`、`distributionType`、订单号、日期范围、分页 | 全平台分账记录与参与方明细 |
| POST | `/finance/revenue-shares/{shareId}/freeze` | 财务/系统 | `reason`、`version` | 已冻结 | 售后、风险、异议等 |
| POST | `/finance/revenue-shares/{shareId}/unfreeze` | 财务 | `reason`、`version` | 待结算 | 仅确认无需退款或争议已解决 |
| POST | `/creator/settlement-disputes` | 创作者 | `shareItemId` 或 `batchId`、`disputeType`、`description`、`evidenceFileIds` | 异议单，关联金额冻结 |
| GET | `/finance/settlement-disputes` | 财务 | `status`、`disputeType`、分页 | 异议处理队列 |
| POST | `/finance/settlement-disputes/{disputeId}/resolve` | 财务 | `result`（`ACCEPT`/`REJECT`/`FREEZE_FOR_SUPPLEMENT`）、`comment` | 处理结论、冻结/解冻结果 |
| POST | `/finance/settlement-batches` | 财务 | `shareItemIds`、`batchNote`、`idempotencyKey` | 草稿结算批次 | 仅待结算、未冻结、未冲销、未结算明细 |
| GET | `/finance/settlement-batches` | 财务/集团管理层只读 | `status`、日期范围、分页 | 批次列表 |
| GET | `/finance/settlement-batches/{batchId}` | 财务/集团管理层只读 | 无 | 明细、收款主体、付款状态、凭证 |
| POST | `/finance/settlement-batches/{batchId}/review` | 财务 | `result`（`APPROVE`/`VOID`）、`comment`、`version` | 待付款/已作废 |
| POST | `/finance/settlement-batches/{batchId}/payments` | 财务 | `paymentAt`、`paymentProofFileId`、`paymentNote`、`itemPayments`、`idempotencyKey` | 批次/明细付款状态 | 一期线下付款上传凭证 |

普通授权完成订单或已核销活动由系统生成 `NORMAL_SHARE` 分账；独家买断授权费用生成 `BUYOUT_FEE` 分配；独家买断后的商品/活动不生成后续平台分账和平台服务费。

## 12. 文件、检测、存证、审计与看板接口

### 12.1 文件与存证

| 方法 | 路径 | 角色 | 请求字段 | 返回数据与规则 |
| --- | --- | --- | --- | --- |
| POST | `/files` | 已登录后台账号 | multipart `file` | `id`、`fileNo`、`originalName`、`mimeType`、`fileSize`、`fileHash`、`securityLevel`、`uploadStatus` | 只接受配置白名单格式；先校验大小/MIME，再上传 COS；返回 `201` |
| GET | `/files/{fileId}` | 上传者本人或平台管理员 | 无 | 文件元数据、可访问状态 | 不返回 `storageKey`、COS Bucket 或密钥 |
| POST | `/files/{fileId}/download-url` | 上传者本人或平台管理员 | 无 | 短期 `downloadURL`、`expiresAt` | 默认 10 分钟；每次签发写审计 |
| GET | `/evidence-records` | 管理员；合规/财务/集团按范围只读 | `objectType`、`objectId`、`status`、分页 | 存证编号、Hash、链平台、状态、回执、失败摘要 |
| POST | `/admin/evidence-records/{evidenceId}/retry` | 平台管理员 | `reason`、`idempotencyKey` | 重试任务状态 | 不得手工伪造成功 |
| POST | `/integrations/evidence/callbacks` | 链服务 | 签名、请求号、回执号、链上交易/存证哈希、结果、时间 | 接收结果 | 验签、幂等、记录重试/回执；成功回调必须同时提供回执号和交易/存证哈希 |

### 12.2 敏感内容检测与审计

| 方法 | 路径 | 角色 | 请求字段/筛选 | 返回数据 |
| --- | --- | --- | --- | --- |
| GET | `/content-detections` | 平台管理员、版权/合规按范围 | `objectType`、`objectId`、`status`、日期范围、分页 | 检测结果、风险类别、服务请求号、错误摘要；不返回敏感词原文 |
| GET | `/audit-logs` | 平台管理员、集团管理层按权限 | `operatorId`、`objectType`、`objectId`、`action`、日期范围、分页 | 操作人、角色、前后状态摘要、结果、时间、IP |
| POST | `/exports` | 有导出权限角色 | `objectType`、`scope`、`maskLevel`、`reason` | 导出任务编号、状态 | 全部导出留痕 |
| GET | `/exports/{exportId}` | 导出申请人/管理员 | 无 | 状态、文件下载短链、过期时间 |

### 12.3 经营看板

| 方法 | 路径 | 角色 | 请求参数 | 返回数据 |
| --- | --- | --- | --- | --- |
| GET | `/dashboard/overview` | 集团管理层 | `from`、`to`、`cityOrgId`、`ipType`、`authorizationMode` | IP、授权、交易、履约、售后、退款、结算、风险 KPI 与趋势 |
| GET | `/dashboard/city-ip` | 集团管理层 | `cityOrgId`、`ipId`、日期范围 | IP、授权、作品、商品、活动、交易、退款、结算摘要 |
| GET | `/dashboard/risks` | 集团管理层 | `riskType`、`severity`、`status`、分页 | 风险清单与对象跳转摘要 |

## 13. 外部服务适配接口

外部服务由后端适配器调用，前端不直接持有服务商密钥或调用敏感接口。

| 适配器 | Go 服务接口建议 | 关键入参 | 关键出参 | 失败规则 |
| --- | --- | --- | --- | --- |
| 短信 | `SmsProvider.SendCode` | 手机号、用途、模板 | 请求号、有效期、发送状态 | 限频或失败不创建可用验证码 |
| 实名 | `IdentityProvider.Verify` | 主体类型、加密身份资料 | 请求号、通过/失败、摘要 | 认证中/失败均禁止购买和创建内容 |
| 敏感内容 | `ContentSafetyProvider.Moderate` | 文本、业务数据编号、会话编号 | 腾讯请求号、`PASS/REVIEW/BLOCK`、风险标签、分值 | 腾讯云 TMS 真实调用；`REVIEW`、`BLOCK` 或异常均阻断当前提交 |
| 文件存储 | `FileStorage.Put/GetSignedURL` | 文件流、权限、用途 | 存储键、Hash、短期 URL | 不暴露长期真实地址 |
| 物流 | `LogisticsProvider.Query/VerifyCallback` | 运单、承运商、回调数据 | 轨迹、签收、事件号 | 回调幂等；异常记录待处理 |
| 支付 | `PaymentProvider.Initiate/Query/Close/Refund` | 业务订单、金额、幂等键 | 微信支付 V3 流水、H5 支付链接、支付/退款状态 | 测试 Mock；生产微信支付 V3；未来可新增数字人民币实现 |
| 存证 | `EvidenceProvider.Submit/Query` | 对象、Hash、请求号 | 存证号、回执、状态 | 无回执不得标记成功；保留重试 |

当前已配置的文本检测服务为腾讯云 TMS：地域 `ap-guangzhou`、策略 `ip_center`、接口 `TextModeration`。每次业务提交由后端生成不含个人信息的 `DataId`；文本只在调用时传给腾讯云，业务库仅保存文本 Hash、腾讯 `RequestId`、结论和风险标签。存证链服务商尚未确定，现有 `EvidenceProvider` 仅定义提交/查询边界；未配置真实服务时返回失败，绝不生成模拟成功回执。

## 14. API 错误码与权限矩阵

### 14.1 错误码分组

| 前缀 | 含义 | 示例 |
| --- | --- | --- |
| `AUTH_` | 登录、Token、验证码和权限 | `AUTH_TOKEN_EXPIRED`、`AUTH_CAPTCHA_INVALID`、`AUTH_FORBIDDEN` |
| `VALIDATION_` | 请求字段校验 | `VALIDATION_REQUIRED`、`VALIDATION_FORMAT_INVALID` |
| `VERSION_` | 乐观锁和并发 | `VERSION_CONFLICT`、`IDEMPOTENCY_CONFLICT` |
| `STATE_` | 状态机限制 | `STATE_TRANSITION_NOT_ALLOWED`、`STATE_OBJECT_LOCKED` |
| `CREATOR_` | 创作者实名和主体 | `CREATOR_IDENTITY_REQUIRED`、`CREATOR_SUSPENDED` |
| `IP_` | IP 确权、上架和风险 | `IP_NOT_LISTED`、`IP_RIGHTS_NOT_CONFIRMED`、`IP_RISK_REVOKED` |
| `AUTHORIZATION_` | 授权购买与边界 | `AUTHORIZATION_QUOTA_SOLD_OUT`、`AUTHORIZATION_ALREADY_ACTIVE`、`AUTHORIZATION_SCOPE_EXCEEDED` |
| `CONTENT_` | 作品、商品、活动和敏感检测 | `CONTENT_TEXT_REJECTED`、`CONTENT_TEXT_CHECK_ERROR`、`CONTENT_WORK_NOT_CONFIRMED` |
| `ORDER_` | 商品订单、库存和支付 | `ORDER_SKU_SOLD_OUT`、`ORDER_PAYMENT_EXPIRED`、`ORDER_NOT_CONFIRMABLE` |
| `BOOKING_` | 活动预约、名额和核销 | `BOOKING_QUOTA_SOLD_OUT`、`BOOKING_ALREADY_VERIFIED`、`BOOKING_EXPIRED` |
| `AFTER_SALE_` | 售后和退款 | `AFTER_SALE_NOT_ELIGIBLE`、`AFTER_SALE_ALREADY_PROCESSING`、`REFUND_AMOUNT_EXCEEDED` |
| `FINANCE_` | 分账、结算和收款 | `FINANCE_SHARE_FROZEN`、`FINANCE_SETTLEMENT_NOT_PAYABLE` |
| `FILE_` / `EVIDENCE_` | 文件权限与存证 | `FILE_ACCESS_DENIED`、`EVIDENCE_RECEIPT_MISSING` |
| `EXTERNAL_` | 外部服务异常 | `EXTERNAL_IDENTITY_TIMEOUT`、`EXTERNAL_LOGISTICS_CALLBACK_INVALID` |

### 14.2 核心错误码明细

| 错误码 | HTTP | 触发条件 | 前端处理建议 |
| --- | --- | --- | --- |
| `AUTH_TOKEN_MISSING` | 401 | 未携带访问令牌 | 跳转登录页 |
| `AUTH_TOKEN_EXPIRED` | 401 | Token 已过期且刷新失败 | 清除会话并跳转登录页 |
| `AUTH_CAPTCHA_INVALID` | 422 | 图形验证码错误或过期 | 刷新验证码，提示重新输入 |
| `AUTH_SMS_CODE_INVALID` | 422 | 短信验证码错误或过期 | 提示重新获取或输入 |
| `AUTH_SMS_RATE_LIMITED` | 429 | 短信发送频率超限 | 显示剩余等待时间 |
| `AUTH_FORBIDDEN` | 403 | 当前角色无接口或数据范围权限 | 隐藏/禁用动作并提示无权限 |
| `VALIDATION_REQUIRED` | 400 | 必填字段缺失 | 定位到对应表单字段 |
| `VALIDATION_FORMAT_INVALID` | 400 | 金额、时间、地区、文件等格式错误 | 显示字段级错误信息 |
| `VALIDATION_FILE_NOT_ALLOWED` | 422 | 文件类型、大小、密级或用途不符合要求 | 提示重新上传 |
| `RESOURCE_CONFLICT` | 409 | 唯一账号、手机号等资源已存在 | 修改冲突字段后重新提交 |
| `VERSION_CONFLICT` | 409 | `If-Match-Version` 与当前版本不一致 | 刷新详情并提示数据已更新 |
| `IDEMPOTENCY_CONFLICT` | 409 | 同一幂等键被不同请求体复用 | 停止重复提交并联系处理人员 |
| `STATE_TRANSITION_NOT_ALLOWED` | 422 | 当前状态不允许该动作 | 刷新当前状态和可执行动作 |
| `STATE_OBJECT_LOCKED` | 422 | 对象被审核、售后、风险或结算锁定 | 展示锁定原因和处理节点 |
| `CREATOR_IDENTITY_REQUIRED` | 422 | 创作者未认证或认证中而发起购买/创作 | 跳转实名认证 |
| `CREATOR_SUSPENDED` | 403 | 创作者账号已停用 | 禁止新增操作，提示平台联系渠道 |
| `IP_NOT_LISTED` | 422 | IP 未上架、暂停、下架、失效或商城隐藏 | 刷新商城，不允许购买 |
| `IP_DCI_CERTIFICATE_REQUIRED` | 422 | 提交 IP 审核时未上传 DCI 版权证书编号或文件 | 停留在编辑页，补齐 DCI 证书；已申请代办时等待线下代办完成后补传 |
| `IP_DCI_CERTIFICATE_NOT_VERIFIED` | 422 | 尝试确权或上架时 DCI 证书未通过版权/合规核验 | 展示核验状态和补充要求，不允许继续流转 |
| `IP_RIGHTS_NOT_CONFIRMED` | 422 | IP 未完成确权或材料/存证条件不满足 | 不允许上架、购买或绑定后续业务 |
| `IP_MAIN_CITY_LOCKED` | 422 | 已确权 IP 尝试修改主归属城市 | 禁止编辑，走异常处置流程 |
| `AUTH_PLAN_BOUND_LOCKED` | 422 | 已绑定 IP 的授权方案尝试编辑、停用或删除 | 新建方案/版本，不改历史 |
| `AUTHORIZATION_QUOTA_SOLD_OUT` | 422 | 授权名额已售罄 | 刷新商城；不创建订单 |
| `AUTHORIZATION_ALREADY_ACTIVE` | 422 | 创作者已持有同一 IP 的有效授权 | 跳转我的授权 |
| `AUTHORIZATION_SCOPE_EXCEEDED` | 422 | 创建作品/商品/活动超出有效授权期限、地区、场景或内容类型 | 显示越界项，禁止提交 |
| `AUTHORIZATION_EXPIRED` | 422 | 授权已到期或已解除 | 停止下载和新内容创建，可按有效新方案重新购买 |
| `AUTH_ORDER_PAYMENT_EXPIRED` | 422 | 授权订单已超时关闭 | 刷新订单，重新购买 |
| `CONTENT_TEXT_REJECTED` | 422 | 敏感内容检测不通过 | 返回脱敏修改提示，允许新版本重提 |
| `CONTENT_TEXT_SUSPECTED` | 422 | 非商品内容检测疑似风险 | 活动禁止发布并返回修改提示；作品进入人工复核。商品同步检测疑似不返回该错误，保留 `PENDING_COPYRIGHT_REVIEW` 进入二级审核 |
| `CONTENT_TEXT_CHECK_ERROR` | 422 | 敏感内容检测超时或异常 | 禁止流转，允许重新提交 |
| `CONTENT_WORK_NOT_CONFIRMED` | 422 | 商品关联作品未确权 | 跳转作品处理，禁止创建商品 |
| `CONTENT_AUTO_CHECK_REJECTED` | 422 | 商品/活动授权边界、SKU、场次或必填规则校验失败 | 返回字段级校验项，禁止发布 |
| `ORDER_SKU_SOLD_OUT` | 422 | SKU 可用库存不足 | 刷新 SKU 库存 |
| `ORDER_PRODUCT_NOT_PURCHASABLE` | 422 | 商品下架、授权失效或 SKU 停售 | 刷新商品详情 |
| `ORDER_PAYMENT_EXPIRED` | 422 | 商品订单超时关闭 | 重新创建订单 |
| `ORDER_NOT_CONFIRMABLE` | 422 | 非已签收、售后中或已完成订单确认收货 | 刷新订单状态 |
| `BOOKING_QUOTA_SOLD_OUT` | 422 | 场次/票种可用名额不足 | 刷新活动详情 |
| `BOOKING_ACTIVITY_NOT_BOOKABLE` | 422 | 活动暂停、结束、下架或授权失效 | 禁止预约 |
| `BOOKING_ALREADY_VERIFIED` | 422 | 已核销预约再次核销、取消或退款 | 展示已核销状态 |
| `BOOKING_EXPIRED` | 422 | 活动结束未核销预约操作退款 | 展示已过期且不可退款 |
| `VERIFICATION_CODE_INVALID` | 422 | 核销码无效、不匹配或已过期 | 提示核销失败原因 |
| `AFTER_SALE_NOT_ELIGIBLE` | 422 | 不符合固定售后/退款模板或订单状态不支持 | 展示规则快照摘要 |
| `AFTER_SALE_ALREADY_PROCESSING` | 422 | 同一订单项/预约已有进行中售后 | 跳转已有售后单 |
| `AFTER_SALE_RETURN_ADDRESS_LOCKED` | 422 | 已创建售后尝试变更退货地址 | 仅显示创建时锁定地址 |
| `REFUND_AMOUNT_EXCEEDED` | 422 | 退款金额超过可退金额或模板计算结果 | 刷新可退金额 |
| `REFUND_TRANSACTION_FAILED` | 422 | 支付退款适配器返回失败 | 售后保持处理中/失败，等待财务处理 |
| `FINANCE_SHARE_FROZEN` | 422 | 分账处于售后、退款、风险或异议冻结中 | 禁止入结算批次 |
| `FINANCE_SETTLEMENT_NOT_PAYABLE` | 422 | 非待结算、未核验账户或已冲销明细尝试付款 | 返回不可付款原因 |
| `FILE_ACCESS_DENIED` | 403 | 无文件/合同/素材下载权限 | 不返回下载 URL |
| `FILE_SIGNED_URL_EXPIRED` | 422 | 临时下载 URL 过期 | 重新请求下载短链 |
| `EVIDENCE_RECEIPT_MISSING` | 422 | 尝试标记上链成功但无存证/回执编号 | 保持待上链或失败状态 |
| `EXTERNAL_IDENTITY_TIMEOUT` | 422 | 实名服务超时/异常 | 实名回退未认证，可重新发起 |
| `EXTERNAL_LOGISTICS_CALLBACK_INVALID` | 401 | 物流回调验签失败或事件非法 | 记录安全审计，不更新物流状态 |
| `EXTERNAL_SERVICE_UNAVAILABLE` | 503 | 短信、检测、物流、存证等依赖不可用 | 对应业务默认阻断或进入重试队列 |

### 14.3 接口权限矩阵

`R` 表示查询/查看，`W` 表示新增/编辑/提交，`A` 表示审核/确认/状态处理，`-` 表示无权。数据范围由后端二次限制：`全` 为全平台，`城` 为本城市，`己` 为本人，`只读` 为无写权限。

| 接口分组 | 平台管理员 | 集团管理层 | 城市运营 | 版权/合规 | 创作者 | 财务 | 履约客服 | 消费者 | 数据范围与审计 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 后台登录、退出、`/auth/me` | R/W | R/W | R/W | R/W | R/W | R/W | R/W | - | 各自账号；登录/失败/退出审计 |
| 消费者短信登录、`/consumer/me` | - | - | - | - | - | - | - | R/W | 本人；验证码与会话审计 |
| 后台账号、角色、权限、系统配置 | A 全 | R 只读 | - | - | - | - | - | - | 配置变更前后快照审计 |
| 标签、地区、固定售后模板 | A 全 | R 只读 | R | R | R | R | R | R 公开地区/规则摘要 | 模板版本、启停和导出审计 |
| IP 列表与详情 | R 全 | R 全只读 | R/W 城 | R 全 | R 仅公开商城 | R 摘要 | R 摘要 | R 公开 | IP 查看与敏感文件下载审计 |
| IP 提交、补充材料 | R | - | W 城 | R | - | - | - | - | 城市运营仅本城市；提交审计 |
| DCI 代办申请与处理 | A 全 | - | W 城 | R/W 处理与资料包下载 | - | - | - | - | 城市运营仅本城市申请；版权/合规处理联系方式并下载资料包；联系方式加密、下载与查看均审计 |
| IP 合规审核、评估报告、确权 | R | R 结果只读 | W 本城草稿/补充状态的评估报告，R 本城结果 | A 全 | - | - | - | - | 评估报告非必填；审核结论、文件和状态审计 |
| IP 上架、暂停、下架、风险处置 | A 全 | R 只读 | - | A 风险确认 | - | - | - | - | 风险处置需双角色留痕 |
| 授权方案、分配方案 | W/A 全 | R 只读 | R 选择 | A 审核 | R 商城展示范围 | R 只读 | - | - | 已绑定方案禁止修改/停用 |
| 创作者实名、委托书 | A 账号停用 | - | - | - | W 本人/留存委托书 | - | - | - | 委托书不需人工确认；证件脱敏、第三方回执审计 |
| 创作者 IP 商城、授权订单、合同、素材 | R 风险/财务摘要 | - | - | R 合规摘要 | R/W 己 | R 财务摘要 | R 授权摘要 | - | 合同/素材下载、支付、到期审计 |
| 作品提交、版本重提 | - | - | - | R 待审 | W 己 | - | - | - | 声明、文件和检测记录审计 |
| 作品版权初审、合规复核、确权 | R 只读 | R 结果只读 | - | A 全 | R 己结果 | - | - | - | 审核动作与存证审计 |
| 商品创建、自动校验、上下架 | R 风险处置 | R 汇总只读 | - | R 合规/风险摘要 | W 己 | R 资金摘要 | R 履约摘要 | R 已发布 | 自动校验，禁止人工发布审核 |
| 活动创建、自动校验、暂停/恢复/下架 | R 风险处置 | R 汇总只读 | - | R 合规/风险摘要 | W 己 | R 核销摘要 | R 已发布 | 自动校验，禁止人工发布审核 |
| 商品订单与物流查询 | R 异常 | R 汇总只读 | - | - | R 己商品订单 | R 金额 | R/W 履约 | R 己订单 | 地址、物流和发货审计 |
| 商品发货、物流异常 | R 异常 | - | - | - | W 己发货订单 | - | W/A 全 | - | 仅待发货；发货幂等和物流回调审计 |
| 活动预约、核销码 | R 异常 | R 汇总只读 | - | - | R 己活动预约 | R 金额 | R/W 核销 | R/W 己预约 | 核销成功一次性、全量审计 |
| 商品售后审核、退货确认 | R 特殊异常 | - | - | - | R 己商品相关 | R 待复核 | A 全 | W/R 己售后 | 客服审核、退货物流与验收审计 |
| 活动取消退款受理 | R 特殊异常 | - | - | - | R 己活动相关 | R 待复核 | A 全 | W/R 己售后 | 已核销/过期禁止退款 |
| 退款金额复核、微信支付退款 | R 只读 | R 汇总只读 | - | - | R 己结果 | A 全 | R 处理结果 | R 己结果 | 退款幂等、冲销与财务审计 |
| 分账、冻结/解冻、结算批次、付款 | R 监督 | R 只读 | R 城市收益摘要 | R 合规摘要 | R 己明细/异议 W | A 全 | - | - | 线下付款凭证和冻结/解冻审计 |
| 文件、存证、检测、审计、导出 | A 全 | R 授权范围 | R 本城范围 | R 合规范围 | R 己范围 | R 财务范围 | R 履约范围 | R 公开文件 | 文件下载、导出、上链重试全部审计 |
| 经营/城市/IP/风险看板 | R 全 | R 全只读 | R 本城市 | R 合规范围 | R 己摘要 | R 财务范围 | R 履约摘要 | - | 聚合数据、导出需权限 |

### 14.4 状态前置条件矩阵

| 接口动作 | 必须满足的状态/条件 | 拒绝时主要错误码 |
| --- | --- | --- |
| 提交 IP 审核 | IP 为 `DRAFT` 或 `SUPPLEMENT_REQUIRED`，城市运营本城市，材料与方案完整且 DCI 已上传 | `STATE_TRANSITION_NOT_ALLOWED`、`IP_DCI_CERTIFICATE_REQUIRED` |
| IP 确权 | IP 为 `PENDING_COMPLIANCE`，版权/合规审核通过且 DCI 已核验 | `STATE_TRANSITION_NOT_ALLOWED`、`IP_DCI_CERTIFICATE_NOT_VERIFIED` |
| IP 自动上架 | IP 为 `PENDING_COMPLIANCE`，确权通过、DCI 已核验、绑定方案已启用、关键材料存证成功、商城字段完整 | `IP_DCI_CERTIFICATE_NOT_VERIFIED`、`EVIDENCE_RECEIPT_MISSING` |
| 创建授权订单 | 创作者账号正常、实名已认证、IP 已上架、名额可用、无有效同 IP 授权 | `CREATOR_IDENTITY_REQUIRED`、`AUTHORIZATION_QUOTA_SOLD_OUT`、`AUTHORIZATION_ALREADY_ACTIVE` |
| 授权微信支付 | 授权订单待支付且未超时、金额匹配、幂等键有效 | `AUTH_ORDER_PAYMENT_EXPIRED`、`IDEMPOTENCY_CONFLICT` |
| 提交作品 | 授权为 `ACTIVE`、允许二创且在范围内、声明全勾选、文件完整 | `AUTHORIZATION_SCOPE_EXCEEDED`、`VALIDATION_REQUIRED` |
| 创建商品 | 授权有效且允许商品/商业化、关联作品已确权、SKU/售后规则完整 | `CONTENT_WORK_NOT_CONFIRMED`、`CONTENT_AUTO_CHECK_REJECTED` |
| 创建活动 | 授权有效且允许活动、实际举办地区非全国、场次票种完整、固定退款模板已选 | `AUTHORIZATION_SCOPE_EXCEEDED`、`VALIDATION_FORMAT_INVALID` |
| 商品发布 | 授权边界有效、文字及关联图片检测未拦截、二级审核均通过 | `CHECK_REJECTED`、`CHECK_ERROR`、审核退回/驳回 |
| 创建商品订单 | 商品已发布、SKU 在售且库存充足、消费者已登录并确认规则 | `ORDER_PRODUCT_NOT_PURCHASABLE`、`ORDER_SKU_SOLD_OUT` |
| 创建活动预约 | 活动报名中、场次票种可预约且名额足够、消费者已登录并确认规则 | `BOOKING_ACTIVITY_NOT_BOOKABLE`、`BOOKING_QUOTA_SOLD_OUT` |
| 发货 | 商品订单 `PENDING_SHIPMENT`，操作者为履约客服或对应创作者 | `STATE_TRANSITION_NOT_ALLOWED`、`AUTH_FORBIDDEN` |
| 现场核销 | 预约 `PENDING_VERIFICATION`、核销码有效且未使用 | `BOOKING_ALREADY_VERIFIED`、`VERIFICATION_CODE_INVALID` |
| 商品售后申请 | 订单和订单项满足售后模板、无进行中冲突售后 | `AFTER_SALE_NOT_ELIGIBLE`、`AFTER_SALE_ALREADY_PROCESSING` |
| 活动退款申请 | 预约未核销、未过期且处于模板允许窗口 | `BOOKING_ALREADY_VERIFIED`、`BOOKING_EXPIRED`、`AFTER_SALE_NOT_ELIGIBLE` |
| 财务退款 | 售后已由履约客服确认，金额不超过可退金额 | `REFUND_AMOUNT_EXCEEDED`、`STATE_TRANSITION_NOT_ALLOWED` |
| 创建结算批次 | 分账为待结算、未冻结/冲销/结算，收款账户已核验 | `FINANCE_SHARE_FROZEN`、`FINANCE_SETTLEMENT_NOT_PAYABLE` |

### 14.5 审计最低要求

以下接口动作必须在同一事务或可靠事件链路内写入 `biz_status_history` 和 `sys_audit_log`：登录/登出、验证码、实名、IP 提交/审核/上架、方案启停、授权购买/支付、合同生成、作品审核确权、商品/活动提交及自动发布、订单支付/发货/签收、核销、售后/退款、分账/冲销/结算、文件下载、导出、存证提交/回执/重试、账号停用和风险处置。

审计字段至少包含操作人、角色、对象类型和编号、前后状态、结果、原因、请求号、幂等键（如有）、操作时间、客户端 IP；涉及敏感数据时只保存脱敏摘要或 Hash。

## 15. 关键接口验收路径

1. 城市运营创建 IP → 提交 → 版权/合规确权 → 存证成功 → 自动进入 `LISTED`；退回补充路径可完整回放。
2. 创作者注册、实名后，才能创建授权订单；企业/工作室委托书仅作资料留存。待支付 30 分钟自动关闭并释放名额。
3. 微信支付成功回调或主动查单确认成功后，授权、合同、凭证、范围快照一次性产生；同一创作者同一 IP 不能同时持有两笔有效授权，到期后可重新购买。
4. 作品经过检测、版权初审、合规复核、确权；商品只能关联已确权作品。
5. 商品/活动提交后仅自动校验，接口不能绕过检测或人工发布；检测失败、疑似或异常均不可发布。
6. 商品订单预占库存、支付、发货、物流签收、确认收货/自动完成、售后退款和分账冲销均可幂等回放。
7. 活动收费/免费预约、名额占用、一次性核销、取消退款、活动结束未核销过期均符合状态机。
8. 普通授权自动分账，独家买断仅处理买断费用分配且后续收入不分账；线下付款必须上传凭证。
9. 存证成功必须存在回执号；上链失败保留失败/重试记录，任何接口不得伪造成功。

## 16. 后续 OpenAPI 产物拆分

本文件确定接口语义与业务契约。正式开发时建议从本文件拆出：

1. `openapi-admin.yaml`：管理后台、创作者、履约、财务、平台管理接口；
2. `openapi-consumer.yaml`：消费者 H5 公开浏览、登录、订单、预约和售后接口；
3. `openapi-integrations.yaml`：短信、物流、实名、检测、支付、存证适配与回调；
4. 本文第 14 章：已合并按接口分组的角色、数据范围、状态前置条件、错误码与审计动作；不再单独拆分错误码与权限矩阵文档。

在生成 OpenAPI YAML 前，不需要新增业务确认；供应商 URL、鉴权方式、回调签名字段、文件大小/格式限制和具体退款模板参数属于实施配置，后续填入环境配置与适配器文档即可。
