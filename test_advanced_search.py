#!/usr/bin/env python3
# coding:utf-8
"""
测试 MrDoc 高级搜索 API 功能
支持 exact/fuzzy/regex 三种搜索模式
"""

import requests
import json
import time

BASE_URL = 'http://localhost:8000'  # 本地服务器地址
API_TOKEN = '43c395f68784452784585da896cb5c66'  # 本地系统token


def test_search_content():
    """测试高级内容搜索 API"""
    print("\n" + "="*70)
    print("  测试高级内容搜索 API (/api/search_content/)")
    print("="*70)

    # 测试用例
    test_cases = [
        {
            'name': '测试 1: 精确搜索 (exact mode) - "CDP"',
            'params': {
                'token': API_TOKEN,
                'pattern': 'CDP',
                'search_mode': 'exact',
                'case_sensitive': False,
                'context_lines': 2,
                'limit': 5
            }
        },
        {
            'name': '测试 2: 精确搜索 (exact mode, 大小写敏感) - "CDP"',
            'params': {
                'token': API_TOKEN,
                'pattern': 'CDP',
                'search_mode': 'exact',
                'case_sensitive': True,
                'context_lines': 1,
                'limit': 5
            }
        },
        {
            'name': '测试 3: 模糊搜索 (fuzzy mode) - "Python"',
            'params': {
                'token': API_TOKEN,
                'pattern': 'Python',
                'search_mode': 'fuzzy',
                'case_sensitive': False,
                'context_lines': 2,
                'limit': 5
            }
        },
        {
            'name': '测试 4: 正则表达式搜索 (regex mode) - "\\bCDP\\b"',
            'params': {
                'token': API_TOKEN,
                'pattern': r'\bCDP\b',  # 单词边界匹配
                'search_mode': 'regex',
                'case_sensitive': False,
                'context_lines': 1,
                'limit': 5
            }
        },
        {
            'name': '测试 5: 正则搜索 - 匹配 kt.* 模式',
            'params': {
                'token': API_TOKEN,
                'pattern': r'kt\.\w+',  # 匹配 kt.test, kt.admin 等
                'search_mode': 'regex',
                'case_sensitive': False,
                'context_lines': 2,
                'limit': 5
            }
        },
        {
            'name': '测试 6: 全局搜索 (pid=0) - "WhatsApp"',
            'params': {
                'token': API_TOKEN,
                'pattern': 'WhatsApp',
                'search_mode': 'exact',
                'pid': 0,  # 全局搜索
                'context_lines': 1,
                'limit': 5
            }
        },
        {
            'name': '测试 7: 无上下文行 (context_lines=0)',
            'params': {
                'token': API_TOKEN,
                'pattern': 'Django',
                'search_mode': 'fuzzy',
                'context_lines': 0,
                'limit': 3
            }
        },
        {
            'name': '测试 8: 大量上下文行 (context_lines=5)',
            'params': {
                'token': API_TOKEN,
                'pattern': 'API',
                'search_mode': 'exact',
                'context_lines': 5,
                'limit': 2
            }
        },
        {
            'name': '测试 9: 测试最大结果数限制',
            'params': {
                'token': API_TOKEN,
                'pattern': 'the',
                'search_mode': 'fuzzy',
                'max_results': 10,  # 限制最多10个匹配
                'context_lines': 1,
                'limit': 5
            }
        },
        {
            'name': '测试 10: POST 请求方式',
            'method': 'POST',
            'params': {
                'token': API_TOKEN,
                'pattern': 'Python',
                'search_mode': 'exact',
                'context_lines': 2,
                'limit': 3
            }
        },
    ]

    for idx, case in enumerate(test_cases, 1):
        print(f"\n{'='*70}")
        print(f"{case['name']}")
        print(f"{'='*70}")
        print(f"参数: {json.dumps(case['params'], indent=2, ensure_ascii=False)}")

        try:
            start_time = time.time()

            # 判断请求方式
            method = case.get('method', 'GET')
            if method == 'POST':
                response = requests.post(
                    f"{BASE_URL}/api/search_content/",
                    json=case['params'],
                    timeout=30
                )
            else:
                response = requests.get(
                    f"{BASE_URL}/api/search_content/",
                    params=case['params'],
                    timeout=30
                )

            request_time = int((time.time() - start_time) * 1000)
            data = response.json()

            if data.get('status'):
                result_data = data.get('data', {})
                print(f"✓ 请求成功 (方法: {method})")
                print(f"  - 总文档数: {result_data.get('total_docs', 0)}")
                print(f"  - 总匹配数: {result_data.get('total_matches', 0)}")
                print(f"  - 服务器耗时: {result_data.get('elapsed_time', 0)}ms")
                print(f"  - 请求总耗时: {request_time}ms")
                print(f"  - 当前页: {result_data.get('page', 0)}")
                print(f"  - 每页数量: {result_data.get('limit', 0)}")

                # 打印搜索参数确认
                search_params = result_data.get('search_params', {})
                print(f"\n  搜索参数确认:")
                print(f"    - 搜索模式: {search_params.get('search_mode')}")
                print(f"    - 大小写敏感: {search_params.get('case_sensitive')}")
                print(f"    - 文集ID: {search_params.get('pid')} (0=全局)")
                print(f"    - 最大结果数: {search_params.get('max_results')}")
                print(f"    - 上下文行数: {search_params.get('context_lines')}")

                # 打印匹配详情（只显示前2个文档）
                results = result_data.get('results', [])
                if results:
                    print(f"\n  匹配详情（显示前2个文档）:")
                    for doc_idx, doc_result in enumerate(results[:2], 1):
                        print(f"\n  [{doc_idx}] 文档: {doc_result['doc_name']}")
                        print(f"      文集: {doc_result['project_name']} (ID: {doc_result['project_id']})")
                        print(f"      文档ID: {doc_result['doc_id']}")
                        print(f"      匹配数: {doc_result['match_count']}")

                        # 显示前2个匹配
                        for match_idx, match in enumerate(doc_result['matches'][:2], 1):
                            print(f"\n      匹配 {match_idx}:")
                            print(f"        行号: {match['line_num']}")
                            print(f"        匹配位置: {match['match_positions']}")

                            # 显示上下文（如果有）
                            if match['before']:
                                print(f"        前面 {len(match['before'])} 行:")
                                for before_line in match['before']:
                                    preview = before_line['line'][:60] + "..." if len(before_line['line']) > 60 else before_line['line']
                                    print(f"          {before_line['line_num']}: {preview}")

                            # 显示匹配行
                            match_line = match['line'][:100] + "..." if len(match['line']) > 100 else match['line']
                            print(f"        >> {match['line_num']}: {match_line}")

                            # 显示后面（如果有）
                            if match['after']:
                                print(f"        后面 {len(match['after'])} 行:")
                                for after_line in match['after']:
                                    preview = after_line['line'][:60] + "..." if len(after_line['line']) > 60 else after_line['line']
                                    print(f"          {after_line['line_num']}: {preview}")

                        if doc_result['match_count'] > 2:
                            print(f"\n      ... 还有 {doc_result['match_count'] - 2} 个匹配未显示")

                    if len(results) > 2:
                        print(f"\n  ... 还有 {len(results) - 2} 个文档未显示")
                else:
                    print("  无匹配结果")

            else:
                print(f"✗ 请求失败: {data.get('data')}")
                if 'traceback' in data:
                    print(f"\n错误堆栈:")
                    print(data['traceback'])

        except Exception as e:
            print(f"✗ 异常: {e}")
            import traceback
            traceback.print_exc()


def test_performance():
    """测试性能 - 大量文档搜索"""
    print("\n" + "="*70)
    print("  性能测试 - 搜索所有文档")
    print("="*70)

    test_cases = [
        {
            'name': '性能测试 1: 全局搜索常见词 "the"',
            'params': {
                'token': API_TOKEN,
                'pattern': 'the',
                'search_mode': 'fuzzy',
                'max_results': 100,
                'context_lines': 0,  # 无上下文以提高性能
                'limit': 50
            }
        },
        {
            'name': '性能测试 2: 正则搜索',
            'params': {
                'token': API_TOKEN,
                'pattern': r'\b[A-Z]{3,}\b',  # 匹配3个或更多大写字母
                'search_mode': 'regex',
                'max_results': 50,
                'context_lines': 0,
                'limit': 20
            }
        },
    ]

    for case in test_cases:
        print(f"\n{case['name']}")
        print(f"参数: {json.dumps(case['params'], indent=2, ensure_ascii=False)}")

        try:
            start_time = time.time()
            response = requests.get(
                f"{BASE_URL}/api/search_content/",
                params=case['params'],
                timeout=60  # 增加超时时间
            )
            request_time = int((time.time() - start_time) * 1000)

            data = response.json()

            if data.get('status'):
                result_data = data.get('data', {})
                server_time = result_data.get('elapsed_time', 0)

                print(f"✓ 性能指标:")
                print(f"  - 服务器处理时间: {server_time}ms")
                print(f"  - 请求总耗时: {request_time}ms")
                print(f"  - 网络延迟: {request_time - server_time}ms")
                print(f"  - 找到文档数: {result_data.get('total_docs', 0)}")
                print(f"  - 总匹配数: {result_data.get('total_matches', 0)}")

                # 判断是否满足性能要求
                if server_time < 2000:
                    print(f"  ✓ 满足性能要求 (<2秒)")
                else:
                    print(f"  ✗ 未满足性能要求 (>2秒)")
            else:
                print(f"✗ 请求失败: {data.get('data')}")

        except Exception as e:
            print(f"✗ 异常: {e}")


def main():
    """主函数"""
    print("\n" + "="*70)
    print("  MrDoc 高级搜索 API 测试")
    print("  测试 exact/fuzzy/regex 三种搜索模式")
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

    # 执行功能测试
    test_search_content()

    # 执行性能测试
    test_performance()

    print("\n" + "="*70)
    print("  ✅ 测试完成")
    print("="*70)

    return 0


if __name__ == '__main__':
    import sys
    sys.exit(main())
