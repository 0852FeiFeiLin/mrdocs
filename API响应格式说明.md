# API 响应格式完整说明

## 📋 响应结构

### 顶层结构

```json
{
  "status": true,           // API 调用是否成功
  "data": {                 // 数据主体（只有 status=true 时存在）
    "results": [...],       // 搜索结果数组
    "total_docs": 9,        // 找到的文档总数
    "total_matches": 50,    // 匹配总数
    "page": 1,              // 当前页码
    "limit": 1,             // 每页文档数
    "elapsed_time": 19,     // 服务器处理耗时(ms)
    "search_params": {...}  // 搜索参数确认
  }
}
```

### results 数组结构

每个结果对象包含：

```json
{
  "doc_id": 9,                           // 文档ID（整数）
  "doc_name": "CDP动态调试...",           // 文档标题（字符串）
  "project_id": 14,                      // 文集ID（整数）
  "project_name": "WhatsApp 插件开发",    // 文集名称（字符串）
  "matches": [...],                      // 匹配数组
  "match_count": 3                       // 该文档的匹配数量
}
```

### matches 数组结构

每个匹配对象包含：

```json
{
  "line_num": 5,                        // 匹配行号（整数，从1开始）
  "line": "本文档记录了使用...",         // 匹配行完整内容（字符串）
  "match_positions": [[34, 37]],        // 匹配位置数组 [[起始, 结束], ...]
  "before_context": [                   // 前文数组
    {
      "line_num": 3,                    // 上下文行号
      "line": "## 1. 概述"              // 上下文行内容
    },
    {
      "line_num": 4,
      "line": ""
    }
  ],
  "after_context": [                    // 后文数组
    {
      "line_num": 6,
      "line": ""
    },
    {
      "line_num": 7,
      "line": "### 1.1 适用场景"
    }
  ]
}
```

## 🔑 关键字段说明

| 字段路径 | 类型 | 说明 | 示例 |
|---------|------|------|------|
| `status` | boolean | API 调用状态 | `true` |
| `data` | object | 数据主体 | `{...}` |
| `data.results` | array | 结果列表 | `[{...}]` |
| `data.results[].doc_id` | integer | 文档ID | `9` |
| `data.results[].doc_name` | string | **文档标题** | `"CDP动态调试..."` |
| `data.results[].project_id` | integer | 文集ID | `14` |
| `data.results[].project_name` | string | **文集名称** | `"WhatsApp 插件开发"` |
| `data.results[].matches` | array | 匹配列表 | `[{...}]` |
| `data.results[].matches[].line_num` | integer | **匹配行号** | `5` |
| `data.results[].matches[].line` | string | **匹配行内容** | `"本文档记录了..."` |
| `data.results[].matches[].match_positions` | array | 匹配位置 | `[[34, 37]]` |
| `data.results[].matches[].before_context` | array | **前文上下文** | `[{line_num, line}]` |
| `data.results[].matches[].after_context` | array | **后文上下文** | `[{line_num, line}]` |
| `data.total_docs` | integer | 文档总数 | `9` |
| `data.total_matches` | integer | 匹配总数 | `50` |
| `data.elapsed_time` | integer | 耗时(ms) | `19` |

## ✅ 正确的解析代码

### Python 示例

```python
import requests
import json

# 1. 发送请求
response = requests.get(
    'http://localhost:8000/api/search_content/',
    params={
        'token': '43c395f68784452784585da896cb5c66',
        'pattern': 'CDP',
        'search_mode': 'exact',
        'before_lines': 2,
        'after_lines': 2,
        'limit': 5
    }
)

# 2. 解析响应
data = response.json()

# 3. 检查状态
if not data['status']:
    print(f"错误: {data.get('data', '未知错误')}")
    exit(1)

# 4. 获取数据
result_data = data['data']

print(f"找到 {result_data['total_docs']} 个文档")
print(f"共 {result_data['total_matches']} 个匹配")
print(f"耗时 {result_data['elapsed_time']}ms\n")

# 5. 遍历结果
for doc_idx, doc in enumerate(result_data['results'], 1):
    print(f"【{doc_idx}】文档: {doc['doc_name']} (ID:{doc['doc_id']})")
    print(f"    项目: {doc['project_name']}")
    print(f"    匹配数: {doc['match_count']}")

    # 6. 遍历匹配
    for match_idx, match in enumerate(doc['matches'], 1):
        print(f"\n  匹配 {match_idx}:")
        print(f"    行号: {match['line_num']}")
        print(f"    内容: {match['line'][:100]}")  # 前100字符

        # 7. 显示前文（如果有）
        if match['before_context']:
            print(f"\n    前文:")
            for ctx in match['before_context']:
                print(f"      {ctx['line_num']}: {ctx['line'][:60]}")

        # 8. 显示匹配行
        print(f"\n    >> {match['line_num']}: {match['line'][:100]}")

        # 9. 显示后文（如果有）
        if match['after_context']:
            print(f"\n    后文:")
            for ctx in match['after_context']:
                print(f"      {ctx['line_num']}: {ctx['line'][:60]}")

    print("\n" + "="*70)
```

### JavaScript 示例

```javascript
// 1. 发送请求
const response = await fetch(
  'http://localhost:8000/api/search_content/?' +
  new URLSearchParams({
    token: '43c395f68784452784585da896cb5c66',
    pattern: 'CDP',
    search_mode: 'exact',
    before_lines: 2,
    after_lines: 2,
    limit: 5
  })
);

// 2. 解析响应
const data = await response.json();

// 3. 检查状态
if (!data.status) {
  console.error('错误:', data.data);
  return;
}

// 4. 获取数据
const resultData = data.data;

console.log(`找到 ${resultData.total_docs} 个文档`);
console.log(`共 ${resultData.total_matches} 个匹配`);
console.log(`耗时 ${resultData.elapsed_time}ms\n`);

// 5. 遍历结果
resultData.results.forEach((doc, docIdx) => {
  console.log(`【${docIdx + 1}】文档: ${doc.doc_name} (ID:${doc.doc_id})`);
  console.log(`    项目: ${doc.project_name}`);
  console.log(`    匹配数: ${doc.match_count}`);

  // 6. 遍历匹配
  doc.matches.forEach((match, matchIdx) => {
    console.log(`\n  匹配 ${matchIdx + 1}:`);
    console.log(`    行号: ${match.line_num}`);
    console.log(`    内容: ${match.line.substring(0, 100)}`);

    // 7. 显示前文
    if (match.before_context.length > 0) {
      console.log(`\n    前文:`);
      match.before_context.forEach(ctx => {
        console.log(`      ${ctx.line_num}: ${ctx.line.substring(0, 60)}`);
      });
    }

    // 8. 显示匹配行
    console.log(`\n    >> ${match.line_num}: ${match.line.substring(0, 100)}`);

    // 9. 显示后文
    if (match.after_context.length > 0) {
      console.log(`\n    后文:`);
      match.after_context.forEach(ctx => {
        console.log(`      ${ctx.line_num}: ${ctx.line.substring(0, 60)}`);
      });
    }
  });

  console.log('\n' + '='.repeat(70));
});
```

## ⚠️ 常见错误

### 错误 1: 字段名拼写错误

```python
# ❌ 错误
doc['doc_title']  # 字段名错误

# ✅ 正确
doc['doc_name']
```

### 错误 2: 访问不存在的嵌套字段

```python
# ❌ 错误
match['before']  # 旧字段名

# ✅ 正确
match['before_context']
```

### 错误 3: 未检查 status

```python
# ❌ 错误 - 直接访问可能导致 KeyError
results = data['data']['results']

# ✅ 正确
if data['status']:
    results = data['data']['results']
else:
    print(f"错误: {data.get('data')}")
```

### 错误 4: 行号从 0 开始

```python
# ❌ 错误 - 行号从 1 开始，不是 0
if match['line_num'] == 0:
    # 这永远不会发生
    pass

# ✅ 正确
if match['line_num'] == 1:
    # 这是第一行
    pass
```

## 📊 实际返回示例

### 请求

```bash
curl "http://localhost:8000/api/search_content/?token=43c395f68784452784585da896cb5c66&pattern=CDP&search_mode=exact&before_lines=2&after_lines=2&limit=1"
```

### 响应（已格式化）

```json
{
  "status": true,
  "data": {
    "results": [
      {
        "doc_id": 9,
        "doc_name": "CDP动态调试Web应用完整方法论",
        "project_id": 14,
        "project_name": "WhatsApp 插件开发",
        "matches": [
          {
            "line_num": 5,
            "line": "本文档记录了使用Chrome DevTools Protocol (CDP)进行动态Web应用调试的完整方法论，特别是分析混淆后的JavaScript代码、定位关键API调用链的实战流程。",
            "match_positions": [[34, 37]],
            "before_context": [
              {"line_num": 3, "line": "## 1. 概述"},
              {"line_num": 4, "line": ""}
            ],
            "after_context": [
              {"line_num": 6, "line": ""},
              {"line_num": 7, "line": "### 1.1 适用场景"}
            ]
          }
        ],
        "match_count": 3
      }
    ],
    "total_docs": 9,
    "total_matches": 50,
    "page": 1,
    "limit": 1,
    "elapsed_time": 19,
    "search_params": {
      "pattern": "CDP",
      "search_mode": "exact",
      "case_sensitive": false,
      "pid": 0,
      "max_results": 50,
      "before_lines": 2,
      "after_lines": 2
    }
  }
}
```

## 🔍 调试技巧

### 1. 打印原始 JSON

```python
import json
print(json.dumps(response.json(), indent=2, ensure_ascii=False))
```

### 2. 检查响应状态码

```python
print(f"HTTP 状态码: {response.status_code}")
print(f"API 状态: {data['status']}")
```

### 3. 检查字段是否存在

```python
if 'doc_name' in doc:
    print(doc['doc_name'])
else:
    print("字段 'doc_name' 不存在")
    print("可用字段:", list(doc.keys()))
```

### 4. 查看实际数据类型

```python
print(f"doc_name 类型: {type(doc['doc_name'])}")
print(f"line_num 类型: {type(match['line_num'])}")
```

## ✅ 字段总结表

| 我想获取 | 正确的访问路径 |
|---------|---------------|
| 文档标题 | `doc['doc_name']` |
| 文集名称 | `doc['project_name']` |
| 匹配行号 | `match['line_num']` |
| 匹配内容 | `match['line']` |
| 前文列表 | `match['before_context']` |
| 后文列表 | `match['after_context']` |
| 前文某行号 | `match['before_context'][i]['line_num']` |
| 前文某行内容 | `match['before_context'][i]['line']` |

---

**最后更新**: 2025-10-29
**API 版本**: v1.1.0
**测试 Token**: `43c395f68784452784585da896cb5c66`
