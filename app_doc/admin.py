from django.contrib import admin
from app_doc.models_search import SearchLog, SearchHotKeyword, SearchSynonym


# 搜索日志管理
@admin.register(SearchLog)
class SearchLogAdmin(admin.ModelAdmin):
    list_display = ('query_text', 'user', 'ip_address', 'results_count',
                    'search_mode', 'search_field', 'elapsed_time', 'created_at')
    list_filter = ('search_mode', 'search_field', 'created_at')
    search_fields = ('query_text', 'ip_address')
    date_hierarchy = 'created_at'
    readonly_fields = ('query_text', 'user', 'ip_address', 'results_count',
                      'search_mode', 'search_field', 'elapsed_time', 'created_at')
    ordering = ('-created_at',)

    def has_add_permission(self, request):
        # 禁止手动添加搜索日志
        return False

    def has_delete_permission(self, request, obj=None):
        # 允许删除旧日志
        return True


# 热门关键词管理
@admin.register(SearchHotKeyword)
class SearchHotKeywordAdmin(admin.ModelAdmin):
    list_display = ('keyword', 'search_count', 'hot_score', 'last_searched_at')
    list_filter = ('last_searched_at',)
    search_fields = ('keyword',)
    ordering = ('-hot_score',)
    readonly_fields = ('search_count', 'hot_score', 'last_searched_at')


# 同义词管理
@admin.register(SearchSynonym)
class SearchSynonymAdmin(admin.ModelAdmin):
    list_display = ('word', 'get_synonym_preview', 'is_active', 'created_at')
    list_filter = ('is_active', 'created_at')
    search_fields = ('word', 'synonyms')
    ordering = ('word',)

    def get_synonym_preview(self, obj):
        """显示同义词预览（前50个字符）"""
        if len(obj.synonyms) > 50:
            return obj.synonyms[:50] + '...'
        return obj.synonyms
    get_synonym_preview.short_description = '同义词'
