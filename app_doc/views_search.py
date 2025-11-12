# coding:utf-8
# @文件: views_search.py
# @创建者：州的先生
# #日期：2020/11/22
# 博客地址：zmister.com


from haystack.generic_views import SearchView as BaseSearchView
from django.db.models import Q
from haystack.views import SearchView
from haystack.query import SearchQuerySet
from app_doc.models import *
import datetime
import time

# 导入搜索工具函数
try:
    from app_doc.search_utils import log_search, get_client_ip
    SEARCH_LOG_ENABLED = True
except ImportError:
    SEARCH_LOG_ENABLED = False


class DocSearchView2(BaseSearchView):

    def get_queryset(self):
        queryset = super(DocSearchView, self).get_queryset()
        # further filter queryset based on some set of criteria
        return queryset.filter(pub_date__gte=date(2015, 1, 1))

    def get_context_data(self, *args, **kwargs):
        context = super(DocSearchView, self).get_context_data(*args, **kwargs)
        # do something
        return context

# 文档搜索 - 基于Haystack全文搜索
class DocSearchView(SearchView):
    results_per_page = 10

    def __call__(self, request):
        # 记录开始时间
        start_time = time.time() * 1000  # 毫秒

        self.request = request
        date_type = self.request.GET.get('d_type', 'recent')
        date_range = self.request.GET.get('d_range', 'all')  # 时间范围，默认不限，all

        # 获取搜索模式：and / or，默认 or
        search_mode = self.request.GET.get('mode', 'or').lower()

        # 获取搜索字段：all / title / content，默认 all
        search_field = self.request.GET.get('field', 'all').lower()

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
                start_date = datetime.datetime.strptime('1900-01-01', '%Y-%m-%d')
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

        # 是否时间筛选
        if date_range == 'all':
            is_date_range = False
        else:
            is_date_range = True

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
            view_list = [i.id for i in Project.objects.filter(role=0)] # 公开文集

        if len(view_list) > 0:
            sqs = SearchQuerySet().filter(
                top_doc__in=view_list
            ).filter(
                modify_time__gte=start_date,
                modify_time__lte=end_date)
        else:
            sqs = SearchQuerySet().filter(
                top_doc__in=None
            ).filter(
                modify_time__gte=start_date,
                modify_time__lte=end_date)

        self.form = self.build_form(form_kwargs={'searchqueryset': sqs})
        self.query = self.get_query().replace("\n",'').replace("\r",'')

        # 处理 AND/OR 搜索模式
        if self.query and search_mode == 'and':
            # AND 模式：所有词都必须出现
            query_terms = self.query.split()
            self.query = ' AND '.join(query_terms)

        # 处理搜索字段
        if self.query:
            if search_field == 'title':
                # 仅搜索标题
                self.form.searchqueryset = sqs.filter(title__contains=self.query)
            elif search_field == 'content':
                # 仅搜索内容
                self.form.searchqueryset = sqs.filter(content__contains=self.query)
            # search_field == 'all' 时使用默认的全文搜索，不需要额外处理

        self.results = self.get_results()

        # 记录搜索日志
        if SEARCH_LOG_ENABLED and self.query:
            elapsed_time = int((time.time() * 1000) - start_time)
            try:
                log_search(
                    query_text=self.query,
                    user=self.request.user if is_auth else None,
                    ip_address=get_client_ip(self.request),
                    results_count=len(self.results) if self.results else 0,
                    search_mode=search_mode,
                    search_field=search_field,
                    elapsed_time=elapsed_time
                )
            except Exception as e:
                # 日志记录失败不影响搜索功能
                print(f"记录搜索日志失败: {e}")

        return self.create_response()

    def extra_context(self):
        context = {
            'date_range': self.request.GET.get('d_range', 'all'),
            'search_mode': self.request.GET.get('mode', 'or'),
            'search_field': self.request.GET.get('field', 'all'),
        }
        return context




