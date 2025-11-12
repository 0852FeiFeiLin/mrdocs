#!/usr/bin/env python3
# coding:utf-8
"""
从在线 MrDoc 系统同步文档到本地
使用 API Token 进行数据同步
"""

import os
import sys
import django
import requests
import json
from datetime import datetime

# 设置 Django 环境
sys.path.insert(0, os.path.dirname(__file__))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'MrDoc.settings')
django.setup()

from django.contrib.auth.models import User
from app_doc.models import Project, Doc

# 在线系统配置
ONLINE_BASE_URL = 'https://doc.kstai.com'
API_TOKEN = 'b8c9ad373e165f5716e29e1693797d153508879319a8d6a1ee3d0baf'


def get_online_projects():
    """获取在线文集列表"""
    url = f'{ONLINE_BASE_URL}/api/get_projects/'
    params = {'token': API_TOKEN}

    try:
        response = requests.get(url, params=params, timeout=30)
        response.raise_for_status()
        data = response.json()

        if data.get('status'):
            projects = data.get('data', [])
            print(f"✓ 获取到 {len(projects)} 个文集")
            return projects
        else:
            print(f"✗ 获取文集失败: {data.get('data')}")
            return []
    except Exception as e:
        print(f"✗ 请求失败: {e}")
        return []


def get_project_docs(project_id):
    """获取指定文集的文档列表"""
    url = f'{ONLINE_BASE_URL}/api/get_docs/'
    params = {'token': API_TOKEN, 'pid': project_id}

    try:
        response = requests.get(url, params=params, timeout=30)
        response.raise_for_status()
        data = response.json()

        if data.get('status'):
            docs = data.get('data', [])
            return docs
        else:
            print(f"  ✗ 获取文档失败: {data.get('data')}")
            return []
    except Exception as e:
        print(f"  ✗ 请求失败: {e}")
        return []


def get_doc_content(doc_id, project_id, doc_name=''):
    """获取文档内容"""
    url = f'{ONLINE_BASE_URL}/api/get_doc/'
    params = {'token': API_TOKEN, 'did': doc_id, 'pid': project_id}

    try:
        response = requests.get(url, params=params, timeout=30)
        response.raise_for_status()
        data = response.json()

        if data.get('status'):
            doc_data = data.get('data')
            if doc_data:
                # 记录返回的字段
                editor_mode = doc_data.get('editor_mode', 'unknown')
                print(f"    → API返回成功 [editor_mode={editor_mode}]")
            return doc_data
        else:
            print(f"    ✗ API返回失败: {data.get('data')}")
            return None
    except Exception as e:
        print(f"    ✗ 请求异常: {e}")
        return None


def sync_project(online_project, admin_user):
    """同步单个文集"""
    project_name = online_project.get('name', '未命名文集')
    project_id = online_project.get('id')

    print(f"\n同步文集: {project_name} (ID: {project_id})")

    # 创建或更新本地文集
    local_project, created = Project.objects.get_or_create(
        name=f"{project_name}",
        defaults={
            'intro': online_project.get('intro', ''),
            'create_user': admin_user,
            'role': 0,  # 公开
        }
    )

    if created:
        print(f"  ✓ 创建文集: {project_name}")
    else:
        print(f"  ✓ 文集已存在: {project_name}")

    # 获取文档列表
    online_docs = get_project_docs(project_id)
    print(f"  找到 {len(online_docs)} 个文档")

    # 同步文档
    synced_count = 0
    skipped_count = 0

    for idx, online_doc in enumerate(online_docs, 1):
        doc_id = online_doc.get('id')
        doc_name = online_doc.get('name', '未命名文档')
        editor_mode = online_doc.get('editor_mode', 'unknown')

        print(f"\n  [{idx}/{len(online_docs)}] {doc_name}")
        print(f"    doc_id={doc_id}, editor_mode={editor_mode}")

        # 获取完整文档内容
        doc_detail = get_doc_content(doc_id, project_id, doc_name)
        if not doc_detail or not isinstance(doc_detail, dict):
            print(f"    ✗ 跳过: 无法获取文档详情")
            skipped_count += 1
            continue

        # 根据editor_mode选择正确的内容字段
        # editor_mode: 1=Markdown, 2=富文本, 3=表格, 4=思维导图
        content = None
        if editor_mode == 1:
            # Markdown编辑器 - 使用md_content
            content = doc_detail.get('md_content', '')
        elif editor_mode == 2:
            # 富文本编辑器 - 使用html_content或content
            content = doc_detail.get('html_content') or doc_detail.get('content', '')
        elif editor_mode == 3:
            # 表格编辑器 - 使用sheet_content
            content = doc_detail.get('sheet_content', '')
        elif editor_mode == 4:
            # 思维导图 - 使用mind_content
            content = doc_detail.get('mind_content', '')
        else:
            # 未知类型，尝试所有可能的字段
            content = (doc_detail.get('md_content') or
                      doc_detail.get('html_content') or
                      doc_detail.get('content') or
                      doc_detail.get('sheet_content') or
                      doc_detail.get('mind_content') or '')

        if not content:
            print(f"    ✗ 跳过: 内容为空 (可能是目录节点)")
            skipped_count += 1
            continue

        content_len = len(content)
        print(f"    → 内容长度: {content_len} 字符")

        # 创建或更新本地文档
        local_doc, doc_created = Doc.objects.get_or_create(
            name=doc_name,
            top_doc=local_project.id,
            defaults={
                'content': content,
                'pre_content': content,  # 存储完整Markdown内容，不截断！
                'create_user': admin_user,
                'parent_doc': online_doc.get('parent_doc', 0),
                'sort': online_doc.get('sort', 99),
                'status': 1,  # 发布状态
            }
        )

        if doc_created:
            print(f"    ✓ 已创建")
            synced_count += 1
        else:
            # 更新文档内容
            local_doc.content = content
            local_doc.pre_content = content  # 存储完整Markdown内容，不截断！
            local_doc.save()
            print(f"    ✓ 已更新")
            synced_count += 1

    print(f"\n  文集统计: 成功{synced_count}个, 跳过{skipped_count}个")
    return synced_count


def main():
    """主函数"""
    print("="*70)
    print("  从在线 MrDoc 系统同步文档")
    print("  时间:", datetime.now().strftime('%Y-%m-%d %H:%M:%S'))
    print("="*70)

    # 获取管理员用户
    try:
        admin_user = User.objects.get(username='admin')
        print(f"✓ 使用管理员账户: {admin_user.username}")
    except User.DoesNotExist:
        print("✗ 未找到管理员用户，请先创建")
        return 1

    # 获取在线文集列表
    print("\n获取在线文集列表...")
    online_projects = get_online_projects()

    if not online_projects:
        print("\n没有可同步的文集")
        return 0

    # 同步每个文集
    total_synced = 0
    for project in online_projects:
        synced_count = sync_project(project, admin_user)
        total_synced += synced_count

    # 重建搜索索引
    print("\n" + "="*70)
    print("  同步完成，重建搜索索引...")
    print("="*70)

    from django.core.management import call_command
    call_command('rebuild_index', '--noinput')

    print("\n" + "="*70)
    print(f"  ✅ 同步完成！共同步 {total_synced} 个文档")
    print("="*70)
    print(f"\n访问本地系统: http://localhost:8000/")

    return 0


if __name__ == '__main__':
    sys.exit(main())
