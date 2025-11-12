# coding:utf-8
"""
MrDoc API 搜索功能
支持 AND/OR 模式、正则匹配、grep 风格的上下文返回
"""

import re
import time
from django.http import JsonResponse
from django.views.decorators.http import require_http_methods
from django.views.decorators.csrf import csrf_exempt
from django.core.paginator import Paginator, PageNotAnInteger, EmptyPage

from haystack.query import SearchQuerySet
from app_doc.models import Doc, Project
from app_api.models import UserToken


def get_client_ip(request):
    """获取客户端IP地址"""
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        ip = x_forwarded_for.split(',')[0]
    else:
        ip = request.META.get('REMOTE_ADDR')
    return ip


@require_http_methods(["GET"])
def api_search(request):
    """
    API搜索接口

    参数:
        token: API Token (必需)
        q: 搜索关键词 (必需)
        mode: 搜索模式 and/or，默认 or
        field: 搜索字段 all/title/content，默认 all
        page: 页码，默认 1
        limit: 每页数量，默认 10

    返回:
        {
            "status": true/false,
            "data": {
                "results": [...],
                "total": 总数量,
                "page": 当前页,
                "limit": 每页数量,
                "elapsed_time": 搜索耗时(ms)
            }
        }
    """
    start_time = time.time() * 1000

    # 验证 token
    token = request.GET.get('token', '')
    try:
        user_token = UserToken.objects.get(token=token)
    except UserToken.DoesNotExist:
        return JsonResponse({'status': False, 'data': 'token无效'})

    # 获取搜索参数
    query = request.GET.get('q', '').strip()
    if not query:
        return JsonResponse({'status': False, 'data': '搜索关键词不能为空'})

    search_mode = request.GET.get('mode', 'or').lower()  # and/or
    search_field = request.GET.get('field', 'all').lower()  # all/title/content
    page_num = int(request.GET.get('page', 1))
    limit = int(request.GET.get('limit', 10))

    # 执行搜索
    try:
        sqs = SearchQuerySet().models(Doc).filter(status=1)

        # 处理 AND/OR 模式
        if search_mode == 'and':
            # AND 模式：所有词都必须出现
            query_terms = query.split()
            search_query = ' AND '.join(query_terms)
        else:
            search_query = query

        # 处理搜索字段
        if search_field == 'title':
            # 仅搜索标题
            sqs = sqs.filter(title__contains=search_query)
        elif search_field == 'content':
            # 仅搜索内容
            sqs = sqs.filter(content__contains=search_query)
        else:
            # 全文搜索（标题+内容）
            sqs = sqs.auto_query(search_query)

        # 分页
        paginator = Paginator(sqs, limit)
        try:
            results_page = paginator.page(page_num)
        except PageNotAnInteger:
            results_page = paginator.page(1)
        except EmptyPage:
            results_page = paginator.page(paginator.num_pages)

        # 构造返回结果
        results = []
        for result in results_page:
            doc = result.object
            # 优先使用完整内容 (content)，如果为空才使用 pre_content
            full_content = doc.content if doc.content else doc.pre_content
            results.append({
                'id': doc.id,
                'name': doc.name,
                'content': full_content,  # 完整文章内容
                'preview': full_content[:200] if full_content else '',  # 前200字符预览
                'top_doc': doc.top_doc,
                'create_time': doc.create_time.strftime('%Y-%m-%d %H:%M:%S'),
                'modify_time': doc.modify_time.strftime('%Y-%m-%d %H:%M:%S'),
            })

        elapsed_time = int((time.time() * 1000) - start_time)

        return JsonResponse({
            'status': True,
            'data': {
                'results': results,
                'total': paginator.count,
                'page': results_page.number,
                'limit': limit,
                'elapsed_time': elapsed_time,
                'search_mode': search_mode,
                'search_field': search_field,
            }
        })

    except Exception as e:
        return JsonResponse({'status': False, 'data': str(e)})


@require_http_methods(["GET"])
def api_grep_search(request):
    """
    Grep 风格的搜索 API

    参数:
        token: API Token (必需)
        q: 搜索关键词 (必需)
        regex: 正则表达式模式，默认 False
        mode: 搜索模式 and/or，默认 or
        field: 搜索字段 all/title/content，默认 all
        context: 上下文行数（等同于 -C）
        before: 前面多少行（等同于 -B）
        after: 后面多少行（等同于 -A）
        line_num: 是否显示行号，默认 True
        ignore_case: 是否忽略大小写，默认 False
        page: 页码，默认 1
        limit: 每页文档数量，默认 10

    返回:
        {
            "status": true/false,
            "data": {
                "results": [
                    {
                        "doc_id": 文档ID,
                        "doc_name": 文档名称,
                        "matches": [
                            {
                                "line_num": 行号,
                                "line": 匹配行内容,
                                "before": [前面的行],
                                "after": [后面的行]
                            }
                        ],
                        "match_count": 匹配数量
                    }
                ],
                "total_docs": 总文档数,
                "total_matches": 总匹配数,
                "elapsed_time": 搜索耗时(ms)
            }
        }
    """
    start_time = time.time() * 1000

    # 验证 token
    token = request.GET.get('token', '')
    try:
        user_token = UserToken.objects.get(token=token)
    except UserToken.DoesNotExist:
        return JsonResponse({'status': False, 'data': 'token无效'})

    # 获取搜索参数
    query = request.GET.get('q', '').strip()
    if not query:
        return JsonResponse({'status': False, 'data': '搜索关键词不能为空'})

    use_regex = request.GET.get('regex', 'false').lower() == 'true'
    search_mode = request.GET.get('mode', 'or').lower()
    search_field = request.GET.get('field', 'all').lower()

    # Grep 参数
    context = int(request.GET.get('context', 0))
    before = int(request.GET.get('before', context))
    after = int(request.GET.get('after', context))
    line_num = request.GET.get('line_num', 'true').lower() == 'true'
    ignore_case = request.GET.get('ignore_case', 'false').lower() == 'true'

    # 分页参数
    page_num = int(request.GET.get('page', 1))
    limit = int(request.GET.get('limit', 10))

    try:
        # 第一步：使用 Haystack 全文搜索获取文档列表
        sqs = SearchQuerySet().models(Doc).filter(status=1)

        # 处理 AND/OR 模式
        if search_mode == 'and':
            query_terms = query.split()
            search_query = ' AND '.join(query_terms)
        else:
            search_query = query

        # 处理搜索字段
        if search_field == 'title':
            sqs = sqs.filter(title__contains=search_query)
        elif search_field == 'content':
            sqs = sqs.filter(content__contains=search_query)
        else:
            sqs = sqs.auto_query(search_query)

        # 第二步：对每个文档内容进行正则匹配和上下文提取
        all_results = []
        total_matches = 0

        for result in sqs:
            doc = result.object
            # 优先使用完整内容 (content)，如果为空才使用 pre_content
            content = doc.content if doc.content else doc.pre_content
            lines = content.split('\n')

            # 准备正则表达式
            if use_regex:
                try:
                    flags = re.IGNORECASE if ignore_case else 0
                    pattern = re.compile(query, flags)
                except re.error as e:
                    return JsonResponse({'status': False, 'data': f'正则表达式错误: {str(e)}'})
            else:
                # 普通文本搜索，转义特殊字符
                escaped_query = re.escape(query)
                flags = re.IGNORECASE if ignore_case else 0
                pattern = re.compile(escaped_query, flags)

            # 查找所有匹配行
            matches = []
            for line_idx, line in enumerate(lines):
                if pattern.search(line):
                    # 提取上下文
                    before_lines = []
                    if before > 0:
                        start = max(0, line_idx - before)
                        before_lines = [
                            {'line_num': i + 1, 'line': lines[i]}
                            for i in range(start, line_idx)
                        ]

                    after_lines = []
                    if after > 0:
                        end = min(len(lines), line_idx + after + 1)
                        after_lines = [
                            {'line_num': i + 1, 'line': lines[i]}
                            for i in range(line_idx + 1, end)
                        ]

                    match_info = {
                        'line_num': line_idx + 1 if line_num else None,
                        'line': line,
                        'before': before_lines if before > 0 else [],
                        'after': after_lines if after > 0 else [],
                    }
                    matches.append(match_info)
                    total_matches += 1

            if matches:
                all_results.append({
                    'doc_id': doc.id,
                    'doc_name': doc.name,
                    'project_id': doc.top_doc,
                    'matches': matches,
                    'match_count': len(matches),
                })

        # 第三步：分页
        paginator = Paginator(all_results, limit)
        try:
            results_page = paginator.page(page_num)
        except PageNotAnInteger:
            results_page = paginator.page(1)
        except EmptyPage:
            results_page = paginator.page(paginator.num_pages)

        elapsed_time = int((time.time() * 1000) - start_time)

        return JsonResponse({
            'status': True,
            'data': {
                'results': list(results_page),
                'total_docs': paginator.count,
                'total_matches': total_matches,
                'page': results_page.number,
                'limit': limit,
                'elapsed_time': elapsed_time,
                'search_params': {
                    'query': query,
                    'regex': use_regex,
                    'mode': search_mode,
                    'field': search_field,
                    'before': before,
                    'after': after,
                    'ignore_case': ignore_case,
                }
            }
        })

    except Exception as e:
        import traceback
        return JsonResponse({
            'status': False,
            'data': str(e),
            'traceback': traceback.format_exc()
        })


@csrf_exempt
@require_http_methods(["GET", "POST"])
def api_search_content(request):
    """
    高级内容搜索 API

    支持三种搜索模式:
    - exact: 精确搜索，保留点号等特殊字符（如 "kt.test"）
    - fuzzy: 模糊搜索，使用全文检索
    - regex: 正则表达式搜索

    参数 (支持 GET 和 POST):
        token: API Token (必需)
        pattern: 搜索关键词/正则表达式 (必需)
        search_mode: 搜索模式 exact/fuzzy/regex，默认 fuzzy
        case_sensitive: 是否区分大小写，默认 False
        pid: 文集ID，0 表示全局搜索，默认 0
        max_results: 最大返回匹配数，默认 50
        before_lines: 匹配行之前的行数，默认 0
        after_lines: 匹配行之后的行数，默认 0
        context_lines: (兼容参数) 统一设置前后行数，优先级低于 before_lines/after_lines
        page: 页码，默认 1
        limit: 每页文档数量，默认 20

    返回:
        {
            "status": true/false,
            "data": {
                "results": [
                    {
                        "doc_id": 文档ID,
                        "doc_name": 文档名称,
                        "project_id": 文集ID,
                        "project_name": 文集名称,
                        "matches": [
                            {
                                "line_num": 行号,
                                "line": 匹配行内容,
                                "match_positions": [[起始位置, 结束位置]],
                                "before_context": [前面的行],
                                "after_context": [后面的行]
                            }
                        ],
                        "match_count": 匹配数量
                    }
                ],
                "total_docs": 总文档数,
                "total_matches": 总匹配数,
                "page": 当前页,
                "limit": 每页数量,
                "elapsed_time": 搜索耗时(ms)
            }
        }
    """
    start_time = time.time() * 1000

    # 获取参数（支持 GET 和 POST）
    if request.method == 'POST':
        import json
        try:
            params = json.loads(request.body.decode('utf-8'))
        except Exception as e:
            # 如果JSON解析失败，尝试使用 POST 表单数据
            try:
                params = request.POST
            except:
                return JsonResponse({'status': False, 'data': f'无法解析请求数据: {str(e)}'})
    else:
        params = request.GET

    # 验证 token
    token = params.get('token', '')
    try:
        user_token = UserToken.objects.get(token=token)
    except UserToken.DoesNotExist:
        return JsonResponse({'status': False, 'data': 'token无效'})

    # 获取搜索参数
    pattern = params.get('pattern', '').strip()
    if not pattern:
        return JsonResponse({'status': False, 'data': '搜索关键词不能为空'})

    search_mode = params.get('search_mode', 'fuzzy').lower()  # exact/fuzzy/regex
    case_sensitive = str(params.get('case_sensitive', 'false')).lower() == 'true'
    pid = int(params.get('pid', 0))  # 0 表示全局搜索
    max_results = int(params.get('max_results', 50))

    # 上下文行数参数：支持独立的 before_lines/after_lines，也兼容旧的 context_lines
    context_lines = int(params.get('context_lines', 0))  # 兼容参数
    before_lines = int(params.get('before_lines', context_lines))  # 优先使用 before_lines
    after_lines = int(params.get('after_lines', context_lines))    # 优先使用 after_lines

    page_num = int(params.get('page', 1))
    limit = int(params.get('limit', 20))

    # 验证搜索模式
    if search_mode not in ['exact', 'fuzzy', 'regex']:
        return JsonResponse({'status': False, 'data': f'不支持的搜索模式: {search_mode}'})

    try:
        # 第一步：获取文档列表（根据 pid 过滤）
        if pid > 0:
            # 特定文集
            docs_query = Doc.objects.filter(top_doc=pid, status=1)
        else:
            # 全局搜索
            docs_query = Doc.objects.filter(status=1)

        # 预加载文集信息以减少查询次数
        docs_query = docs_query.select_related('create_user')

        # 第二步：准备正则表达式
        if search_mode == 'exact':
            # 精确搜索：转义特殊字符但保留点号等
            # 使用 \b 单词边界来确保精确匹配
            escaped_pattern = re.escape(pattern)
            # 恢复点号（用于匹配如 kt.test）
            escaped_pattern = escaped_pattern.replace(r'\\.', '.')
            regex_pattern = r'\b' + escaped_pattern + r'\b'
            flags = 0 if case_sensitive else re.IGNORECASE
            try:
                compiled_pattern = re.compile(regex_pattern, flags)
            except re.error as e:
                return JsonResponse({'status': False, 'data': f'正则表达式错误: {str(e)}'})

        elif search_mode == 'regex':
            # 正则表达式搜索
            flags = 0 if case_sensitive else re.IGNORECASE
            try:
                compiled_pattern = re.compile(pattern, flags)
            except re.error as e:
                return JsonResponse({'status': False, 'data': f'正则表达式错误: {str(e)}'})

        else:  # fuzzy
            # 模糊搜索：使用 Haystack 全文检索
            # 这个模式先用全文检索找到候选文档，然后再做正则匹配
            escaped_pattern = re.escape(pattern)
            flags = 0 if case_sensitive else re.IGNORECASE
            compiled_pattern = re.compile(escaped_pattern, flags)

        # 第三步：对每个文档进行搜索
        all_results = []
        total_matches = 0
        docs_found = 0

        # 获取文集信息缓存
        project_cache = {}

        for doc in docs_query:
            # 检查是否已达到最大文档数
            if docs_found >= max_results:
                break

            # 获取文档内容
            content = doc.content if doc.content else doc.pre_content
            if not content:
                continue

            lines = content.split('\n')

            # 查找所有匹配行
            matches = []
            doc_match_count = 0

            for line_idx, line in enumerate(lines):
                # 检查是否已达到最大匹配数
                if total_matches >= max_results:
                    break

                match = compiled_pattern.search(line)
                if match:
                    # 计算匹配位置
                    match_positions = []
                    for m in compiled_pattern.finditer(line):
                        match_positions.append([m.start(), m.end()])

                    # 提取上下文（使用独立的 before_lines 和 after_lines）
                    before_context = []
                    if before_lines > 0:
                        start = max(0, line_idx - before_lines)
                        before_context = [
                            {'line_num': i + 1, 'line': lines[i]}
                            for i in range(start, line_idx)
                        ]

                    after_context = []
                    if after_lines > 0:
                        end = min(len(lines), line_idx + after_lines + 1)
                        after_context = [
                            {'line_num': i + 1, 'line': lines[i]}
                            for i in range(line_idx + 1, end)
                        ]

                    match_info = {
                        'line_num': line_idx + 1,
                        'line': line,
                        'match_positions': match_positions,
                        'before_context': before_context,
                        'after_context': after_context,
                    }
                    matches.append(match_info)
                    doc_match_count += 1
                    total_matches += 1

            if matches:
                # 获取文集名称
                if doc.top_doc not in project_cache:
                    try:
                        project = Project.objects.get(id=doc.top_doc)
                        project_cache[doc.top_doc] = project.name
                    except Project.DoesNotExist:
                        project_cache[doc.top_doc] = '未知文集'

                all_results.append({
                    'doc_id': doc.id,
                    'doc_name': doc.name,
                    'project_id': doc.top_doc,
                    'project_name': project_cache[doc.top_doc],
                    'matches': matches,
                    'match_count': doc_match_count,
                })
                docs_found += 1

        # 第四步：分页
        paginator = Paginator(all_results, limit)
        try:
            results_page = paginator.page(page_num)
        except PageNotAnInteger:
            results_page = paginator.page(1)
        except EmptyPage:
            results_page = paginator.page(paginator.num_pages)

        elapsed_time = int((time.time() * 1000) - start_time)

        return JsonResponse({
            'status': True,
            'data': {
                'results': list(results_page),
                'total_docs': paginator.count,
                'total_matches': total_matches,
                'page': results_page.number,
                'limit': limit,
                'elapsed_time': elapsed_time,
                'search_params': {
                    'pattern': pattern,
                    'search_mode': search_mode,
                    'case_sensitive': case_sensitive,
                    'pid': pid,
                    'max_results': max_results,
                    'before_lines': before_lines,
                    'after_lines': after_lines,
                }
            }
        })

    except Exception as e:
        import traceback
        return JsonResponse({
            'status': False,
            'data': str(e),
            'traceback': traceback.format_exc()
        })
