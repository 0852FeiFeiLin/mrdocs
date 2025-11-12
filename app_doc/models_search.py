# coding:utf-8
# @文件: models_search.py
# @创建者: AI Assistant
# @日期: 2025-10-28
# 搜索相关模型

from django.db import models
from django.contrib.auth.models import User


class SearchLog(models.Model):
    """
    搜索日志模型
    记录所有搜索行为，用于：
    - 搜索统计和分析
    - 热门搜索词
    - 搜索建议
    - 用户搜索历史
    """
    # 搜索词
    query_text = models.CharField(max_length=500, verbose_name='搜索词', db_index=True)

    # 用户信息（可选，未登录用户为 NULL）
    user = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        verbose_name='搜索用户'
    )

    # IP 地址
    ip_address = models.GenericIPAddressField(verbose_name='IP地址', null=True, blank=True)

    # 搜索结果数量
    results_count = models.IntegerField(default=0, verbose_name='结果数量')

    # 搜索模式：and / or
    search_mode = models.CharField(max_length=10, default='or', verbose_name='搜索模式')

    # 搜索字段：all / title / content
    search_field = models.CharField(max_length=20, default='all', verbose_name='搜索字段')

    # 搜索耗时（毫秒）
    elapsed_time = models.IntegerField(default=0, verbose_name='搜索耗时(ms)')

    # 是否有点击结果
    has_click = models.BooleanField(default=False, verbose_name='是否点击结果')

    # 创建时间
    created_at = models.DateTimeField(auto_now_add=True, verbose_name='搜索时间', db_index=True)

    class Meta:
        db_table = 'search_log'
        verbose_name = '搜索日志'
        verbose_name_plural = verbose_name
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['query_text', '-created_at']),
            models.Index(fields=['user', '-created_at']),
        ]

    def __str__(self):
        return f'{self.query_text} ({self.results_count} results)'


class SearchHotKeyword(models.Model):
    """
    热门搜索词模型
    定期汇总 SearchLog 生成
    """
    # 关键词
    keyword = models.CharField(max_length=200, verbose_name='关键词', unique=True, db_index=True)

    # 搜索次数
    search_count = models.IntegerField(default=0, verbose_name='搜索次数')

    # 最后搜索时间
    last_searched_at = models.DateTimeField(auto_now=True, verbose_name='最后搜索时间')

    # 热度分数（基于搜索次数和时间衰减）
    hot_score = models.FloatField(default=0.0, verbose_name='热度分数', db_index=True)

    # 更新时间
    updated_at = models.DateTimeField(auto_now=True, verbose_name='更新时间')

    class Meta:
        db_table = 'search_hot_keyword'
        verbose_name = '热门搜索词'
        verbose_name_plural = verbose_name
        ordering = ['-hot_score', '-search_count']

    def __str__(self):
        return f'{self.keyword} ({self.search_count})'


class SearchSynonym(models.Model):
    """
    搜索同义词模型
    用于扩展搜索，提升召回率
    """
    # 原词
    word = models.CharField(max_length=100, verbose_name='原词', db_index=True)

    # 同义词（逗号分隔）
    synonyms = models.TextField(verbose_name='同义词列表')

    # 是否启用
    is_active = models.BooleanField(default=True, verbose_name='是否启用')

    # 创建时间
    created_at = models.DateTimeField(auto_now_add=True, verbose_name='创建时间')

    # 更新时间
    updated_at = models.DateTimeField(auto_now=True, verbose_name='更新时间')

    class Meta:
        db_table = 'search_synonym'
        verbose_name = '搜索同义词'
        verbose_name_plural = verbose_name

    def __str__(self):
        return f'{self.word} → {self.synonyms}'

    def get_synonym_list(self):
        """获取同义词列表"""
        return [s.strip() for s in self.synonyms.split(',') if s.strip()]
