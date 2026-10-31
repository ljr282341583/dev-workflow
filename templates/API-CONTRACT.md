# 接口契约 · <项目名>

> 规则：**先定契约，再写代码。** 前端先按契约接 mock，后端按契约实现。
> 契约改了必须先改这份文档，再通知对方——不许口头改。

- **Base URL**：`http://localhost:3000/api`（开发） / `https://____`（线上）
- **版本**：v1
- **数据格式**：JSON，UTF-8
- **统一响应包**：

```json
{ "code": 0, "message": "ok", "data": {} }
```

- **错误码约定**

| code | 含义 | 前端表现 |
| --- | --- | --- |
| 0 | 成功 | — |
| 400 | 参数错误 | 字段旁提示具体错误 |
| 401 | 未登录/凭证失效 | 跳登录，保留当前页意图 |
| 403 | 无权限 | toast + 返回 |
| 404 | 资源不存在 | 空态页 |
| 429 | 请求过频 | toast「操作太快，稍后再试」 |
| 500 | 服务异常 | 错误态 + 重试按钮 |

- **金额单位**：分（整数），前端负责格式化
- **时间**：ISO 8601 带时区（`2026-11-01T02:08:34+08:00`），列表展示按本地时区
- **分页**：`page`（从 1 开始）/ `pageSize`（默认 20，最大 100）；响应 `{ list, total, page, pageSize }`
- **鉴权**：`Authorization: Bearer <token>`
- **幂等**：写操作带 `Idempotency-Key`

---

## 1. 接口清单

| # | 方法 | 路径 | 说明 | 状态 |
| --- | --- | --- | --- | --- |
| 1 | GET | /items | 列表 | 已联通 / mock |
| 2 | GET | /items/:id | 详情 | |
| 3 | POST | /items | 新建 | |
| 4 | PATCH | /items/:id | 更新 | |
| 5 | DELETE | /items/:id | 删除 | |

---

## 2. 接口详情

### GET /items

**Query**

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| page | number | 否 | 默认 1 |
| pageSize | number | 否 | 默认 20 |
| keyword | string | 否 | 模糊搜索 |
| status | string | 否 | 枚举：all / active / done |

**响应**

```json
{
  "code": 0,
  "message": "ok",
  "data": {
    "list": [
      { "id": "1", "name": "示例", "amount": 1200, "status": "active", "createdAt": "2026-11-01T02:08:34+08:00" }
    ],
    "total": 1,
    "page": 1,
    "pageSize": 20
  }
}
```

**异常**：500 → 前端展示错误态并允许重试

---

### POST /items

**Body**

```json
{ "name": "示例", "amount": 1200 }
```

**校验**：`name` 1–50 字符；`amount` 为非负整数（分）；重复提交按 `Idempotency-Key` 去重

**响应**：返回新建对象（含 `id`）

---

## 3. mock 约定

- mock 文件位置：`src/mocks/handlers.*`
- 与契约**同构**，前端切真接口时只改 `baseURL` 与请求封装，不改调用处
- 必备 mock 场景：正常、空列表、慢响应（3s）、500 错误、401 过期

## 4. 变更记录

| 日期 | 变更 | 影响端 | 已通知 |
| --- | --- | --- | --- |
| | | | |
