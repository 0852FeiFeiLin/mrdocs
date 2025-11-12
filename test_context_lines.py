#!/usr/bin/env python3
# coding:utf-8
"""
测试独立的 before_lines/after_lines 参数功能
验证上下文行数的灵活控制
"""

import requests
import json

BASE_URL = 'http://localhost:8000'
API_TOKEN = '43c395f68784452784585da896cb5c66'


def print_match_with_context(match, test_name):
    """打印匹配结果及其上下文"""
    print(f"\n  【{test_name}】")
    print(f"  匹配行 {match['line_num']}: {match['line'][:80]}...")

    if match['before_context']:
        print(f"\n  前面 {len(match['before_context'])} 行:")
        for ctx in match['before_context']:
            preview = ctx['line'][:60] + "..." if len(ctx['line']) > 60 else ctx['line']
            print(f"    行 {ctx['line_num']}: {preview}")
    else:
        print(f"  (无前面上下文)")

    print(f"\n  >> 行 {match['line_num']}: {match['line'][:80]}...")

    if match['after_context']:
        print(f"\n  后面 {len(match['after_context'])} 行:")
        for ctx in match['after_context']:
            preview = ctx['line'][:60] + "..." if len(ctx['line']) > 60 else ctx['line']
            print(f"    行 {ctx['line_num']}: {preview}")
    else:
        print(f"  (无后面上下文)")


def test_context_lines():
    """测试独立的 before_lines/after_lines 参数"""
    print("\n" + "="*70)
    print("  测试独立的前后上下文行数控制")
    print("="*70)

    test_cases = [
        {
            'name': '测试 1: 只要前文 (before_lines=3, after_lines=0)',
            'desc': '适用场景：查看某个变量或函数的定义上下文',
            'params': {
                'token': API_TOKEN,
                'pattern': 'CDP',
                'search_mode': 'exact',
                'before_lines': 3,
                'after_lines': 0,
                'limit': 1
            }
        },
        {
            'name': '测试 2: 只要后文 (before_lines=0, after_lines=5)',
            'desc': '适用场景：查看函数定义后的实现代码',
            'params': {
                'token': API_TOKEN,
                'pattern': 'def',
                'search_mode': 'fuzzy',
                'before_lines': 0,
                'after_lines': 5,
                'limit': 1
            }
        },
        {
            'name': '测试 3: 前后不对称 (before_lines=2, after_lines=8)',
            'desc': '适用场景：关注后续内容多于前文',
            'params': {
                'token': API_TOKEN,
                'pattern': 'Python',
                'search_mode': 'exact',
                'before_lines': 2,
                'after_lines': 8,
                'limit': 1
            }
        },
        {
            'name': '测试 4: 无上下文 (before_lines=0, after_lines=0)',
            'desc': '适用场景：只需要匹配行本身，提高性能',
            'params': {
                'token': API_TOKEN,
                'pattern': 'API',
                'search_mode': 'exact',
                'before_lines': 0,
                'after_lines': 0,
                'limit': 1
            }
        },
        {
            'name': '测试 5: 对称上下文 (before_lines=3, after_lines=3)',
            'desc': '适用场景：查看完整的代码块上下文',
            'params': {
                'token': API_TOKEN,
                'pattern': 'WhatsApp',
                'search_mode': 'exact',
                'before_lines': 3,
                'after_lines': 3,
                'limit': 1
            }
        },
        {
            'name': '测试 6: 兼容性测试 - 使用旧的 context_lines 参数',
            'desc': '验证向后兼容性',
            'params': {
                'token': API_TOKEN,
                'pattern': 'Django',
                'search_mode': 'exact',
                'context_lines': 2,  # 旧参数，应该设置 before_lines=2, after_lines=2
                'limit': 1
            }
        },
        {
            'name': '测试 7: 优先级测试 - before_lines/after_lines 覆盖 context_lines',
            'desc': '验证新参数优先级高于旧参数',
            'params': {
                'token': API_TOKEN,
                'pattern': 'Python',
                'search_mode': 'exact',
                'context_lines': 2,      # 旧参数
                'before_lines': 1,       # 应该覆盖 context_lines
                'after_lines': 4,        # 应该覆盖 context_lines
                'limit': 1
            }
        },
        {
            'name': '测试 8: POST 请求方式 - 独立参数',
            'method': 'POST',
            'desc': 'POST 请求支持独立上下文参数',
            'params': {
                'token': API_TOKEN,
                'pattern': 'kt\\.\\w+',
                'search_mode': 'regex',
                'before_lines': 2,
                'after_lines': 3,
                'limit': 1
            }
        },
        {
            'name': '测试 9: 边界测试 - 文档开头（before_lines 超出）',
            'desc': '验证文档开头时 before_context 返回实际可用行数',
            'params': {
                'token': API_TOKEN,
                'pattern': '^#',  # 匹配文档标题（通常在第一行）
                'search_mode': 'regex',
                'before_lines': 10,  # 请求前10行，但实际可能没有
                'after_lines': 3,
                'limit': 1
            }
        },
        {
            'name': '测试 10: 大量上下文 (before_lines=10, after_lines=10)',
            'desc': '测试大量上下文性能',
            'params': {
                'token': API_TOKEN,
                'pattern': 'CDP',
                'search_mode': 'exact',
                'before_lines': 10,
                'after_lines': 10,
                'limit': 1
            }
        },
    ]

    for idx, case in enumerate(test_cases, 1):
        print(f"\n{'='*70}")
        print(f"{case['name']}")
        print(f"说明: {case['desc']}")
        print(f"{'='*70}")
        print(f"参数: {json.dumps(case['params'], indent=2, ensure_ascii=False)}")

        try:
            # 判断请求方式
            method = case.get('method', 'GET')
            if method == 'POST':
                response = requests.post(
                    f"{BASE_URL}/api/search_content/",
                    json=case['params'],
                    timeout=10
                )
            else:
                response = requests.get(
                    f"{BASE_URL}/api/search_content/",
                    params=case['params'],
                    timeout=10
                )

            data = response.json()

            if data.get('status'):
                result_data = data.get('data', {})
                print(f"\n✓ 请求成功")
                print(f"  - 找到文档数: {result_data.get('total_docs', 0)}")
                print(f"  - 总匹配数: {result_data.get('total_matches', 0)}")
                print(f"  - 耗时: {result_data.get('elapsed_time', 0)}ms")

                # 验证返回的搜索参数
                search_params = result_data.get('search_params', {})
                print(f"\n  搜索参数确认:")
                print(f"    - before_lines: {search_params.get('before_lines')}")
                print(f"    - after_lines: {search_params.get('after_lines')}")

                # 显示第一个匹配的详细信息
                results = result_data.get('results', [])
                if results:
                    first_doc = results[0]
                    if first_doc['matches']:
                        first_match = first_doc['matches'][0]

                        # 验证上下文行数
                        actual_before = len(first_match['before_context'])
                        actual_after = len(first_match['after_context'])
                        expected_before = search_params.get('before_lines', 0)
                        expected_after = search_params.get('after_lines', 0)

                        print(f"\n  上下文验证:")
                        print(f"    - 期望前文行数: {expected_before}")
                        print(f"    - 实际前文行数: {actual_before}")
                        if actual_before <= expected_before:
                            print(f"      ✓ 正确（实际 ≤ 期望，可能受文档边界限制）")
                        else:
                            print(f"      ✗ 错误（实际 > 期望）")

                        print(f"    - 期望后文行数: {expected_after}")
                        print(f"    - 实际后文行数: {actual_after}")
                        if actual_after <= expected_after:
                            print(f"      ✓ 正确（实际 ≤ 期望，可能受文档边界限制）")
                        else:
                            print(f"      ✗ 错误（实际 > 期望）")

                        # 打印匹配详情
                        print_match_with_context(first_match, f"{first_doc['doc_name']}")
                else:
                    print("  无匹配结果")

            else:
                print(f"✗ 请求失败: {data.get('data')}")

        except Exception as e:
            print(f"✗ 异常: {e}")
            import traceback
            traceback.print_exc()


def main():
    """主函数"""
    print("\n" + "="*70)
    print("  独立上下文行数控制功能测试")
    print("  before_lines / after_lines 参数")
    print("="*70)

    # 测试服务器连接
    try:
        response = requests.get(BASE_URL, timeout=5)
        if response.status_code == 200:
            print(f"\n✓ 服务器连接正常: {BASE_URL}")
        else:
            print(f"\n✗ 服务器响应异常: HTTP {response.status_code}")
            return 1
    except Exception as e:
        print(f"\n✗ 服务器无法连接: {e}")
        return 1

    # 执行测试
    test_context_lines()

    print("\n" + "="*70)
    print("  ✅ 测试完成")
    print("="*70)

    return 0


if __name__ == '__main__':
    import sys
    sys.exit(main())
