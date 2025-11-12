#!/usr/bin/env python3
# coding:utf-8
"""
测试 MrDoc 搜索 API 功能
"""

import requests
import json

BASE_URL = 'http://localhost:8000'
API_TOKEN = '43c395f68784452784585da896cb5c66'  # 本地系统token


def test_api_search():
    """测试 API 搜索接口"""
    print("\n" + "="*70)
    print("  测试 API 搜索接口")
    print("="*70)

    # 测试用例
    test_cases = [
        {
            'name': '基础搜索 - OR模式',
            'params': {'token': API_TOKEN, 'q': 'Python', 'mode': 'or', 'limit': 5}
        },
        {
            'name': '基础搜索 - AND模式',
            'params': {'token': API_TOKEN, 'q': 'Python Django', 'mode': 'and', 'limit': 5}
        },
        {
            'name': '标题搜索',
            'params': {'token': API_TOKEN, 'q': 'WhatsApp', 'field': 'title', 'limit': 5}
        },
        {
            'name': '内容搜索',
            'params': {'token': API_TOKEN, 'q': 'CDP', 'field': 'content', 'limit': 5}
        },
    ]

    for case in test_cases:
        print(f"\n测试: {case['name']}")
        print(f"参数: {case['params']}")

        try:
            response = requests.get(f"{BASE_URL}/api/search/", params=case['params'], timeout=10)
            data = response.json()

            if data.get('status'):
                result_data = data.get('data', {})
                print(f"✓ 成功")
                print(f"  - 总数: {result_data.get('total', 0)}")
                print(f"  - 返回: {len(result_data.get('results', []))} 个结果")
                print(f"  - 耗时: {result_data.get('elapsed_time', 0)}ms")

                # 打印前3个结果的标题
                for idx, doc in enumerate(result_data.get('results', [])[:3], 1):
                    print(f"  {idx}. {doc.get('name', 'N/A')}")
            else:
                print(f"✗ 失败: {data.get('data')}")

        except Exception as e:
            print(f"✗ 异常: {e}")


def test_grep_search():
    """测试 Grep 风格搜索接口"""
    print("\n" + "="*70)
    print("  测试 Grep 风格搜索接口")
    print("="*70)

    # 测试用例
    test_cases = [
        {
            'name': '基础 grep - 显示上下文',
            'params': {
                'token': API_TOKEN,
                'q': 'CDP',
                'context': 2,  # 上下文2行
                'limit': 3
            }
        },
        {
            'name': 'Grep - 正则表达式',
            'params': {
                'token': API_TOKEN,
                'q': r'\bCDP\b',  # 单词边界匹配
                'regex': 'true',
                'before': 1,
                'after': 1,
                'limit': 3
            }
        },
        {
            'name': 'Grep - 忽略大小写',
            'params': {
                'token': API_TOKEN,
                'q': 'whatsapp',
                'ignore_case': 'true',
                'context': 1,
                'limit': 3
            }
        },
    ]

    for case in test_cases:
        print(f"\n测试: {case['name']}")
        print(f"参数: {json.dumps(case['params'], indent=2)}")

        try:
            response = requests.get(f"{BASE_URL}/api/grep_search/", params=case['params'], timeout=10)
            data = response.json()

            if data.get('status'):
                result_data = data.get('data', {})
                print(f"✓ 成功")
                print(f"  - 总文档数: {result_data.get('total_docs', 0)}")
                print(f"  - 总匹配数: {result_data.get('total_matches', 0)}")
                print(f"  - 耗时: {result_data.get('elapsed_time', 0)}ms")

                # 打印匹配详情
                for doc_result in result_data.get('results', [])[:2]:  # 只显示前2个文档
                    print(f"\n  文档: {doc_result['doc_name']}")
                    print(f"  匹配数: {doc_result['match_count']}")

                    for match in doc_result['matches'][:2]:  # 每个文档只显示前2个匹配
                        print(f"    行 {match['line_num']}: {match['line'][:80]}...")
                        if match['before']:
                            print(f"      [前面 {len(match['before'])} 行]")
                        if match['after']:
                            print(f"      [后面 {len(match['after'])} 行]")

            else:
                print(f"✗ 失败: {data.get('data')}")

        except Exception as e:
            print(f"✗ 异常: {e}")


def main():
    """主函数"""
    print("\n" + "="*70)
    print("  MrDoc 搜索 API 测试")
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
    test_api_search()
    test_grep_search()

    print("\n" + "="*70)
    print("  ✅ 测试完成")
    print("="*70)

    return 0


if __name__ == '__main__':
    import sys
    sys.exit(main())
