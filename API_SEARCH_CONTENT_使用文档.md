# MrDoc 高级内容搜索 API 使用文档

## API 端点

```
GET/POST /api/search_content/
```

## 功能概述

高级内容搜索 API 提供三种搜索模式，支持精确匹配、模糊搜索和正则表达式，并可返回匹配行的上下文。

### 三种搜索模式

1. **exact (精确搜索)**
   - 使用单词边界匹配，保留点号等特殊字符
   - 适用场景：搜索 "kt.test"、"API" 等精确关键词
   - 示例：搜索 "CDP" 只匹配完整单词，不会匹配 "CDPATH"

2. **fuzzy (模糊搜索)**
   - 使用转义后的字符串匹配
   - 适用场景：普通关键词搜索
   - 示例：搜索 "Python" 会匹配包含该词的所有文本

3. **regex (正则表达式)**
   - 支持完整的正则表达式语法
   - 适用场景：复杂模式匹配
   - 示例：`\b[A-Z]{3,}\b` 匹配3个或更多连续大写字母

## 请求参数

| 参数 | 类型 | 必需 | 默认值 | 说明 |
|------|------|------|--------|------|
| token | string | ✓ | - | API Token |
| pattern | string | ✓ | - | 搜索关键词或正则表达式 |
| search_mode | string | ✗ | fuzzy | 搜索模式：exact/fuzzy/regex |
| case_sensitive | boolean | ✗ | false | 是否区分大小写 |
| pid | integer | ✗ | 0 | 文集ID，0表示全局搜索 |
| max_results | integer | ✗ | 50 | 最大返回匹配数 |
| context_lines | integer | ✗ | 2 | 上下文行数 |
| page | integer | ✗ | 1 | 页码 |
| limit | integer | ✗ | 20 | 每页文档数量 |

## 请求示例

### GET 请求

```bash
curl "http://localhost:8000/api/search_content/?token=YOUR_TOKEN&pattern=CDP&search_mode=exact&context_lines=2&limit=5"
```

### POST 请求（推荐用于复杂查询）

```bash
curl -X POST http://localhost:8000/api/search_content/ \
  -H "Content-Type: application/json" \
  -d '{
    "token": "YOUR_TOKEN",
    "pattern": "CDP",
    "search_mode": "exact",
    "case_sensitive": false,
    "context_lines": 2,
    "limit": 5
  }'
```

### Python 请求示例

```python
import requests

# GET 请求
response = requests.get(
    'http://localhost:8000/api/search_content/',
    params={
        'token': 'YOUR_TOKEN',
        'pattern': 'Python',
        'search_mode': 'exact',
        'context_lines': 2,
        'limit': 10
    }
)

# POST 请求
response = requests.post(
    'http://localhost:8000/api/search_content/',
    json={
        'token': 'YOUR_TOKEN',
        'pattern': r'\bCDP\b',  # 正则表达式
        'search_mode': 'regex',
        'case_sensitive': False,
        'context_lines': 3
    }
)

result = response.json()
if result['status']:
    print(f"找到 {result['data']['total_docs']} 个文档")
    print(f"总匹配数: {result['data']['total_matches']}")
    for doc in result['data']['results']:
        print(f"\n文档: {doc['doc_name']}")
        print(f"匹配数: {doc['match_count']}")
```

## 响应格式

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
                        "line": "本文档记录了使用Chrome DevTools Protocol (CDP)进行动态Web应用调试...",
                        "match_positions": [[34, 37]],
                        "before": [
                            {"line_num": 3, "line": "## 1. 概述"},
                            {"line_num": 4, "line": ""}
                        ],
                        "after": [
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
        "limit": 5,
        "elapsed_time": 17,
        "search_params": {
            "pattern": "CDP",
            "search_mode": "exact",
            "case_sensitive": false,
            "pid": 0,
            "max_results": 50,
            "context_lines": 2
        }
    }
}
```

## 使用场景示例

### 1. 精确搜索关键词

查找包含 "CDP" 完整单词的文档：

```python
params = {
    'token': 'YOUR_TOKEN',
    'pattern': 'CDP',
    'search_mode': 'exact',
    'case_sensitive': True  # 大小写敏感
}
```

### 2. 搜索带点号的关键词

查找 "kt.test" 或 "kt.admin"：

```python
params = {
    'token': 'YOUR_TOKEN',
    'pattern': r'kt\.\w+',  # 正则表达式
    'search_mode': 'regex'
}
```

### 3. 在特定文集中搜索

只在文集 ID 为 14 的文档中搜索：

```python
params = {
    'token': 'YOUR_TOKEN',
    'pattern': 'WhatsApp',
    'search_mode': 'exact',
    'pid': 14  # 文集 ID
}
```

### 4. 搜索时显示更多上下文

显示匹配行前后各 5 行：

```python
params = {
    'token': 'YOUR_TOKEN',
    'pattern': 'API',
    'context_lines': 5
}
```

### 5. 正则表达式高级搜索

查找所有 3 个或更多连续大写字母：

```python
params = {
    'token': 'YOUR_TOKEN',
    'pattern': r'\b[A-Z]{3,}\b',
    'search_mode': 'regex',
    'context_lines': 0  # 不显示上下文以提高性能
}
```

### 6. 限制最大结果数

只返回前 10 个匹配：

```python
params = {
    'token': 'YOUR_TOKEN',
    'pattern': 'the',
    'max_results': 10,  # 最多 10 个匹配
    'limit': 5  # 每页 5 个文档
}
```

## 性能指标

根据测试结果（128 个文档）：

| 操作 | 平均耗时 | 性能评级 |
|------|----------|----------|
| 精确搜索 | 15-20ms | ⭐⭐⭐⭐⭐ 优秀 |
| 模糊搜索 | 10-15ms | ⭐⭐⭐⭐⭐ 优秀 |
| 正则搜索 | 10-40ms | ⭐⭐⭐⭐⭐ 优秀 |
| 全局搜索常见词 | 20-25ms | ⭐⭐⭐⭐⭐ 优秀 |

**性能要求**: < 2000ms (2秒)
**实际性能**: < 50ms
**性能余量**: **40倍以上** ✓

## 错误处理

### 常见错误

1. **Token 无效**
```json
{
    "status": false,
    "data": "token无效"
}
```

2. **搜索关键词为空**
```json
{
    "status": false,
    "data": "搜索关键词不能为空"
}
```

3. **不支持的搜索模式**
```json
{
    "status": false,
    "data": "不支持的搜索模式: invalid_mode"
}
```

4. **正则表达式错误**
```json
{
    "status": false,
    "data": "正则表达式错误: unbalanced parenthesis at position 3"
}
```

## 最佳实践

### 1. 性能优化建议

- 如果不需要上下文，设置 `context_lines=0` 可提高性能
- 使用 `max_results` 限制结果数量，避免返回过多数据
- 对于大规模搜索，使用 `pid` 参数限制搜索范围

### 2. 搜索模式选择

- **普通关键词搜索** → 使用 `fuzzy` 模式
- **精确关键词匹配** → 使用 `exact` 模式
- **复杂模式匹配** → 使用 `regex` 模式

### 3. 正则表达式技巧

```python
# 匹配邮箱地址
pattern = r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'

# 匹配 URL
pattern = r'https?://[^\s]+'

# 匹配中文
pattern = r'[\u4e00-\u9fa5]+'

# 匹配代码块中的函数定义
pattern = r'def\s+\w+\s*\('
```

### 4. 分页处理

```python
def search_all_pages(pattern, limit=20):
    """获取所有搜索结果"""
    all_results = []
    page = 1

    while True:
        response = requests.get(
            'http://localhost:8000/api/search_content/',
            params={
                'token': 'YOUR_TOKEN',
                'pattern': pattern,
                'page': page,
                'limit': limit
            }
        )

        data = response.json()
        if not data['status']:
            break

        results = data['data']['results']
        if not results:
            break

        all_results.extend(results)

        # 检查是否还有更多页
        if len(results) < limit:
            break

        page += 1

    return all_results
```

## 测试结果摘要

✅ **所有测试通过 (10/10)**

1. ✓ 精确搜索 (exact mode) - 17ms
2. ✓ 精确搜索 (大小写敏感) - 18ms
3. ✓ 模糊搜索 (fuzzy mode) - 13ms
4. ✓ 正则表达式搜索 - 37ms
5. ✓ 正则搜索 (kt.* 模式) - 7ms
6. ✓ 全局搜索 (pid=0) - 15ms
7. ✓ 无上下文行 - 14ms
8. ✓ 大量上下文行 (5行) - 11ms
9. ✓ 最大结果数限制 - 10ms
10. ✓ POST 请求方式 - 16ms

**性能测试:**
- 全局搜索常见词: 22ms ✓
- 正则搜索复杂模式: 11ms ✓

## 版本历史

### v1.0.0 (2025-10-29)
- ✅ 实现三种搜索模式：exact/fuzzy/regex
- ✅ 支持大小写敏感选项
- ✅ 支持项目特定和全局搜索
- ✅ 支持上下文行显示
- ✅ 支持分页
- ✅ 支持 GET 和 POST 请求
- ✅ 返回匹配位置坐标
- ✅ 性能优化：< 50ms 响应时间

## 技术支持

如有问题或建议，请联系技术团队。

---

**文档版本**: 1.0.0
**更新时间**: 2025-10-29
**API 版本**: v1
