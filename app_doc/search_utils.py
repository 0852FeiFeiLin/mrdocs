# coding:utf-8
# @文件: search_utils.py
# @创建者: AI Assistant
# @日期: 2025-10-28
# 搜索工具函数

import time
from datetime import datetime, timedelta
from django.db.models import Count, Q
from app_doc.models_search import SearchLog, SearchHotKeyword, SearchSynonym


def log_search(query_text, user=None, ip_address=None, results_count=0,
               search_mode='or', search_field='all', elapsed_time=0):
    """
    记录搜索日志

    Args:
        query_text: 搜索词
        user: 搜索用户（可选）
        ip_address: IP地址
        results_count: 结果数量
        search_mode: 搜索模式 (and/or)
        search_field: 搜索字段 (all/title/content)
        elapsed_time: 搜索耗时（毫秒）

    Returns:
        SearchLog 实例
    """
    try:
        search_log = SearchLog.objects.create(
            query_text=query_text[:500],  # 限制长度
            user=user if user and user.is_authenticated else None,
            ip_address=ip_address,
            results_count=results_count,
            search_mode=search_mode,
            search_field=search_field,
            elapsed_time=elapsed_time,
        )
        return search_log
    except Exception as e:
        print(f"记录搜索日志失败: {e}")
        return None


def update_hot_keywords(days=7, min_count=2):
    """
    更新热门搜索词

    Args:
        days: 统计最近N天的数据
        min_count: 最小搜索次数

    Returns:
        更新的关键词数量
    """
    try:
        # 计算时间范围
        start_date = datetime.now() - timedelta(days=days)

        # 聚合搜索日志
        keyword_stats = SearchLog.objects.filter(
            created_at__gte=start_date,
            query_text__isnull=False
        ).exclude(
            query_text=''
        ).values('query_text').annotate(
            count=Count('id')
        ).filter(
            count__gte=min_count
        ).order_by('-count')[:100]  # 只保留前100个

        updated_count = 0
        for stat in keyword_stats:
            keyword = stat['query_text']
            count = stat['count']

            # 计算热度分数（基于搜索次数和时间衰减）
            # 简单算法：count * (1 - 衰减系数)
            # 衰减系数 = (当前时间 - 最后搜索时间) / 总时间范围
            last_log = SearchLog.objects.filter(
                query_text=keyword
            ).order_by('-created_at').first()

            if last_log:
                time_diff = (datetime.now() - last_log.created_at.replace(tzinfo=None)).total_seconds()
                decay_factor = max(0, 1 - (time_diff / (days * 86400)))  # 86400秒 = 1天
                hot_score = count * decay_factor

                # 更新或创建热门关键词
                hot_keyword, created = SearchHotKeyword.objects.update_or_create(
                    keyword=keyword,
                    defaults={
                        'search_count': count,
                        'hot_score': hot_score,
                        'last_searched_at': last_log.created_at,
                    }
                )
                updated_count += 1

        return updated_count
    except Exception as e:
        print(f"更新热门搜索词失败: {e}")
        return 0


def get_hot_keywords(limit=10):
    """
    获取热门搜索词

    Args:
        limit: 返回数量

    Returns:
        热门关键词列表
    """
    try:
        hot_keywords = SearchHotKeyword.objects.all()[:limit]
        return [
            {
                'keyword': kw.keyword,
                'count': kw.search_count,
                'score': round(kw.hot_score, 2),
            }
            for kw in hot_keywords
        ]
    except Exception as e:
        print(f"获取热门搜索词失败: {e}")
        return []


def get_search_suggestions(query, limit=5):
    """
    获取搜索建议
    基于历史搜索和热门关键词

    Args:
        query: 用户输入的查询词
        limit: 返回数量

    Returns:
        建议列表
    """
    if not query or len(query.strip()) == 0:
        # 返回热门搜索词
        return [kw['keyword'] for kw in get_hot_keywords(limit)]

    try:
        # 前缀匹配热门关键词
        suggestions = SearchHotKeyword.objects.filter(
            keyword__istartswith=query
        ).order_by('-hot_score')[:limit]

        result = [kw.keyword for kw in suggestions]

        # 如果结果不足，从搜索日志中补充
        if len(result) < limit:
            additional = SearchLog.objects.filter(
                query_text__icontains=query
            ).values('query_text').annotate(
                count=Count('id')
            ).order_by('-count')[:limit - len(result)]

            result.extend([item['query_text'] for item in additional])

        return result[:limit]
    except Exception as e:
        print(f"获取搜索建议失败: {e}")
        return []


def expand_query_with_synonyms(query):
    """
    使用同义词扩展查询

    Args:
        query: 原始查询词

    Returns:
        扩展后的查询字符串
    """
    try:
        # 分词
        import jieba
        terms = list(jieba.cut(query))

        # 查找同义词
        expanded_terms = []
        for term in terms:
            expanded_terms.append(term)

            # 查找该词的同义词
            synonyms = SearchSynonym.objects.filter(
                word=term,
                is_active=True
            ).first()

            if synonyms:
                expanded_terms.extend(synonyms.get_synonym_list())

        # 去重并返回
        unique_terms = list(set(expanded_terms))
        return ' OR '.join(unique_terms)
    except Exception as e:
        print(f"扩展查询失败: {e}")
        return query


def get_client_ip(request):
    """
    获取客户端 IP 地址

    Args:
        request: Django request 对象

    Returns:
        IP 地址字符串
    """
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        ip = x_forwarded_for.split(',')[0]
    else:
        ip = request.META.get('REMOTE_ADDR')
    return ip
