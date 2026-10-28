# IP 本地联调与内容审核 Mock 说明

本地测试使用 `config/test.yaml`，内容审核配置为 `content_safety.provider: mock`，仅在 `app.environment=test` 时允许。Mock 审核返回 `PASS`，用于不依赖外部腾讯云 TMS 的真实 HTTP 联调。

生产环境必须使用完整的腾讯云 TMS 配置，禁止使用 Mock。

IP 创建请求中的 `rightDocuments` 只能包含有效材料；前端不得把 `documentType=null`、空编号、`fileId=null` 的占位行提交给后端。无材料时应删除该数组项。

本次验证：使用测试 SQL dump 在 `127.0.0.1:8080` 调用 `POST /api/v1/ips`，移除空权利证明项后返回 201，创建 DRAFT IP 成功。
