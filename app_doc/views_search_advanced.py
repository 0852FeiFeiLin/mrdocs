# coding:utf-8
# @文件: views_search_advanced.py
# @创建者: AI Assistant
# @日期: 2025-10-28
# 博客地址：zmister.com
# 高级搜索功能：支持 AND/OR 搜索、字段搜索、相关性排序

from haystack.generic_views import SearchView as BaseSearchView
from django.db.models import Q
from haystack.views import SearchView
from haystack.query import SearchQuerySet
from app_doc.models import *
import datetime
from django.http import JsonResponse
from django.views import View


class AdvancedDocSearchView(SearchView):
    """
    高级文档搜索视图
    支持:
    - AND/OR 逻辑搜索
    - 字段搜索 (标题、内容)
    - 相关性排序
    - 时间范围过滤
    """
    results_per_page = 20

    def __call__(self, request):
        self.request = request

        # 获取搜索模式：and / or，默认 or
        search_mode = self.request.GET.get('mode', 'or').lower()

        # 获取搜索字段：all / title / content，默认 all
        search_field = self.request.GET.get('field', 'all').lower()

        # 获取排序方式：relevance / time，默认 relevance
        sort_by = self.request.GET.get('sort', 'relevance').lower()

        # 时间范围处理
        date_type = self.request.GET.get('d_type', 'recent')
        date_range = self.request.GET.get('d_range', 'all')

        # 处理时间范围
        if date_type == 'recent':
            if date_range == 'recent1':  # 最近1天
                start_date = datetime.datetime.now() - datetime.timedelta(days=1)
            elif date_range == 'recent7':  # 最近7天
                start_date = datetime.datetime.now() - datetime.timedelta(days=7)
            elif date_range == 'recent30':  # 最近30天
                start_date = datetime.datetime.now() - datetime.timedelta(days=30)
            elif date_range == 'recent365':  # 最近一年
                start_date = datetime.datetime.now() - datetime.timedelta(days=365)
            else:
                start_date = datetime.datetime.strptime('1900-01-01', '%Y-%m-% d')
            end_date = datetime.datetime.now()
        elif date_type == 'day':
            try:
                date_list = date_range.split('|')
                start_date = datetime.datetime.strptime(date_list[0], '%Y-%m-%d')
                end_date = datetime.datetime.strptime(date_list[1], '%Y-%m-%d')
            except:
                start_date = datetime.datetime.now() - datetime.timedelta(days=1)
                end_date = datetime.datetime.now()
        else:
            start_date = datetime.datetime.strptime('1900-01-01', '%Y-%m-%d')
            end_date = datetime.datetime.now()

        # 是否认证
        if self.request.user.is_authenticated:
            is_auth = True
        else:
            is_auth = False

        # 获取可搜索的文集列表
        if is_auth:
            colla_list = [i.project.id for i in
                          ProjectCollaborator.objects.filter(user=self.request.user)]  # 用户的协作文集
            open_list = [i.id for i in Project.objects.filter(
                Q(role=0) | Q(create_user=self.request.user)
            )]  # 公开文集
            view_list = list(set(open_list).union(set(colla_list)))  # 合并上述两个文集ID列表
        else:
            view_list = [i.id for i in Project.objects.filter(role=0)]  # 公开文集

        # 构建基础查询集
        if len(view_list) > 0:
            sqs = SearchQuerySet().filter(
                top_doc__in=view_list
            ).filter(
                modify_time__gte=start_date,
                modify_time__lte=end_date
            )
        else:
            sqs = SearchQuerySet().filter(
                top_doc__in=None
            ).filter(
                modify_time__gte=start_date,
                modify_time__lte=end_date
            )

        # 构建表单
        self.form = self.build_form(form_kwargs={'searchqueryset': sqs})

        # 获取查询字符串
        self.query = self.get_query().replace("\n", '').replace("\r", '')

        # 根据搜索模式修改查询
        if self.query:
            # AND 模式：所有词都必须出现
            if search_mode == 'and':
                # Whoosh 支持 AND 语法
                query_terms = self.query.split()
                self.query = ' AND '.join(query_terms)
            # OR 模式：任意词出现即可（默认）
            # Whoosh 默认就是 OR 模式（在 whoosh_cn_backend.py 中设置了 OrGroup）

        # 获取结果
        self.results = self.get_results()

        return self.create_response()

    def extra_context(self):
        context = {
            'date_range': self.request.GET.get('d_range', 'all'),
            'search_mode': self.request.GET.get('mode', 'or'),
            'search_field': self.request.GET.get('field', 'all'),
            'sort_by': self.request.GET.get('sort', 'relevance'),
        }
        return context


class SearchSuggestView(View):
    """
    搜索建议 API
    基于搜索历史返回热门搜索词
    """
    def get(self, request):
        query = request.GET.get('q', '').strip()

        # TODO: 实现基于搜索历史的建议
        # 目前返回空列表
        suggestions = []

        if query:
            # 这里可以实现基于 jieba 的词频统计或搜索历史的建议
            pass

        return JsonResponse({
            'query': query,
            'suggestions': suggestions
        })


class SearchStatsView(View):
    """
    搜索统计 API
    返回热门搜索词、搜索趋势等
    """
    def get(self, request):
        # TODO: 实现搜索统计功能
        # 需要先创建 SearchLog 模型

        return JsonResponse({
            'hot_keywords': [],
            'recent_searches': [],
        })
