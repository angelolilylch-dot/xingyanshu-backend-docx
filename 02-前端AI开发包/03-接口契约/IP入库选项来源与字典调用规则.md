# IP 入库选项来源与字典调用规则

更新日期：2026-11-25
适用页面：B02 城市 IP 管理（IP 新建、编辑、补充材料）
适用接口：`POST/PATCH /api/v1/ips`

## 1. 强制规则

前端只能调用接口契约中明确存在、且后端已允许的字典类型。禁止为了“猜测”下拉选项而轮询别名或相近名称；一次下拉加载失败后，不得改用其他未约定的字典路径再次尝试。

下列路径均不是当前后端允许的字典类型，B02 不得调用：

```text
/api/v1/dictionaries/RIGHT_ACQUISITION_METHOD
/api/v1/dictionaries/RIGHT_DOCUMENT_TYPE
/api/v1/dictionaries/RIGHT_DOC_TYPE
/api/v1/dictionaries/RIGHT_DOCUMENTS
/api/v1/dictionaries/DOCUMENT_TYPE
/api/v1/dictionaries/ACQUISITION_METHOD
/api/v1/dictionaries/RIGHTS_ACQUISITION_METHOD
/api/v1/dictionaries/IP_ACQUISITION_METHOD
/api/v1/dictionaries/RIGHT_TYPE
/api/v1/dictionaries/DCI_STATUS
/api/v1/dictionaries/LICENSE_TYPE
```

调用未允许类型时，后端返回 `400 VALIDATION_FORMAT_INVALID` 与“请求数据格式不正确”。这表示字典类型不在服务端白名单内，**不是 HTTP 请求方式错误**；前端不得统一显示为“请求方式不正确”。

## 2. B02 已允许的动态选项来源

| 页面字段 | 唯一数据来源 | 请求方式 | 前端显示/提交 |
| --- | --- | --- | --- |
| `ipType`（IP 类型） | 标准字典 | `GET /api/v1/dictionaries/IP_TYPE` | 显示 `name`，提交 `code` |
| `rightHolder.holderType`（权利人类型） | 标准字典 | `GET /api/v1/dictionaries/RIGHT_HOLDER_TYPE` | 显示 `name`，提交 `code` |
| `applicableProductTypes`（适用商品类型） | 标准字典 | `GET /api/v1/dictionaries/APPLICABLE_PRODUCT_TYPE` | 多选，提交 `code[]` |
| `applicableActivityTypes`（适用活动类型） | 标准字典 | `GET /api/v1/dictionaries/APPLICABLE_ACTIVITY_TYPE` | 多选，提交 `code[]` |
| 地域/文化/品类/商业化标签 | 标签主数据 | `GET /api/v1/tags?tagType=REGION/CULTURE/CATEGORY/COMMERCIAL` | 多选，提交标签 `code[]` |
| `mainCityOrgId`（主归属城市） | 已启用城市组织 | `GET /api/v1/admin/orgs/options` | 仅显示 `orgType=CITY` 且 `status=ACTIVE` 项；显示 `orgName/cityCode`，提交 `id` |
| 授权方案 | 已启用授权方案 | `GET /api/v1/auth-plans` | 提交 `authPlanVersionId` |
| 分账模板 | 已启用分账模板 | `GET /api/v1/distribution-templates` | 提交 `distributionTemplateId` 和各参与方比例 |

`mainCityOrgId` 不是行政区划字段，禁止提交城市名称、地区编码或手工文本替代组织 ID。地区查询 `GET /public/regions` 仅在其他需要选择行政区划的页面使用，不替代主归属城市。

## 3. 固定选项：不得请求字典

### 3.1 权利取得方式

`rightHolder.acquisitionMethod` 已由 IP 接口契约定义为固定枚举。前端以本地常量渲染下拉框，提交稳定代码，不请求任何 `RIGHT_*` 或 `ACQUISITION_*` 字典。

| 提交值 | 页面名称 |
| --- | --- |
| `ORIGINAL_CREATION` | 原始创作 |
| `TRANSFER` | 权利转让取得 |
| `LICENSE` | 授权取得 |
| `INHERITANCE` | 继承取得 |
| `ENTRUSTED_MANAGEMENT` | 委托管理 |
| `OTHER` | 其他 |

联动规则：选择 `ORIGINAL_CREATION` 时，`creationProcessVideos` 至少有一项；选择其他方式时可上传视频，若未上传视频则必须填写 `creationProcessVideoExemptionReason`。视频和豁免原因不得同时提交。

### 3.2 资源来源

`sourceType` 当前为必填字符串，但尚未注册为标准字典，也没有完整的后端枚举白名单。前端不得请求 `/dictionaries/SOURCE_TYPE` 或 `/dictionaries/IP_SOURCE_TYPE`。

当前页面采用受控的本地选项；已约定/已有业务数据的代码包括 `CITY_COLLECTION`（城市征集）与 `CITY_OPERATION_SOLICITATION`（城市运营征集）。新增来源类型前，必须先由产品、接口契约和后端统一稳定代码；只有后端新增标准字典并开放白名单后，前端才改为动态加载。

### 3.3 权属证明类型

`rightDocuments[].documentType` 必填，当前后端校验“非空且长度不超过 40”，尚未开放 `RIGHT_DOCUMENT_TYPE` 标准字典，也没有后端白名单校验。因此当前实现要求：

1. 前端使用受控下拉框，不允许自由文本输入；
2. 前端不得调用任何 `RIGHT_DOCUMENT_TYPE`、`RIGHT_DOC_TYPE` 或 `DOCUMENT_TYPE` 字典路径；
3. 页面统一使用下列稳定代码，显示中文名称、提交代码：

| 提交值 | 页面名称 |
| --- | --- |
| `COPYRIGHT_REGISTRATION` | 著作权登记证书 |
| `COPYRIGHT_CERTIFICATE` | 版权证书 |
| `TRANSFER_AGREEMENT` | 权利转让协议 |
| `LICENSE_AGREEMENT` | 授权许可协议 |
| `INHERITANCE_CERTIFICATE` | 继承证明 |
| `AUTHORIZATION_LETTER` | 授权委托书 |
| `IDENTITY_CERTIFICATE` | 权利人身份证明 |
| `OTHER` | 其他权属证明 |

后端后续如需允许平台统一维护或动态扩展证明类型，必须同时完成：新增 `RIGHT_DOCUMENT_TYPE` 白名单与初始化数据、对 `documentType` 实施白名单校验、更新 OpenAPI/接口说明和测试。完成前，前端不能预先调用该字典接口。

## 4. 错误展示规范

统一请求层必须保留服务端完整错误对象：`code`、`message`、`requestId`、`data.field`、`data.resourceType`、`data.action`。

| 情况 | 页面行为 |
| --- | --- |
| `400 VALIDATION_FORMAT_INVALID` | 直接显示服务端 `message`；记录请求 URL 和字典类型；不得显示“请求方式不正确” |
| `401` | 按登录态过期流程刷新或跳转登录 |
| `403 AUTH_FORBIDDEN` | 显示无权限，不得继续探测资源或其他接口 |
| `404/422` 且有 `data.field` | 定位、高亮对应表单控件，并显示服务端 `message` |
| `500/503` | 显示“服务暂不可用，请稍后重试”，保留 `requestId` 用于排查 |

未知错误码同样必须显示服务端 `message` 和 `requestId`，不得退化为“操作失败”或“请求方式不正确”。

## 5. 前端验收

1. B02 网络请求中不再出现第 1 节所列路径；
2. 权利取得方式与权属证明类型均为受控选项；
3. IP 类型、权利人类型、适用商品/活动类型、标签和主归属城市分别使用第 2 节规定的数据源；
4. 所有失败提示保留后端原始 `message` 和 `requestId`；
5. `ORIGINAL_CREATION` 的创作过程视频必填规则在前端提交前即可阻止并定位提示。
