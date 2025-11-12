# API接口无"API文档"

 基于我的分析，MrDoc确实有API接口，但并没有提供传统意义上的"API文档"（如Swagger/OpenAPI文档）。让我总结一下MrDoc的API情况。

⏺ 📚 MrDoc API 接口分析

  基于对MrDoc源码的分析，确实有API接口，但没有传统的API文档页面。

  🔍 API 接口概览

  MrDoc 提供了两套API接口：

  1. 传统Token API (/api/)

  基础路径: http://服务器IP:8081/api/

  接口列表：
  ├── manage_token/           # Token管理
  ├── get_projects/           # 获取文集列表
  ├── get_project/            # 获取文集信息
  ├── get_docs/               # 获取文集的文档列表
  ├── get_level_docs/         # 获取文集的文档列表(层级)
  ├── get_self_docs/          # 获取自己的文档列表
  ├── get_doc/                # 获取单篇文档
  ├── get_doc_previous_next/  # 获取文档上下篇
  ├── create_project/         # 新建文集
  ├── create_doc/             # 新建文档
  ├── modify_doc/             # 修改文档
  ├── delete_doc/             # 删除文档
  ├── upload_img/             # 上传图片
  ├── upload_img_url/         # 上传URL图片
  ├── check_token/            # 验证Token
  ├── get_timestamp/          # 获取服务器时间
  └── oauth0/                 # Token验证登录

  2. RESTful API (/api_app/)

  基础路径: http://服务器IP:8081/api_app/

  接口列表：
  ├── login/                  # 登录认证
  ├── projects/               # 文集CRUD
  ├── docs/                   # 文档CRUD
  ├── doctemps/               # 文档模板
  ├── images/                 # 图片管理
  ├── imggroups/              # 图片分组
  └── attachments/            # 附件管理

  🔑 API 认证方式

  Token认证

  # 1. 获取Token（在Web界面）
  访问: http://服务器IP:8081/admin/
  路径: 用户设置 → Token管理

  # 2. 使用Token调用API
  curl -H "Authorization: Token your_token_here" \
       http://服务器IP:8081/api/get_projects/

  时间戳认证

  # 用于oauth0接口
  curl "http://服务器IP:8081/api/oauth0/?username=admin&timestamp=1234567890&randstr=abc&hashstr=xyz"

  📖 API使用示例

  获取文集列表

  curl -X GET "http://服务器IP:8081/api/get_projects/" \
       -H "Authorization: Token YOUR_TOKEN"

  获取文档内容

  curl -X GET "http://服务器IP:8081/api/get_doc/?doc_id=1" \
       -H "Authorization: Token YOUR_TOKEN"

  创建新文档

  curl -X POST "http://服务器IP:8081/api/create_doc/" \
       -H "Authorization: Token YOUR_TOKEN" \
       -H "Content-Type: application/json" \
       -d '{"title": "新文档", "content": "文档内容", "project_id": 1}'

  💡 API文档现状

  ❌ 没有在线API文档
  - 没有Swagger/OpenAPI文档
  - 没有自动生成的API文档页面
  - 没有交互式API测试界面

  ✅ 但有这些资源
  - 源码中的注释说明
  - Token管理页面：http://服务器IP:8081/admin/ → 用户设置 → Token管理
  - 客户端和扩展程序使用这些API

  🛠️ 如何探索API

  1. 通过源码了解

  # 查看API端点
  cat deployment/源码目录/app_api/urls.py
  cat deployment/源码目录/app_api/urls_app.py

  # 查看API实现
  cat deployment/源码目录/app_api/views.py
  cat deployment/源码目录/app_api/views_app.py

  2. 通过Token管理页面

  访问: http://服务器IP:8081/admin/
  登录 → 用户设置 → Token管理

  3. 网络请求抓包

  使用浏览器开发者工具查看MrDoc前端如何调用API

  🔧 实际使用场景

  MrDoc的API主要用于：
  - 📱 移动端APP
  - 🖥️ 桌面客户端
  - 🔌 浏览器扩展
  - 🤖 自动化脚本
  - 📊 第三方集成

  📋 总结

  MrDoc有完整的API接口，但没有专门的API文档页面。

  如果你需要使用API：
  1. 获取Token：登录Web界面 → 用户设置 → Token管理
  2. 参考源码：查看 app_api/urls.py 了解端点
  3. 测试接口：使用Postman或curl工具测试
  4. 查看响应：通过实际调用了解数据格式

  这是一个比较传统的API设计，适合有一定开发经验的用户使用。 🔧