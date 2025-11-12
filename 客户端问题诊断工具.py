#!/usr/bin/env python3
# coding:utf-8
"""
客户端问题诊断工具
帮助定位客户端解析代码的问题
"""

import requests
import json

BASE_URL = 'http://localhost:8000'
TOKEN = '43c395f68784452784585da896cb5c66'

def diagnose_search(pattern, search_mode='exact'):
    """诊断单个搜索"""
    print("\n" + "="*70)
    print(f"  诊断搜索: '{pattern}' (模式: {search_mode})")
    print("="*70)

    response = requests.get(
        f'{BASE_URL}/api/search_content/',
        params={
            'token': TOKEN,
            'pattern': pattern,
            'search_mode': search_mode,
            'before_lines': 0,
            'after_lines': 0,
            'limit': 1
        }
    )

    print(f"\n1️⃣ HTTP 响应检查")
    print(f"   状态码: {response.status_code}")
    print(f"   Content-Type: {response.headers.get('Content-Type')}")

    try:
        data = response.json()
    except Exception as e:
        print(f"   ❌ JSON 解析失败: {e}")
        print(f"   原始响应: {response.text[:200]}")
        return

    print(f"\n2️⃣ API 状态检查")
    print(f"   status 字段: {data.get('status')}")
    print(f"   status 类型: {type(data.get('status'))}")

    if not data.get('status'):
        print(f"   ❌ API 返回失败: {data.get('data')}")
        return

    result_data = data['data']

    print(f"\n3️⃣ 结果数据检查")
    print(f"   total_docs: {result_data.get('total_docs')}")
    print(f"   total_matches: {result_data.get('total_matches')}")
    print(f"   results 长度: {len(result_data.get('results', []))}")

    if not result_data.get('results'):
        print(f"   ❌ results 数组为空")
        return

    doc = result_data['results'][0]

    print(f"\n4️⃣ 文档字段检查")
    print(f"   doc_id: {doc.get('doc_id')} (类型: {type(doc.get('doc_id')).__name__})")
    print(f"   doc_name: '{doc.get('doc_name')}' (类型: {type(doc.get('doc_name')).__name__})")

    # 检查可能的错误字段名
    if 'doc_title' in doc:
        print(f"   ⚠️  发现错误字段 'doc_title': {doc['doc_title']}")
    if 'title' in doc:
        print(f"   ⚠️  发现字段 'title': {doc['title']}")

    print(f"   project_id: {doc.get('project_id')}")
    print(f"   project_name: '{doc.get('project_name')}'")
    print(f"   match_count: {doc.get('match_count')}")

    if not doc.get('matches'):
        print(f"   ❌ matches 数组为空")
        return

    match = doc['matches'][0]

    print(f"\n5️⃣ 匹配字段检查")
    print(f"   line_num: {match.get('line_num')} (类型: {type(match.get('line_num')).__name__})")

    # 检查 line_num 是否为 0
    if match.get('line_num') == 0:
        print(f"   ⚠️  警告: line_num 为 0！")
        print(f"   实际值: {match.get('line_num')}")
        print(f"   完整 match 对象: {json.dumps(match, ensure_ascii=False, indent=2)}")

    line_content = match.get('line', '')
    print(f"   line 长度: {len(line_content)}")
    print(f"   line 类型: {type(line_content).__name__}")
    print(f"   line 前50字符: '{line_content[:50]}'")

    # 检查 line 是否为空
    if not line_content:
        print(f"   ⚠️  警告: line 字段为空！")
        print(f"   line 值: '{line_content}'")
        print(f"   完整 match 对象: {json.dumps(match, ensure_ascii=False, indent=2)}")

    # 检查可能的错误字段名
    if 'line_number' in match:
        print(f"   ⚠️  发现字段 'line_number': {match['line_number']}")
    if 'content' in match:
        print(f"   ⚠️  发现字段 'content': {match['content'][:50]}")

    print(f"   match_positions: {match.get('match_positions')}")

    print(f"\n6️⃣ 上下文字段检查")
    print(f"   before_context 类型: {type(match.get('before_context'))}")
    print(f"   before_context 长度: {len(match.get('before_context', []))}")
    print(f"   after_context 类型: {type(match.get('after_context'))}")
    print(f"   after_context 长度: {len(match.get('after_context', []))}")

    # 检查可能的错误字段名
    if 'before' in match:
        print(f"   ⚠️  发现旧字段 'before': {len(match['before'])}")
    if 'after' in match:
        print(f"   ⚠️  发现旧字段 'after': {len(match['after'])}")

    print(f"\n7️⃣ 完整数据展示")
    print(f"   文档: {doc['doc_name']}")
    print(f"   匹配行 {match['line_num']}: {match['line'][:100]}")

    print(f"\n✅ 诊断完成 - 数据正常")


def check_common_mistakes():
    """检查常见错误"""
    print("\n" + "="*70)
    print("  常见客户端错误检查")
    print("="*70)

    print("\n❌ 常见错误 1: 字段名拼写错误")
    print("   错误: doc['doc_title']")
    print("   正确: doc['doc_name']")

    print("\n❌ 常见错误 2: 使用旧字段名")
    print("   错误: match['before']")
    print("   正确: match['before_context']")

    print("\n❌ 常见错误 3: 未检查 status")
    print("   错误: results = data['data']['results']")
    print("   正确: if data['status']: results = data['data']['results']")

    print("\n❌ 常见错误 4: 字段访问方式错误")
    print("   错误: doc.doc_name (点号访问)")
    print("   正确: doc['doc_name'] (字典访问)")

    print("\n❌ 常见错误 5: 默认值处理")
    print("   错误: line_num = match['line_num'] or 0")
    print("   正确: line_num = match.get('line_num', 0)")
    print("   说明: 如果 line_num 不存在才返回 0")


def show_correct_code():
    """显示正确的代码示例"""
    print("\n" + "="*70)
    print("  ✅ 正确的客户端代码示例")
    print("="*70)

    code = '''
import requests

response = requests.get(
    'http://localhost:8000/api/search_content/',
    params={
        'token': '43c395f68784452784585da896cb5c66',
        'pattern': 'CDP',
        'search_mode': 'exact',
        'limit': 5
    }
)

data = response.json()

# ✅ 检查状态
if not data['status']:
    print(f"错误: {data.get('data')}")
    exit(1)

result_data = data['data']

# ✅ 遍历结果
for doc in result_data['results']:
    # ✅ 使用正确的字段名
    print(f"文档: {doc['doc_name']}")        # 不是 doc_title
    print(f"项目: {doc['project_name']}")    # 不是 project_title

    for match in doc['matches']:
        # ✅ 使用正确的字段名
        print(f"行号: {match['line_num']}")  # 不是 line_number
        print(f"内容: {match['line']}")       # 不是 content

        # ✅ 使用新的字段名
        for ctx in match['before_context']:  # 不是 before
            print(f"  {ctx['line_num']}: {ctx['line']}")
'''

    print(code)


def main():
    """主函数"""
    print("="*70)
    print("  🔍 客户端问题诊断工具")
    print("="*70)
    print(f"\n服务器: {BASE_URL}")
    print(f"Token: {TOKEN[:20]}...")

    # 诊断用户提到的三个搜索
    test_cases = [
        ('kt.set.contact', 'exact'),
        ('chatgpt.ask', 'exact'),
        ('telegram', 'fuzzy'),
    ]

    for pattern, mode in test_cases:
        diagnose_search(pattern, mode)

    # 检查常见错误
    check_common_mistakes()

    # 显示正确代码
    show_correct_code()

    print("\n" + "="*70)
    print("  💡 诊断建议")
    print("="*70)
    print("\n如果您的客户端显示:")
    print("  - 行号: 0")
    print("  - 匹配内容: 空")
    print("\n可能的原因:")
    print("  1. 使用了错误的字段名（如 doc_title 而不是 doc_name）")
    print("  2. 使用了旧的字段名（如 before 而不是 before_context）")
    print("  3. 字段访问方式错误（如 doc.doc_name 而不是 doc['doc_name']）")
    print("  4. 未正确处理默认值")
    print("\n请参考上面的正确代码示例，检查您的客户端代码。")

    print("\n" + "="*70)
    print("  📋 快速检查清单")
    print("="*70)
    print("\n在您的客户端代码中搜索以下错误模式:")
    print("  [ ] doc['doc_title'] 或 doc.doc_title")
    print("  [ ] match['line_number'] 或 match.line_number")
    print("  [ ] match['before'] 或 match['after']")
    print("  [ ] match['content'] (应该是 match['line'])")
    print("\n如果发现以上任何一个，请替换为正确的字段名。")


if __name__ == '__main__':
    main()
