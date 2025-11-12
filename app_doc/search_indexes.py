# coding:utf-8
# @文件: search_indexes.py
# @创建者：州的先生
# #日期：2020/11/22
# 博客地址：zmister.com

from haystack import indexes
from app_doc.models import *

# 文档索引
class DocIndex(indexes.SearchIndex,indexes.Indexable):
    # 全文搜索字段（标题+内容）
    text = indexes.CharField(document=True, use_template=True)

    # 独立的标题字段（用于标题搜索，权重更高）
    title = indexes.CharField(model_attr='name')

    # 独立的内容字段（用于内容搜索）
    content = indexes.CharField(model_attr='content')

    # 元数据字段
    top_doc = indexes.IntegerField(model_attr='top_doc')
    modify_time = indexes.DateTimeField(model_attr='modify_time')
    create_user = indexes.IntegerField(model_attr='create_user_id')

    def get_model(self):
        return Doc

    def index_queryset(self, using=None):
        return self.get_model().objects.filter(status=1)


class ProjectIndex(indexes.SearchIndex, indexes.Indexable):
    text = indexes.CharField(document=True, use_template=True)
    create_user = indexes.IntegerField(model_attr='create_user_id')
    modify_time = indexes.DateTimeField(model_attr='modify_time')

    def get_model(self):
        return Project

    def index_queryset(self, using=None):
        return self.get_model().objects.all()
