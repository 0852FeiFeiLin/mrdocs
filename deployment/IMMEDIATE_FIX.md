# 立即修复步骤

## 问题分析

1. **Nginx容器不断重启** - 配置文件引用了不存在的文件
2. **MrDoc应用无响应** - 应用可能未正确启动

## 立即执行修复

### 方案1：紧急修复（最快）
```bash
cd /root/kt/mrdocs
./deployment/scripts/emergency_fix.sh
```

### 方案2：深度诊断（推荐）
```bash
cd /root/kt/mrdocs
./deployment/scripts/diagnose_and_fix.sh
```
这会显示详细的错误信息，帮助定位问题。

### 方案3：快速检查
```bash
cd /root/kt/mrdocs
./deployment/scripts/quick_fix.sh
```

## 手动修复步骤

如果脚本无法执行，手动运行：

```bash
# 1. 修复Nginx配置
cd /root/kt/mrdocs
sed -i 's/include \/etc\/nginx\/snippets\/mrdoc-common.conf;//g' deployment/nginx/mrdoc.conf

# 2. 重启Nginx
docker restart mrdocs-safe-nginx

# 3. 查看应用日志
docker logs mrdocs-safe-app --tail 100

# 4. 如果应用有问题，重新构建
docker-compose -f deployment/docker/docker-compose.yml up -d --build mrdocs-safe-app
```

## 检查要点

1. 查看应用详细日志：
```bash
docker logs mrdocs-safe-app
```

2. 检查Python依赖是否安装：
```bash
docker exec mrdocs-safe-app pip list | grep Django
```

3. 测试数据库连接：
```bash
docker exec mrdocs-safe-app python -c "import MySQLdb; print('MySQL模块正常')"
```

## 预期结果

修复后应该看到：
- Nginx容器状态：Up（不再重启）
- MrDoc应用：响应8081端口
- 所有端口正常监听：8081, 8082, 3307, 6380

## 访问测试

```bash
curl http://localhost:8081
curl http://localhost:8082/health
```

如果仍有问题，请运行`diagnose_and_fix.sh`脚本并提供输出日志。