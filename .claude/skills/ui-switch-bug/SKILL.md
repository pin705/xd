---
name: ui-switch-bug
description: This skill should be used when the user reports "白屏" after switching between old and new UI, mentions "新老界面切换", or discusses blank screen issues when switching between JSP (old) and Vue (new) interfaces.
version: 1.0.0
project: xiand
---

# 新老界面切换白屏问题

## 问题描述

用户按以下顺序操作时会出现白屏：
1. 新界面（Vue/HTTP API）登录
2. 老界面（JSP）登录 → 白屏

## 根本原因

**虚拟连接与Socket连接冲突**

- 老界面使用 JSP 直接 Socket 连接到游戏服务器（13800端口）
- 新界面使用 HTTP API（8888端口）创建虚拟连接（BufferConnection）

当玩家通过新界面登录后，再用老界面登录时：
1. `login_check.pike` 通过 `find_player()` 找到了已存在的玩家对象
2. 调用 `reconnect()` 尝试重连
3. 但玩家对象的连接是虚拟连接，数据被发送到虚拟连接而不是Socket
4. Socket 的 `read()` 读不到数据 → `data` 为空 → 白屏

## 解决方案

修改 `lowlib/system/cmds/login_check.pike`，在检测到用户有虚拟连接时：

1. 检查 HTTP API daemon 是否存在
2. 检查用户是否有虚拟连接（`has_virtual_connection()`）
3. 如果有，清除虚拟连接并销毁旧玩家对象
4. 重新创建玩家对象（首次登录流程）

## 关键代码位置

**文件**: `lowlib/system/cmds/login_check.pike`

**位置**: 第52-110行（第一个reconnect路径）和 第133-192行（第二个reconnect路径）

```pike
// 检查并清除虚拟连接（解决新老界面切换白屏问题）
object http_api_d = find_object(ROOT + "/gamelib/single/daemons/http_api_daemon.pike");
if(http_api_d && functionp(http_api_d->has_virtual_connection)
   && http_api_d->has_virtual_connection(user_name)) {
    // 清除虚拟连接
    if(functionp(http_api_d->remove_virtual_connection))
        http_api_d->remove_virtual_connection(user_name);
    // 从 CONND 中移除玩家
    object connd = find_object(SROOT + "/connd.pike");
    if(connd && functionp(connd->erase_user))
        connd->erase_user(me);
    // 销毁旧玩家对象
    destruct(me);
    // 重新创建玩家对象（首次登录流程）
    program u;
    object m;
    catch{
        m=(object)(ROOT+"/"+path+"/master.pike");
    };
    if(m){
        u=m->connect();
    }
    if(!u){
        u=(program)(ROOT+"/"+path+"/clone/user.pike");
    }
    me=u();
    me->set_name(user_name);
    me->set_userip(userip);
    me->set_project(path);
    if(me->setup(lgpswd)) {
        me->is_http_api_user = 0;
        exec(me,previous_object());
        if(environment(me)==0){
            me->move(LOW_VOID_OB);
        }
        destruct(previous_object());
    }
}
```

## 虚拟连接管理函数

xiand 的虚拟连接管理函数在 `_http_api_mod/virtual_conn.pike` 模块中：

```pike
// 检查用户是否有虚拟连接
int has_virtual_connection(string userid)
{
    if(!userid) return 0;
    mixed vconn = vconnections[userid];
    return vconn != 0 && vconn != UNDEFINED;
}

// 移除虚拟连接
void remove_virtual_connection(string userid)
{
    if(!userid) return;
    vconnections[userid] = 0;
}

// 从虚拟连接池获取玩家对象
object get_player_from_connection(string userid, void|int update_idle_time)
{
    if(!userid) return 0;
    mixed vconn = vconnections[userid];
    if(vconn && arrayp(vconn) && sizeof(vconn) >= 3) {
        object player = vconn[2];
        if(player && functionp(player->query_name)) {
            if(update_idle_time != 0) {
                vconn[1] = time();
            }
            return player;
        }
        vconnections[userid] = 0;
    }
    return 0;
}
```

## 相关文件

- `lowlib/system/cmds/login_check.pike` - 登录验证命令
- `gamelib/single/daemons/http_api_daemon.pike` - HTTP API daemon
- `gamelib/single/daemons/_http_api_mod/virtual_conn.pike` - 虚拟连接管理模块
- `lowlib/connd.pike` - 连接管理daemon
- `web/web_vue/` - 新界面Vue应用

## 提交记录

**xiand**:
```
121fe3de0d fix(login): 修复新老界面切换白屏问题
```

## 与 oldtx/tx 的区别

| 特性 | oldtx/tx | xiand |
|------|----------|-------|
| HTTP API daemon | http_api.pike | http_api_daemon.pike |
| 虚拟连接模块 | http_api/virtual_conn.pike | _http_api_mod/virtual_conn.pike |
| 虚拟连接函数 | daemon内定义 | 模块化 #include |
| CONND路径 | pikenv/connd.pike | lowlib/connd.pike |
| 游戏端口 | 5555 | 13800 |
| HTTP端口 | 8888 | 8888 |

## 注意事项

1. **两个reconnect路径都需要修复**: login_check.pike有两个reconnect路径
   - 无用户文件，玩家在内存中
   - 有用户文件，玩家在线

2. **修复后需要重启游戏服务器**才能生效

3. **调试日志**: 修复会写入 `/tmp/xiand_login_debug.log` 用于排查问题
