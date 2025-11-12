#!/usr/bin/env python3
# coding:utf-8
"""
查看和分析 MrDoc 搜索日志
"""

import os
import sys
import django
from datetime import datetime, timedelta

# 设置 Django 环境
sys.path.insert(0, os.path.dirname(__file__))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'MrDoc.settings')
django.setup()

from app_doc.models_search import SearchLog, SearchHotKeyword
from django.db.models import Count, Avg


def view_recent_logs(limit=20):
    """查看最近的搜索日志"""
    print("\n" + "="*80)
    print(f"  最近 {limit} 条搜索日志")
    print("="*80 + "\n")

    logs = SearchLog.objects.all().order_by('-created_at')[:limit]

    if not logs:
        print("暂无搜索日志")
        return

    print(f"{'时间':<20} {'关键词':<25} {'模式':<8} {'字段':<10} {'结果':<8} {'耗时':<10}")
    print("-" * 80)

    for log in logs:
        created_at = log.created_at.strftime('%Y-%m-%d %H:%M:%S')
        query = log.query_text[:23] + '...' if len(log.query_text) > 25 else log.query_text
        mode = log.search_mode.upper()
        field = log.search_field
        results = str(log.results_count)
        elapsed = f"{log.elapsed_time}ms"

        print(f"{created_at:<20} {query:<25} {mode:<8} {field:<10} {results:<8} {elapsed:<10}")


def view_statistics():
    """查看搜索统计信息"""
    print("\n" + "="*80)
    print("  搜索统计信息")
    print("="*80 + "\n")

    total_searches = SearchLog.objects.count()
    print(f"总搜索次数: {total_searches}")

    if total_searches == 0:
        print("暂无搜索数据")
        return

    # 平均响应时间
    avg_time = SearchLog.objects.aggregate(Avg('elapsed_time'))['elapsed_time__avg']
    print(f"平均响应时间: {avg_time:.2f}ms")

    # 按模式统计
    print("\n按搜索模式统计:")
    mode_stats = SearchLog.objects.values('search_mode').annotate(count=Count('id')).order_by('-count')
    for stat in mode_stats:
        mode = stat['search_mode'].upper()
        count = stat['count']
        percentage = (count / total_searches) * 100
        print(f"  {mode}: {count} 次 ({percentage:.1f}%)")

    # 按字段统计
    print("\n按搜索字段统计:")
    field_stats = SearchLog.objects.values('search_field').annotate(count=Count('id')).order_by('-count')
    for stat in field_stats:
        field = stat['search_field']
        count = stat['count']
        percentage = (count / total_searches) * 100
        print(f"  {field}: {count} 次 ({percentage:.1f}%)")

    # 热门关键词
    print("\n热门搜索关键词 (Top 10):")
    top_keywords = SearchLog.objects.values('query_text').annotate(
        count=Count('id')
    ).order_by('-count')[:10]

    for idx, kw in enumerate(top_keywords, 1):
        print(f"  {idx}. {kw['query_text']}: {kw['count']} 次")

    # 最近7天趋势
    print("\n最近7天搜索趋势:")
    for i in range(6, -1, -1):
        date = datetime.now() - timedelta(days=i)
        start = date.replace(hour=0, minute=0, second=0, microsecond=0)
        end = date.replace(hour=23, minute=59, second=59, microsecond=999999)

        count = SearchLog.objects.filter(
            created_at__gte=start,
            created_at__lte=end
        ).count()

        date_str = date.strftime('%Y-%m-%d')
        bar = '█' * (count // 2) if count > 0 else ''
        print(f"  {date_str}: {bar} {count}")


def view_hot_keywords(limit=20):
    """查看热门关键词"""
    print("\n" + "="*80)
    print(f"  热门关键词 (Top {limit})")
    print("="*80 + "\n")

    keywords = SearchHotKeyword.objects.all().order_by('-hot_score')[:limit]

    if not keywords:
        print("暂无热门关键词数据")
        print("\n提示: 运行以下命令更新热门关键词:")
        print("  python update_hot_keywords.py")
        return

    print(f"{'关键词':<30} {'搜索次数':<12} {'热度分数':<12} {'最后搜索时间':<20}")
    print("-" * 80)

    for kw in keywords:
        keyword = kw.keyword[:28] + '...' if len(kw.keyword) > 30 else kw.keyword
        count = str(kw.search_count)
        score = f"{kw.hot_score:.2f}"
        last_time = kw.last_searched_at.strftime('%Y-%m-%d %H:%M:%S') if kw.last_searched_at else 'N/A'

        print(f"{keyword:<30} {count:<12} {score:<12} {last_time:<20}")


def main():
    """主函数"""
    if len(sys.argv) > 1:
        command = sys.argv[1]

        if command == 'logs':
            limit = int(sys.argv[2]) if len(sys.argv) > 2 else 20
            view_recent_logs(limit)

        elif command == 'stats':
            view_statistics()

        elif command == 'hot':
            limit = int(sys.argv[2]) if len(sys.argv) > 2 else 20
            view_hot_keywords(limit)

        else:
            print(f"未知命令: {command}")
            print_usage()

    else:
        # 默认显示所有信息
        view_recent_logs(20)
        view_statistics()
        view_hot_keywords(20)


def print_usage():
    """打印使用说明"""
    print("\n使用说明:")
    print("  python view_search_logs.py             # 显示所有信息")
    print("  python view_search_logs.py logs [N]    # 显示最近 N 条日志（默认20）")
    print("  python view_search_logs.py stats       # 显示统计信息")
    print("  python view_search_logs.py hot [N]     # 显示前 N 个热门关键词（默认20）")


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n操作已取消")
        sys.exit(0)
    except Exception as e:
        print(f"\n错误: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
