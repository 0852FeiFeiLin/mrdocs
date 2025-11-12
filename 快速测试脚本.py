#!/usr/bin/env python3
# coding:utf-8
"""
快速测试脚本 - 验证 API 数据解析
用于确认返回的数据格式和字段正确性
"""

import requests
import json

BASE_URL = 'http://localhost:8000'
TOKEN = '43c395f68784452784585da896cb5c66'

def print_separator(title=""):
    """打印分隔线"""
    print("\n" + "="*70)
    if title:
        print(f"  {title}")
        print("="*70)

def test_basic_search():
    """测试 1: 基础搜索 - 验证所有字段"""
    print_separator("测试 1: 基础搜索 CDP")

    response = requests.get(
        f'{BASE_URL}/api/search_content/',
        params={
            'token': TOKEN,
            'pattern': 'CDP',
            'search_mode': 'exact',
            'before_lines': 2,
            'after_lines': 2,
            'limit': 1
        }
    )

    print(f"HTTP 状态码: {response.status_code}")

    data = response.json()
    print(f"API 状态: {data['status']}")

    if not data['status']:
        print(f"❌ 错误: {data.get('data', '未知错误')}")
        return False

    result_data = data['data']

    # 验证顶层字段
    print(f"\n✓ 顶层字段验证:")
    print(f"  - total_docs: {result_data['total_docs']}")
    print(f"  - total_matches: {result_data['total_matches']}")
    print(f"  - elapsed_time: {result_data['elapsed_time']}ms")
    print(f"  - page: {result_data['page']}")
    print(f"  - limit: {result_data['limit']}")

    # 验证结果数组
    if not result_data['results']:
        print(f"❌ 错误: results 数组为空")
        return False

    doc = result_data['results'][0]

    print(f"\n✓ 文档字段验证:")
    print(f"  - doc_id: {doc['doc_id']} (类型: {type(doc['doc_id']).__name__})")
    print(f"  - doc_name: '{doc['doc_name']}' (类型: {type(doc['doc_name']).__name__})")
    print(f"  - project_id: {doc['project_id']} (类型: {type(doc['project_id']).__name__})")
    print(f"  - project_name: '{doc['project_name']}' (类型: {type(doc['project_name']).__name__})")
    print(f"  - match_count: {doc['match_count']}")

    # 验证匹配数组
    if not doc['matches']:
        print(f"❌ 错误: matches 数组为空")
        return False

    match = doc['matches'][0]

    print(f"\n✓ 匹配字段验证:")
    print(f"  - line_num: {match['line_num']} (类型: {type(match['line_num']).__name__})")
    print(f"  - line: '{match['line'][:50]}...' (长度: {len(match['line'])})")
    print(f"  - match_positions: {match['match_positions']}")
    print(f"  - before_context: {len(match['before_context'])} 行")
    print(f"  - after_context: {len(match['after_context'])} 行")

    # 显示完整匹配
    print(f"\n✓ 匹配详情:")
    print(f"\n  文档: {doc['doc_name']}")
    print(f"  项目: {doc['project_name']}")
    print(f"\n  匹配行 {match['line_num']}:")
    print(f"    {match['line'][:100]}")

    if match['before_context']:
        print(f"\n  前文:")
        for ctx in match['before_context']:
            print(f"    {ctx['line_num']}: {ctx['line'][:60]}")

    if match['after_context']:
        print(f"\n  后文:")
        for ctx in match['after_context']:
            print(f"    {ctx['line_num']}: {ctx['line'][:60]}")

    print(f"\n✅ 所有字段验证通过！")
    return True


def test_regex_search():
    """测试 2: 正则搜索 - 验证特殊模式"""
    print_separator("测试 2: 正则搜索 kt.set.contact")

    response = requests.get(
        f'{BASE_URL}/api/search_content/',
        params={
            'token': TOKEN,
            'pattern': r'kt\.set\.contact',
            'search_mode': 'regex',
            'case_sensitive': False,
            'before_lines': 1,
            'after_lines': 1,
            'limit': 1
        }
    )

    data = response.json()

    if not data['status']:
        print(f"❌ 错误: {data.get('data')}")
        return False

    result_data = data['data']
    print(f"✓ 找到 {result_data['total_docs']} 个文档")
    print(f"✓ 共 {result_data['total_matches']} 个匹配")

    if result_data['results']:
        doc = result_data['results'][0]
        print(f"\n✓ 文档: {doc['doc_name']}")
        print(f"  项目: {doc['project_name']}")

        for idx, match in enumerate(doc['matches'][:3], 1):
            print(f"\n  匹配 {idx}:")
            print(f"    行 {match['line_num']}: {match['line'][:80]}")

    print(f"\n✅ 正则搜索验证通过！")
    return True


def test_empty_context():
    """测试 3: 无上下文 - 验证边界情况"""
    print_separator("测试 3: 无上下文搜索")

    response = requests.get(
        f'{BASE_URL}/api/search_content/',
        params={
            'token': TOKEN,
            'pattern': 'Python',
            'search_mode': 'exact',
            'before_lines': 0,
            'after_lines': 0,
            'limit': 1
        }
    )

    data = response.json()

    if not data['status']:
        print(f"❌ 错误: {data.get('data')}")
        return False

    result_data = data['data']
    doc = result_data['results'][0]
    match = doc['matches'][0]

    print(f"✓ 搜索参数验证:")
    params = result_data['search_params']
    print(f"  - before_lines: {params['before_lines']}")
    print(f"  - after_lines: {params['after_lines']}")

    print(f"\n✓ 上下文验证:")
    print(f"  - before_context 长度: {len(match['before_context'])}")
    print(f"  - after_context 长度: {len(match['after_context'])}")

    if len(match['before_context']) == 0 and len(match['after_context']) == 0:
        print(f"\n✅ 无上下文验证通过！")
        return True
    else:
        print(f"\n❌ 错误: 应该无上下文但有数据")
        return False


def test_asymmetric_context():
    """测试 4: 不对称上下文"""
    print_separator("测试 4: 不对称上下文 (before=1, after=5)")

    response = requests.get(
        f'{BASE_URL}/api/search_content/',
        params={
            'token': TOKEN,
            'pattern': 'API',
            'search_mode': 'exact',
            'before_lines': 1,
            'after_lines': 5,
            'limit': 1
        }
    )

    data = response.json()

    if not data['status']:
        print(f"❌ 错误: {data.get('data')}")
        return False

    result_data = data['data']
    doc = result_data['results'][0]
    match = doc['matches'][0]

    print(f"✓ 搜索参数:")
    params = result_data['search_params']
    print(f"  - before_lines: {params['before_lines']}")
    print(f"  - after_lines: {params['after_lines']}")

    print(f"\n✓ 实际上下文:")
    print(f"  - before_context: {len(match['before_context'])} 行")
    print(f"  - after_context: {len(match['after_context'])} 行")

    before_ok = len(match['before_context']) <= params['before_lines']
    after_ok = len(match['after_context']) <= params['after_lines']

    if before_ok and after_ok:
        print(f"\n✅ 不对称上下文验证通过！")
        return True
    else:
        print(f"\n❌ 上下文行数超出限制")
        return False


def test_post_request():
    """测试 5: POST 请求"""
    print_separator("测试 5: POST 请求")

    response = requests.post(
        f'{BASE_URL}/api/search_content/',
        json={
            'token': TOKEN,
            'pattern': 'Django',
            'search_mode': 'exact',
            'before_lines': 2,
            'after_lines': 2,
            'limit': 1
        }
    )

    data = response.json()

    if not data['status']:
        print(f"❌ 错误: {data.get('data')}")
        return False

    result_data = data['data']
    print(f"✓ POST 请求成功")
    print(f"✓ 找到 {result_data['total_docs']} 个文档")

    if result_data['results']:
        doc = result_data['results'][0]
        print(f"\n✓ 文档: {doc['doc_name']}")
        print(f"  匹配数: {doc['match_count']}")

    print(f"\n✅ POST 请求验证通过！")
    return True


def main():
    """主函数 - 运行所有测试"""
    print("="*70)
    print("  🚀 API 数据格式验证测试套件")
    print("="*70)
    print(f"\n服务器: {BASE_URL}")
    print(f"Token: {TOKEN[:20]}...")

    # 运行所有测试
    tests = [
        ("基础搜索", test_basic_search),
        ("正则搜索", test_regex_search),
        ("无上下文", test_empty_context),
        ("不对称上下文", test_asymmetric_context),
        ("POST请求", test_post_request),
    ]

    results = []
    for name, test_func in tests:
        try:
            result = test_func()
            results.append((name, result))
        except Exception as e:
            print(f"\n❌ 测试异常: {e}")
            import traceback
            traceback.print_exc()
            results.append((name, False))

    # 总结
    print_separator("测试总结")
    passed = sum(1 for _, result in results if result)
    total = len(results)

    for name, result in results:
        status = "✅ 通过" if result else "❌ 失败"
        print(f"{status}: {name}")

    print(f"\n通过率: {passed}/{total} ({passed*100//total}%)")

    if passed == total:
        print("\n🎉 所有测试通过！API 数据格式完全正确！")
        return 0
    else:
        print(f"\n⚠️  有 {total-passed} 个测试失败，请检查")
        return 1


if __name__ == '__main__':
    import sys
    sys.exit(main())
