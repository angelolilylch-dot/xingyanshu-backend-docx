# 前端 AI 变更摘要

## 2026-09-28：API-CNT-01 二创作品闭环已完成

`POST/GET /api/v1/creator/works`、作品新版本重提交、版权初审、合规复核与确权存证接口均已可联调。创作者提交前须从本人有效授权的冻结/已存证素材包选择 `materialItemIds`，文件先上传后只提交文件 ID；不得自行传 IP ID。`TEXT_REJECTED`、`TEXT_CHECK_ERROR`、`RETURNED`、`REJECTED` 只能新建版本重提交，`RIGHTS_CONFIRMED` 才能作为后续商品候选作品。已完成真实 MySQL 与 JWT HTTP 验收；商品、活动和消费者 H5 仍未实现，不得提前开放相关入口。

## 2026-09-23：IP 详情补齐确权、素材包与 DCI Hash

IP 详情页调用 `GET /api/v1/ips/{ipId}` 后，确权完成的 IP 应展示三个可复制但不可编辑的 Hash 区块：`rightsEvidence.hashValue`（IP 权属确权快照 SHA-256）及 `rightsEvidence.transactionHash`（链上存证交易 Hash）；`materialPack.manifestHash`（冻结交付素材清单 Hash）及 `materialPack.evidenceTransactionHash`；`dciAssistance.submissionManifestHash`（如走 DCI 代办）。同时展示对应状态、回执号、锁定/冻结/存证时间。`materialItems[]` 展示文件 SHA-256、角色、排序、交付标识和范围，不能展示 `storageKey` 或提供后台详情页的直接下载链接。IP 列表只显示 `materialPackStatus/materialPackEvidenceStatus/materialPackFrozenAt` 摘要。

## 2026-09-23：IP 冻结素材包与 C04 授权素材下载已完成

B02 保存 IP 的请求必须提交必填 `materialPack`：`packName/scopeDescription/items[]`，每项包含 `fileId/materialRole/sortNo/deliverable/scopeDescription`。DCI 代办会锁定素材清单；代办取得证书后，使用 `POST /api/v1/ips/{ipId}/dci-certificate`（`certificateNo/certificateFileId`、`If-Match-Version`、`Idempotency-Key`）回填，不能再编辑原 IP 或素材包。C04 详情进入时调用 `GET /api/v1/creator/authorizations/{authorizationId}/material-packs`；仅展示接口返回的冻结、已存证、可交付素材。单项下载调用 `POST .../material-downloads`，请求只传 `materialItemId`，禁止传裸 `fileId`；成功使用 `downloadUrl/expiresAt`。遇到 `AUTHORIZATION_EXPIRED`、`MATERIAL_PACK_NOT_FROZEN`、`MATERIAL_PACK_EVIDENCE_PENDING`、`MATERIAL_PACK_SNAPSHOT_MISMATCH` 或 `MATERIAL_ITEM_NOT_DELIVERABLE` 时展示对应不可下载原因，不得重试支付或绕过授权。

## 2026-09-23：C04 购买记录页面字段、数据和操作补齐

「我的授权 / 购买记录」必须默认有演示数据，不能要求先走支付演示才能展示。列表每条记录显示 `paidAt`、`authOrderNo`、`authorizationNo`、IP 名称/编号、方案和 `authorizationMode`、有效期、地区、场景、内容类型、`amount/currency`、授权状态、`contract.status`、`certificate`、`evidence.status/receiptNo/transactionHash`。提供状态筛选、详情、合同/凭证下载、异步刷新与哈希复制；仅 `downloadReady=true` 才可下载。存证处理中、重试中或失败都不得改写支付成功和有效授权状态。


## 2026-09-23：AUT-03 已完成，可实现测试支付和购买记录

测试环境 C03 增加“模拟支付成功（仅测试环境）”，使用新的 `Idempotency-Key` 调用 `POST /api/v1/payments/mock/pay`，请求仅传 `bizType=AUTH_ORDER` 与 `bizOrderId`；生产环境完全隐藏。接口成功后支付和授权立即生效，直接跳转购买记录，不等待 PDF 或存证。购买记录/详情使用 `GET /creator/authorizations` 与 `GET /creator/authorizations/{authorizationId}`；`contract.downloadReady` 或 `certificate.downloadReady` 为真后再调用对应下载接口取得短链。`PENDING_EVIDENCE`、`EVIDENCE_RETRYING`、`EVIDENCE_FAILED` 都不能被显示为支付失败，只有 `EVIDENCED` 展示并复制回执号/交易哈希。真实微信支付 V3 仍未完成，属于 `API-FND-05-R1`。


> 用途：每次涉及前端的需求、字段、接口或原型修改完成后，在本文件追加一段可直接发送给前端 AI 的文字摘要。前端 AI 先读取最新一条摘要即可开始改动；出现冲突或需要字段细节时，再回查 `前端修改说明.md`、页面字段清单和 OpenAPI。

## 2026-09-11：新增前端字段控件设计规范

请将《前端字段控件设计规范.md》作为原型和页面实现的强制细化规范。它逐项规定当前可联调范围内字段是单行文本、多行文本、下拉、单选、复选、日期、数值、比例、上传或只读展示，并统一定义 IP 封面、详情图、版权证明、DCI 证书、评估报告和委托书的文件格式、单文件大小、数量及上传表现。原型不得以通用输入框替代该规范指定的控件；B02 必须完整显示八个分区，B03 必须保留三个页签。

## 2026-09-11：原型已按字段控件规范第一轮细化

原型已同步调整：后台登录不显示角色下拉，仅保留账号、密码和图形验证码；账号创建的角色、数据范围改为单选组；组织类型改为单选组、城市编码改为城市选择；授权方案新增表单补齐授权方式、期限、地区、场景、商业化/二创/N 创权限、内容类型、名额、价格、模板和方案说明；分账模板改为参与方复选并明确不填比例。B02 的封面、详情图、版权证明、DCI、评估报告上传控件已显示允许格式、单文件大小与多文件规则。前端实现仍以《前端字段控件设计规范.md》逐项比对，不得只复制原型的静态文字。

## 2026-09-11：按业务域重构当前可联调原型菜单

请按业务域而不是单个操作拆菜单。平台管理员侧栏只保留四项：`账号与组织`（页签：账号管理、组织管理）、`平台配置`（页签：平台参数、地区管理、标签管理、固定售后模板）、`IP 管理`（列表、详情和自动上架结果均在域内）和`授权方案管理`（页签：授权方案、分账结构模板；详情、草稿、审核、启停均在域内）。城市运营侧栏只保留`城市 IP 管理`，在该域内完成列表、新建、草稿编辑、补充材料、评估报告、DCI 代办、提交合规和进度查询。版权/合规侧栏只保留`IP 合规审核`，页签为“待审核 IP / 审核详情 / DCI 代办”；不得出现平台管理员的人工上架动作。文件上传、文件信息、下载短链只作为各表单通用能力，不设主菜单。

## 2026-09-17：B02 新增 IP 的 DCI 代办一并保存

B02 新增 IP 表单把 DCI 代办设计为 `dciAssistanceRequested` 复选框，不设置单独“申请 DCI 代办”或“保存草稿”按钮。勾选后显示 `dciAssistanceRequest.contactName/contactMobile/preferredContactTime/requestNote`，其中联系人姓名、手机号必填；点击一次“保存 IP”调用 `POST /api/v1/ips`，后端同一事务创建 IP 与 DCI 代办申请。DCI 代办和 `dciCertificateNo/dciCertificateFileId` 必须互斥：勾选代办时禁用并清空证书字段；填写编号或上传文件时自动取消并清空代办字段。后端会拒绝同时提交两组数据。已保存 IP 后才需要补申请时，才调用 `POST /api/v1/ips/{ipId}/dci-assistance-requests`。

（历史说明，已废止）后台登录曾设计为角色下拉和 `loginType` 分支；当前不显示角色下拉、不传 `loginType`，由服务端自动识别账号类型。

（历史说明，已废止）当前统一登录调用 `POST /api/v1/auth/login`，仅提交 `account`、`password`、`captchaId`、`captchaCode`，不传 `loginType`；创作者仍使用手机号作为账号。

## 2026-09-09：原型按已实现接口重做，B02 为完整表单

前端实现时，不要再把管理后台页面当作通用表格和通用弹窗。已实现接口对应的账号、组织、平台参数/地区/标签、售后模板、文件服务、IP 入库、授权方案/分账模板和 B03 合规审核，均已有专用原型。B02 必须按八段式表单开发：长内容字段用 `textarea`，枚举用下拉/单选，商品/活动类型与标签用复选，证明/图片/DCI/评估报告用文件上传；DCI 缺失时可保存草稿和申请代办，但不能提交审核。敏感检测、存证/审计记录、角色权限配置暂不做独立管理列表，因为现阶段无对应查询维护 API。

## 2026-09-09：原型菜单仅展示可联调页面

当前原型只保留已实现接口支持的三个后台角色：平台管理员、城市运营人员、版权/合规人员；只显示账号、组织、基础配置、售后模板、文件服务、IP、方案模板和合规确权页面。消费者、创作者、履约、财务、看板、商品、活动、订单、检测/审计/存证列表、角色权限配置等均暂时隐藏，前端不得把它们当作已可开发联调页面。

## 2026-09-09：B03 改为以待审核 IP 为主工作队列

版权/合规进入 B03 时，先请求 `GET /api/v1/compliance/ips/pending?keyword=&dciCertificateStatus=UPLOADED|VERIFIED&pageNo=1&pageSize=20`，不要默认进入 DCI 代办。接口只返回 `PENDING_COMPLIANCE` IP；列表使用 `ipNo/ipName/mainCityOrgName/rightHolderNameMasked/dciCertificateStatus/authPlanName/distributionTemplateName/hasEvaluationReport/nextAction/updatedAt`。`nextAction=VERIFY_DCI` 打开 DCI 核验，`CONFIRM_RIGHTS` 打开确权表单；点击项目后调用 `GET /api/v1/ips/{ipId}` 获取完整材料和当前 `version`。DCI 代办保留为第二页签，继续使用已有接口和敏感联系人保护规则。

## 2026-09-11：B03 确权成功后自动上架

B03 仅版权/合规可使用。DCI 代办队列改为 `GET /api/v1/compliance/dci-assistance-requests`，完整返回 `contactName/contactMobile` 用于实际联系；此类数据不可缓存、导出或写入前端日志。处理进度调用 `POST /api/v1/compliance/dci-assistance-requests/{requestId}/handle`，请求 `handlingStatus/handlingNote` 并带 `If-Match-Version`、`Idempotency-Key`。DCI 核验调用 `POST /api/v1/ips/{ipId}/dci-verifications`，仅传 `result=PASS|RETURN`、`comment` 和两个请求头。确权/退回调用 `POST /api/v1/ips/{ipId}/rights-reviews`：退回必须填写 `comment`，确认必须提交最终 `authPlanVersionId`、`distributionTemplateId`、全部 `distributionItems[]`。返回 `502` 时表示存证未取得成功回执，IP 仍为待合规状态；取得存证成功回执后，系统在同一事务中直接将 IP 置为 `LISTED`、设置 `mallVisible=true`，前端不得显示人工上架按钮或调用 `/ips/{ipId}/list`。暂停、恢复、下架接口后端均已实现，风险处置按当前范围暂缓。

## 2026-09-09：已完成接口的查询与字段命名统一

请按真实接口收紧已完成功能：B01 `GET /api/v1/ips` 仅传 `keyword/pageNo/pageSize`，其中 `keyword` 仅搜索 IP 编号和 IP 名称；不要再传城市、IP 类型、DCI、授权方式或状态筛选。B04 `GET /api/v1/auth-plans` 仅传 `enabledOnly`，不要传授权方式、内容类型或方案状态筛选。A05 后台地区仅支持 `keyword`，地区列表字段读取 `code/name`；后台标签仅支持 `tagType/keyword`。IP、授权方案及分账模板的列表/详情响应已统一为 camelCase，读取 `ipNo`、`dciCertificateStatus`、`distributionTemplateId`、`participantType` 等字段，不读取任何下划线字段。管理后台原型已移除 B01 无效筛选，并移除 B04 无效的授权方式筛选。

## 2026-09-07：新增组织管理和动态菜单规则

请新增 A09「组织管理」页面 `/platform/organizations`，仅平台管理员可访问。组织接口已经完成，可直接联调：`GET/POST /api/v1/admin/orgs`、`GET/PATCH /api/v1/admin/orgs/{orgId}`、`PATCH /api/v1/admin/orgs/{orgId}/status`，账号页面的组织下拉使用 `GET /api/v1/admin/orgs/options`。A03 不允许手工填写 `orgId`；城市运营账号或 `CITY` 数据范围只能绑定 `orgType=CITY` 且有 `cityCode` 的已启用组织。城市组织必须有上级组织和城市编码。编辑和状态操作必须将当前 `version` 放入 `If-Match-Version`；组织仍有启用账号或启用下级组织时，后端返回 `409 RESOURCE_CONFLICT`。后台导航不按角色名称写死：登录与刷新时调用 `/auth/me`，用 `data.menus[].resourceCode` 过滤前端固定的路由、图标和排序配置，用 `data.permissions[]` 控制操作按钮。

## 2026-09-07：A03 后台账号管理接口已完成

A03「后台账号管理」后端接口已经可以联调：`GET/POST /api/v1/admin/accounts`、`GET/PATCH /api/v1/admin/accounts/{userId}`、`PATCH /api/v1/admin/accounts/{userId}/status`，仅平台管理员可调用。新增不需要 `Idempotency-Key`；编辑和启用/停用必须把详情或列表返回的 `version` 原样放到 `If-Match-Version` 请求头。列表只用 `mobileMasked` 展示手机号；编辑页先请求详情，并把详情中的 `data.mobile` 回显到手机号输入框。所有接口不返回初始密码、密码 Hash 或令牌；停用成功后该账号所有已有登录态立即失效。测试环境 CORS 已允许 `*`，可直接从任意本地前端端口联调；生产环境必须改为精确来源白名单。账号或手机号重复时处理 `409 RESOURCE_CONFLICT`，版本过期时处理 `409 VERSION_CONFLICT` 并刷新详情。

## 2026-09-07：后台账号数据范围与单角色约束

请修改统一管理后台的 A03「后台账号管理」：一期每个后台账号只能选择一个角色，原角色多选控件改为单选。新增“数据范围”字段并在账号列表、详情和编辑回显中展示；页面中文选项固定为“全平台、本城市、本组织、仅本人”。接口提交和接收时，数据范围仍使用固定编码 `ALL`、`CITY`、`ORG`、`SELF`，前端不得直接显示编码，应显示中文名称。后端会在接口中返回 `dataScope` 和 `dataScopeName`；前端可据此隐藏无关菜单或数据，但不得作为权限安全判断。涉及文件：A03 页面、账号列表列、账号新增/编辑表单、登录后权限初始化处理。请勿实现多角色选择。

## 2026-09-07：后台登录图形验证码接口

后台登录页初始化和每次点击“刷新验证码”时调用 `GET /api/v1/auth/captcha`。接口无需 Token，建议携带新的 `X-Request-Id`。成功后将 `data.imageBase64` 直接赋值给验证码图片，将 `data.captchaId` 保存在登录表单状态；提交登录时与用户输入的 `captchaCode` 一起发送。图片为完整 `data:image/png;base64,...` URL，不需要再拼接前缀。请求失败时显示“验证码加载失败”并允许重试；不要在前端保存或校验验证码答案。

## 2026-09-10：统一登录接口替换旧后台登录接口

（历史说明，已废止）统一登录不再接收 `loginType`；后台账号和创作者均需先获取图形验证码，提交账号、密码和验证码，登录后按服务端返回的主体类型初始化页面。

## 2026-09-07：后台登录与令牌刷新接口（已替换）

本节为历史记录，实施以 2026-09-10 的统一登录说明为准；旧地址已不可调用。令牌刷新规则保持不变：后台与创作者访问令牌过期时调用 `POST /api/v1/auth/refresh`，请求体为 `{ "refreshToken": "{当前最新刷新令牌}" }`，不携带 `Authorization`；同一时刻仅允许一个刷新请求。成功后原子替换内存中的两个令牌并重放原请求，失败或重放后再次返回 `401` 时清除登录态并跳转登录页。旧 refreshToken 不能再次使用。

## 2026-09-07：后台注销接口

后台用户点击退出登录时调用 `POST /api/v1/auth/logout`，请求头携带当前 `Authorization: Bearer {accessToken}`，无需请求体。收到 `code: "OK"` 后立即清除前端内存中的 `accessToken`、`refreshToken`、用户资料和菜单权限，并跳转登录页；不要等待页面刷新。接口返回 `401` 或 `AUTH_TOKEN_EXPIRED` 时也按已退出处理。注销会同时使该会话的刷新令牌失效，因此注销后不得尝试自动刷新或重放旧请求。

## 2026-09-07：后台当前登录信息接口

后台进入工作台、浏览器刷新后调用 `GET /api/v1/auth/me`，请求头携带 `Authorization: Bearer {accessToken}`。成功后用 `data.user` 覆盖当前用户资料，用 `data.roles` 记录唯一角色，用 `data.menus` 构建可见导航，用 `data.permissions` 控制按钮可见性；数据范围显示 `data.user.dataScopeName`，不要显示编码。刷新令牌成功后，旧访问令牌会立即返回 `401`，因此必须先替换内存中的访问令牌再调用 `/auth/me` 或重放业务请求。`/auth/me` 返回 `401` 时清除登录态并回到登录页。

## 2026-09-07：后台账号格式规则

后台登录和后台账号管理中的 `username` 统一为 `2-50` 位，仅允许英文字母、数字、下划线 `_`、连字符 `-`，且首尾必须为英文字母或数字；不支持手机号登录。前端使用正则 `^[A-Za-z0-9][A-Za-z0-9_-]{0,48}[A-Za-z0-9]$` 在提交前校验，并在收到 `VALIDATION_FORMAT_INVALID` 的 `fieldErrors.username` 时定位账号输入框；服务端仍会强制校验，前端校验不可替代服务端。

## 2026-09-07：A03 后台账号管理接口待联调

A03 账号管理将使用 `GET/POST /admin/accounts`、`GET/PATCH /admin/accounts/{userId}`、`PATCH /admin/accounts/{userId}/status`，仅平台管理员可见。列表绑定 `data.items[]`，字段为 `id`、`username`、`displayName`、`mobileMasked`、组织、唯一角色、`dataScopeName`、`status`、`lastLoginAt`。新增表单提交 `username`、`initialPassword`、`displayName`、`mobile`、`orgId`、`roleCode`、`dataScope`；编辑时不显示或提交 `username`、`initialPassword`，仅提交显示名、手机号、组织、角色、数据范围与版本。启用/停用提交 `status`、`reason`、版本；停用后当前账号所有登录态失效。接口尚未实现，前端可先按 OpenAPI 准备页面和 Mock 数据，联调时以最终接口开发记录为准。

## 2026-09-07：A02 仅集团管理层经营看板

A02 `/dashboard` 仅集团管理层可访问，调用 `GET /auth/me` 与 `GET /dashboard/overview`，展示全平台经营 KPI、趋势和风险摘要，只读。平台管理员、城市运营、版权/合规、创作者、财务、履约客服登录后不进入 `/dashboard`，按 `/auth/me` 返回的第一个可见菜单跳转对应业务页。`/dashboard/city-ip`、`/dashboard/risks` 同样仅集团管理层使用。

## 2026-09-08：A05/A06 与基础数据接口已完成

平台管理员的基础数据接口已可联调。A05 使用 `GET /api/v1/admin/configs` 获取 `data.items[]`，每项包含 `configKey`、非敏感 `value`、`valueType`、`isSecret`、敏感配置的 `hasValue`、`version`、`updatedAt`；更新使用 `PATCH /api/v1/admin/configs/{configKey}`，请求体为 `{ "value": "...", "reason": "..." }`，并将当前 `version` 放入 `If-Match-Version`。密钥不会返回实际值，也不能通过页面保存。

A06 使用 `GET/POST /api/v1/admin/after-sale-templates` 查询或新建首个固定模板；模板字段为 `templateNo`、`templateName`、`bizType`、`conditions`、`refundRule`、商品专用的 `returnFeeBearer`。修改规则时必须调用 `POST /api/v1/admin/after-sale-templates/{templateId}/versions` 创建新版本，不能做原地编辑；后端会自动停用旧版本。启停使用 `PATCH /api/v1/admin/after-sale-templates/{templateId}/status`，请求 `{ "enabled": false, "reason": "..." }` 并携带版本头。

## 2026-09-08：A05 调整为三个选项卡，固定字典已可读取

A05 `/platform/config` 不新增侧边栏菜单，页面内改为“平台参数、地区管理、标签管理”三个选项卡，默认打开平台参数。地区管理使用 `GET/POST /api/v1/admin/regions` 与 `PATCH /api/v1/admin/regions/{regionId}/status`；标签管理使用 `GET/POST /api/v1/admin/tags` 与 `PATCH /api/v1/admin/tags/{tagId}/status`。地区、标签的停用请求均提交 `{ "enabled": false, "reason": "..." }`，所有更新带当前版本到 `If-Match-Version`。

固定枚举已由后端初始化写入，可通过 `GET /api/v1/dictionaries/{dictType}` 只读获取。前端显示接口 `name`，保存时提交 `code`，不再硬编码 IP 类型、授权方式、DCI 状态、售后类型等中文选项；固定枚举不放在 A05 编辑。

## 2026-09-08：通用文件上传接口已完成

所有后台文件上传统一调用 `POST /api/v1/files`，请求为 `multipart/form-data`，仅传字段 `file`。成功后使用 `data.id` 作为业务接口的 `fileId`，可展示 `originalName`、`mimeType`、`fileSize`、`fileHash`、`uploadStatus`；不要传旧的 `fileRole`、`securityLevel`，也不要保存 COS 地址。图片仅支持 JPG/JPEG/PNG/WebP 且最大 10MB，文档仅支持 PDF/DOC/DOCX/XLS/XLSX 且最大 30MB，媒体仅支持 MP4/MP3/WAV 且最大 200MB。

查看元数据调用 `GET /api/v1/files/{fileId}`；下载前调用 `POST /api/v1/files/{fileId}/download-url`，跳转响应中的 `data.downloadURL`，地址会过期。需对 `413 FILE_SIZE_EXCEEDED`、`400 FILE_TYPE_NOT_ALLOWED`、`400 FILE_CONTENT_INVALID` 和 `502 FILE_UPLOAD_FAILED` 分别给出明确失败提示。

地区与标签数据源统一为 `GET /api/v1/public/regions`、`GET /api/v1/tags`、`GET /api/v1/dictionaries/{dictType}`。后续 B02、C06、C07 的地区、四类标签及固定模板下拉必须从这些接口读取；不要再使用旧的 `/dict-items` 路径或在前端写死枚举中文名。地区筛选支持 `level=NATION|PROVINCE|CITY|DISTRICT` 与 `parentCode`；标签类型仅为 `REGION`、`CULTURE`、`CATEGORY`、`COMMERCIAL`。

## 2026-09-08：授权方案与分账结构模板

分账模板改为参与方结构模板，不再填写比例，也不需要版权/合规审核。B05 使用 `GET/POST /api/v1/distribution-templates`、`GET/PATCH /api/v1/distribution-templates/{templateId}`、`PATCH /api/v1/distribution-templates/{templateId}/status`；模板只维护名称、类型、`items[].participantType`、`items[].sortNo` 与启用状态。模板中的全部参与方均为必选项，已被 IP 使用的模板后端会拒绝编辑或停用。

B02 选择授权方案和分账结构模板后，按模板 `items[]` 动态生成期望分账比例输入。提交 `distributionTemplateId` 与 `distributionItems[].participantType/distributionItems[].ratio`，比例合计必须为100%。B03 只确认或调整 IP 专属比例，不回写模板。

## 2026-09-09：已完成接口的管理后台原型同步

已同步修改 `星恒云创版权二创平台一期MVP角色原型_v0.4.html`。登录页补充图形验证码；A03/A05/A06/A07/A08 标明已完成接口的字段和边界。B02 现可演示选择授权方案、匹配分账结构模板、动态生成全部必选参与方的 IP 专属比例并实时校验合计 100%；B04 展示方案与模板摘要；B05 分为“授权方案”和“分账结构模板”两个选项卡，模板创建页不提供比例输入，并直观展示已绑定模板的锁定状态。

后续每完成一个影响用户界面的后端接口任务，必须同步更新 OpenAPI、字段绑定清单、前端变更说明和对应 HTML 原型；纯内部任务须明确标记无需修改原型。

## 2026-09-09：API-IP-01 城市 IP 入库接口已完成

B02 已可按真实接口开发。保存草稿用 `POST /api/v1/ips`，编辑用 `PATCH /api/v1/ips/{ipId}` 并传 `If-Match-Version`，读取回显用 `GET /api/v1/ips/{ipId}`；DCI 代办为 `POST /api/v1/ips/{ipId}/dci-assistance-requests`，评估报告为 `POST /api/v1/ips/{ipId}/evaluation-reports`，提交合规审核为 `POST /api/v1/ips/{ipId}/submit`。文件先上传至 `POST /api/v1/files`，业务请求只提交返回的 `fileId`。

选择授权方案后提交其 `authPlanVersionId`，选择匹配类型的分账结构模板后提交 `distributionTemplateId`。页面仍以 60%、20%、20% 形式让用户填写，但请求体的 `distributionItems[].ratio` 必须在提交前转换为 `"0.6"`、`"0.2"`、`"0.2"`；每个模板参与方均必填，后端要求总和严格等于 `1.000000`。DCI 未上传可保存、可申请代办，但提交会返回 `422 IP_DCI_CERTIFICATE_REQUIRED`。

## 2026-09-16：C02 创作者 IP 商城查询补齐

`GET /api/v1/creator/ip-mall` 已支持 `keyword`、`regionCode`、`ipType`、`tagCodes`、`authorizationMode`、`contentType`、`term`、`minPrice`、`maxPrice`、`sortBy`、分页。`tagCodes` 用英文逗号分隔，多个标签需同时匹配；排序支持 `priceAsc`、`priceDesc`、`updatedAtAsc`，默认按最近一次上架时间排序。响应卡片使用 `ipId/ipName/coverFileId/introduction/price/authorizationMode/termType/termValue/contentType/canPurchase/listedAt`，其中 `listedAt` 是最近一次进入 `LISTED`（已上架）状态的时间；所有 ID 以字符串传输。未实名、已有有效授权、普通授权名额售罄或独家买断已被其他创作者购买时仍可浏览，但 `canPurchase=false`；购买前仍应调用 `purchase-preview` 取得最终判定，独家买断售罄时其 `blockCode=AUTHORIZATION_QUOTA_SOLD_OUT`（授权名额已售罄）。

## 2026-09-22：错误响应可定位性升级

前端不得再依赖笼统的 `RESOURCE_NOT_FOUND` 文案猜测失败对象。404 按资源返回独立错误码，并在 `data.resourceType` 标识资源类型、在可定位到请求字段时通过 `data.field` 指向具体字段。例如封面失效返回 `COVER_FILE_NOT_FOUND + data.field=coverFileId`，权利证明文件失效返回 `RIGHT_DOCUMENT_FILE_NOT_FOUND + data.field=rightDocuments[].fileId`，授权方案版本失效返回 `AUTH_PLAN_VERSION_NOT_FOUND + data.field=authPlanVersionId`，分账模板失效返回 `DISTRIBUTION_PLAN_NOT_FOUND + data.field=distributionTemplateId`。前端应优先按 `data.field` 定位并高亮控件，同时显示服务端 `message`；未知新错误码仍显示 `message` 和 `requestId`，不能退化成“IP、文件或关联方案不存在”。

已同步覆盖 IP、文件、授权方案、分账模板、DCI 代办、创作者、实名记录、授权委托书、地区、标签、系统配置、售后模板、账号、组织和授权订单。`STATE_TRANSITION_NOT_ALLOWED` 可携带 `data.currentStatus/action/reasonCode`，前端用于刷新数据和给出动作级提示；`AUTH_FORBIDDEN` 仍不披露资源是否存在。

## 2026-09-24：API-CNT-01 二创作品提交与确权（历史实施说明，已于 2026-09-28 完成）

创作者作品页应提供作品名称、类型、简介、创作说明、完成时间、公开版权声明、五项声明、AI 辅助/共同创作说明、新增独创表达自评比例及维度、原始 IP 使用说明、预览文件、源文件、过程证据和已下载素材项选择。提交只传 `authorizationId`，IP 由服务端从授权中确定；前端不得自行传入或替换 IP。`newExpressionRatio` 取值 51–100，需明确标注为平台确权准入自评，不是法定版权比例。

提交前必须从 `GET /api/v1/creator/authorizations/{authorizationId}/material-packs` 获取可用冻结素材包及素材项，素材项以 `materialItemIds` 传入；服务端会校验授权有效、允许二创、素材包冻结/存证和购买时清单 Hash 一致。文本检测状态为 `PASS` 或 `REVIEW` 时进入版权初审，`BLOCK`、`ERROR` 显示对应状态并允许按后续重提交规则处理。版权合规后台依次调用作品版本审核和确权接口；确权后显示确权快照 Hash、存证状态和交易 Hash。原始 IP 权属不展示为创作者所有；界面须展示“创作者仅就经平台确认的新增独创表达主张权利”。
