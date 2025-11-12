#!/usr/bin/env python3
# coding:utf-8
"""
创建 MrDoc 测试数据
"""

import os
import sys
import django

# 设置 Django 环境
sys.path.insert(0, os.path.dirname(__file__))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'MrDoc.settings')
django.setup()

from django.contrib.auth.models import User
from app_doc.models import Project, Doc


def create_test_data():
    """创建测试数据"""
    print("开始创建测试数据...")

    # 获取管理员用户
    try:
        admin_user = User.objects.get(username='admin')
        print(f"✓ 找到管理员用户: {admin_user.username}")
    except User.DoesNotExist:
        print("✗ 未找到管理员用户")
        return False

    # 创建测试文集
    print("\n创建测试文集...")
    project, created = Project.objects.get_or_create(
        name='搜索功能测试文集',
        defaults={
            'intro': '用于测试搜索功能的文集',
            'create_user': admin_user,
            'role': 0,  # 公开
        }
    )
    if created:
        print(f"✓ 创建文集: {project.name}")
    else:
        print(f"✓ 文集已存在: {project.name}")

    # 创建测试文档
    print("\n创建测试文档...")

    test_docs = [
        {
            'name': 'Python 基础教程',
            'content': '''# Python 基础教程

Python 是一种高级编程语言，具有简洁易读的语法。

## 特点
- 简单易学
- 功能强大
- 社区活跃

## 应用领域
Python 广泛应用于：
- Web 开发
- 数据分析
- 人工智能
- 自动化运维
''',
        },
        {
            'name': 'Django 框架入门',
            'content': '''# Django 框架入门

Django 是 Python 的一个 Web 框架，遵循 MTV 设计模式。

## 核心组件
- Model：数据模型
- Template：模板系统
- View：视图逻辑

## 优势
- 快速开发
- 安全可靠
- 可扩展性强
''',
        },
        {
            'name': '文档管理系统设计',
            'content': '''# 文档管理系统设计

MrDoc 是一个基于 Django 的文档管理系统。

## 核心功能
- 文档编辑
- 全文检索
- 权限管理
- 团队协作

## 技术栈
- Django 4.2
- Whoosh 搜索引擎
- Markdown 编辑器
''',
        },
        {
            'name': 'Python 数据分析',
            'content': '''# Python 数据分析

使用 Python 进行数据分析的常用工具。

## 主要库
- NumPy：数值计算
- Pandas：数据处理
- Matplotlib：数据可视化

## 应用场景
- 统计分析
- 机器学习
- 商业智能
''',
        },
        {
            'name': 'Web 开发最佳实践',
            'content': '''# Web 开发最佳实践

现代 Web 开发的推荐做法。

## 前端技术
- HTML5
- CSS3
- JavaScript

## 后端技术
- Python Django
- RESTful API
- 数据库设计

## 部署运维
- Docker 容器化
- Nginx 反向代理
- 持续集成
''',
        },
    ]

    created_docs = []
    for idx, doc_data in enumerate(test_docs):
        doc, created = Doc.objects.get_or_create(
            name=doc_data['name'],
            top_doc=project.id,
            defaults={
                'content': doc_data['content'],
                'pre_content': doc_data['content'][:200],
                'create_user': admin_user,
                'parent_doc': 0,
                'sort': idx + 1,
            }
        )
        if created:
            print(f"  ✓ 创建文档: {doc.name}")
            created_docs.append(doc)
        else:
            print(f"  ✓ 文档已存在: {doc.name}")

    print(f"\n✓ 成功创建 {len(created_docs)} 个文档")

    # 重建搜索索引
    print("\n重建搜索索引...")
    from django.core.management import call_command
    call_command('rebuild_index', '--noinput')
    print("✓ 搜索索引重建完成")

    print("\n" + "="*60)
    print("  测试数据创建完成！")
    print("="*60)
    print(f"\n文集名称: {project.name}")
    print(f"文档数量: {Doc.objects.filter(top_doc=project.id).count()}")
    print(f"访问地址: http://localhost:8000/project-{project.id}/")
    print("\n登录信息:")
    print("  用户名: admin")
    print("  密码: admin123")
    print("\n搜索测试关键词:")
    print("  - Python")
    print("  - Django")
    print("  - 文档管理")
    print("  - Python Django (AND 模式)")
    print("  - Web 开发 (OR 模式)")

    return True


if __name__ == '__main__':
    success = create_test_data()
    sys.exit(0 if success else 1)
