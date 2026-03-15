/**
 * ========================================================================
 * HTTP API HTML Renderer Module
 * ========================================================================
 *
 * HTML渲染功能：解析MUD输出、生成按钮、处理颜色代码
 *
 * ========================================================================
 */

// 此模块通过主文件的 #include 加载
// 不需要单独 include，所有依赖由主文件提供

// ========================================================================
// 主HTML生成
// ========================================================================

/**
 * 将MUD响应转换为HTML格式 (用于iframe显示)
 */
string response_to_html(string response, string userid, string cmd)
{
    string txd = generate_txd(userid);
    string html = "";
    string area = getenv("GAME_AREA");
    if(!area) area = "tx01";

    // 检查玩家主题
    int use_dark_mode = 0;
    object player = find_player(userid);
    if(player && functionp(player->query_dark_mode) && player->query_dark_mode()) {
        use_dark_mode = 1;
    }

    http_werror(" Theme mode: %s (player=%s)\n", use_dark_mode ? "dark" : "classic", userid || "none");

    // HTML头部
    html += "<!DOCTYPE html>\n<html>\n<head>\n";
    html += "<meta charset=\"UTF-8\">\n";
    html += "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no\">\n";
    html += "<title>天下AI网游 - " + area + "</title>\n";

    // 根据模式选择颜色
    string bg_color, text_color, parent_bg, child_bg, border_color, input_bg, scrollbar_track, scrollbar_thumb;
    string btn_text, link_color, hover_shadow;

    if(use_dark_mode) {
        bg_color = "#1a1a2e";
        text_color = "#e0e0e0";
        parent_bg = "#1a1a2e";
        child_bg = "#1a1a2e";
        border_color = "rgba(255,255,255,0.2)";
        input_bg = "#2a2a4a";
        scrollbar_track = "#2a2a4a";
        scrollbar_thumb = "#4a4a6a";
        btn_text = "#e0e0e0";
        link_color = "#667eea";
        hover_shadow = "rgba(102,126,234,0.4)";
    } else {
        bg_color = "#F5E6D3";
        text_color = "#3d2914";
        parent_bg = "#F5E6D3";
        child_bg = "#F5E6D3";
        border_color = "#8B7765";
        input_bg = "#FFFEF8";
        scrollbar_track = "#E8D9C6";
        scrollbar_thumb = "#C4B5A4";
        btn_text = "#3d2914";
        link_color = "#8B4513";
        hover_shadow = "rgba(139,69,19,0.3)";
    }

    // 内联样式
    html += "<style>\n";
    html += sprintf("html,body{font:Normal 18px \"Noto Sans SC Medium\";background:%s;color:%s;height:100vh;margin:0;padding:0}\n", bg_color, text_color);
    html += sprintf("a{text-decoration:none;margin:1px auto;display:inline-block;padding:4px 8px;border-radius:4px;transition:all 0.2s;color:%s}\n", link_color);
    html += sprintf("a:hover{transform:translateY(-1px);box-shadow:0 2px 8px %s}\n", hover_shadow);
    html += sprintf(".parent{height:calc(100vh - 20px);text-align:center;background:%s;overflow-y:auto;overflow-x:hidden;scroll-behavior:smooth;-webkit-overflow-scrolling:touch;padding-bottom:20px}\n", parent_bg);
    html += ".child{display:inline-block;width:300px;text-align:left;vertical-align:top}\n";
    html += ".parent:before,.parent:after{content:'';display:inline-block;height:100%;vertical-align:top}\n";

    if(use_dark_mode) {
        html += sprintf(".btn{padding:6px 12px;border-radius:6px;border:1px solid %s;background:rgba(102,126,234,0.2);color:%s;font-size:14px;cursor:pointer;margin:2px}\n", border_color, btn_text);
        html += ".btn-outline-info{color:#667eea;border-color:#667eea;background:transparent}\n";
        html += ".btn-outline-success{color:#48bb78;border-color:#48bb78;background:transparent}\n";
        html += ".btn-outline-warning{color:#ed8936;border-color:#ed8936;background:transparent}\n";
        html += ".btn-outline-purple{color:#9f7aea;border-color:#9f7aea;background:transparent}\n";
    } else {
        html += sprintf(".btn{padding:6px 12px;border-radius:6px;border:1px solid %s;background:#E8D9C6;color:%s;font-size:14px;cursor:pointer;margin:2px}\n", border_color, btn_text);
        html += ".btn-outline-info{color:#8B4513;border-color:#8B4513;background:#FFFEF8}\n";
        html += ".btn-outline-success{color:#228B22;border-color:#228B22;background:#FFFEF8}\n";
        html += ".btn-outline-warning{color:#CC5500;border-color:#CC5500;background:#FFFEF8}\n";
        html += ".btn-outline-purple{color:#800080;border-color:#800080;background:#FFFEF8}\n";
    }

    html += ".ink-wash-gradient{background:linear-gradient(90deg,#8B4513,#D2691E,#CD853F,#DEB887,#2F4F4F,#696969);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text;font-weight:bold}\n";
    html += sprintf(".parent::-webkit-scrollbar{width:8px}\n");
    html += sprintf(".parent::-webkit-scrollbar-track{background:%s}\n", scrollbar_track);
    html += sprintf(".parent::-webkit-scrollbar-thumb{background:%s;border-radius:4px}\n", scrollbar_thumb);
    html += ".parent::-webkit-scrollbar-thumb:hover{background:#a0a0b0}\n";
    html += "</style>\n";

    // JavaScript
    html += "<script>\n";
    html += "function submitInput(inputId,txd){var input=document.getElementById(inputId);if(!input)return;var value=encodeURIComponent(input.value);var url='/api/html?txd='+txd+'&cmd='+value;window.location.href=url}\n";
    html += "function submitCmdInput(inputId,hiddenCmd,txd){var input=document.getElementById(inputId);if(!input)return;var value=encodeURIComponent(input.value);var url='/api/html?txd='+txd+'&cmd='+hiddenCmd+' '+value;window.location.href=url}\n";
    // 翻译语言切换函数 - 支持队列机制和postMessage通信
    html += "console.log('[Iframe Debug] Script loaded');window.pendingLanguage=null;window.changeLanguage=function(lang){console.log('[Iframe Debug] changeLanguage called:',lang);if(typeof translate!=='undefined'&&translate.changeLanguage){console.log('[Iframe Debug] Calling translate.changeLanguage');translate.changeLanguage(lang);window.pendingLanguage=null;window.parent.postMessage({type:'changeLanguage',lang:lang},'*')}else{window.pendingLanguage=lang;console.log('[Iframe Debug] Translate not loaded yet, pending:',lang)}};\n";
    // 监听来自父窗口的语言切换消息
    html += "window.addEventListener('message',function(event){if(event.data&&event.data.type==='changeLanguage'){console.log('[Iframe Debug] Received language change from parent:',event.data.lang);window.changeLanguage(event.data.lang)}});\n";
    html += "</script>\n";

    html += "</head>\n<body>\n";
    html += "<div class=\"parent\">\n<div class=\"child\">\n";

    // 解析并转换内容
    html += parse_mud_content_to_html(response, txd, userid);

    html += "</div>\n</div>\n";

    // 翻译插件
    string translate_bg = use_dark_mode ? "#2a2a4a" : "#E8D9C6";
    string translate_border = use_dark_mode ? "rgba(255,255,255,0.1)" : "#8B7765";
    string translate_select_bg = use_dark_mode ? "#1a1a2e" : "#FFFEF8";
    string translate_text = use_dark_mode ? "#e0e0e0" : "#3d2914";

    html += sprintf("<div class='translate-center' style='position:fixed;bottom:0;left:0;right:0;text-align:center;padding:8px;background:%s;border-top:1px solid %s;z-index:999;'>\n", translate_bg, translate_border);
    html += "<div class='translate-wrapper'>\n";
    html += sprintf("<select id='translateLanguageSelect' onchange='changeLanguage(this.value)' style='padding:4px 8px;border:1px solid %s;border-radius:4px;background:%s;color:%s;font-size:11px;'>\n", translate_border, translate_select_bg, translate_text);
    html += "<option value='chinese_simplified'>简体中文</option>\n<option value='chinese_traditional'>繁體中文</option>\n<option value='english'>English</option>\n<option value='japanese'>日本語</option>\n<option value='korean'>한국어</option>\n<option value='french'>Français</option>\n<option value='german'>Deutsch</option>\n<option value='spanish'>Español</option>\n<option value='russian'>Русский</option>\n<option value='portuguese'>Português</option>\n";
    html += "</select>\n</div>\n</div>\n";

    // 加载翻译插件 - 从当前服务器(8888)加载translate.js，避免跨域问题
    html += "<script src='/includes/translate.js'></script>\n"
         + "<script>\n"
         + "console.log('[Iframe Debug] translate.js loaded');\n"
         + "translate.language.setLocal('chinese_simplified');\n"
         + "translate.service.use('client.edge');\n"
         + "translate.setAutoDiscriminateLocalLanguage();\n"
         + "translate.execute();\n"
         + "setTimeout(function(){\n"
         + "var targetLang=window.pendingLanguage||localStorage.getItem('userLanguage');\n"
         + "if(targetLang&&targetLang!=='chinese_simplified'){\n"
         + "console.log('[Iframe Debug] Applying language:',targetLang);\n"
         + "translate.changeLanguage(targetLang);\n"
         + "}\n"
         + "window.pendingLanguage=null;\n"
         + "},100);\n"
         + "</script>\n";

    html += "</body>\n</html>\n";

    return html;
}

// ========================================================================
// MUD内容解析
// ========================================================================

/**
 * 解析MUD原始输出并转换为HTML
 */
string parse_mud_content_to_html(string response, string txd, string userid)
{
    string html = "";
    if(!response) response = "";

    http_werror(" ===== parse_mud_content_to_html START =====\n");
    http_werror(" Response length: %d bytes\n", sizeof(response));

    array lines = response / "\n";
    http_werror(" Total lines: %d\n", sizeof(lines));

    int line_count = 0;
    foreach(lines, string line) {
        string original_line = line;
        line = String.trim_all_whites(line);
        if(!sizeof(line)) {
            html += "<br/>\n";
            continue;
        }

        line_count++;

        // 去掉行尾的{数字}标记
        while(1) {
            int start = search(line, "{");
            if(start == -1) break;
            int end = search(line, "}", start);
            if(end == -1) break;
            string between = line[start+1..end-1];
            int is_all_digits = 1;
            for(int i = 0; i < sizeof(between); i++) {
                if(between[i] < '0' || between[i] > '9') {
                    is_all_digits = 0;
                    break;
                }
            }
            if(is_all_digits) {
                line = line[0..start-1] + line[end+1..];
            } else {
                break;
            }
        }

        if(line_count % 10 == 0) {
            http_werror(" Processing line %d\n", line_count);
        }

        // 检测并处理按钮和输入框
        int has_special = 0;
        array parts = ({});
        int current = 0;

        while(current < sizeof(line)) {
            int start = search(line, "[", current);
            if(start == -1) {
                if(current < sizeof(line)) {
                    parts += ({line[current..]});
                }
                break;
            }
            if(start > current) {
                parts += ({line[current..start-1]});
            }
            int end = search(line, "]", start);
            if(end == -1) {
                parts += ({line[start..]});
                break;
            }
            parts += ({line[start..end]});
            current = end + 1;
            has_special = 1;
        }

        if(has_special) {
            foreach(parts, string part) {
                part = String.trim_all_whites(part);
                if(!sizeof(part)) continue;

                if(has_prefix(part, "[") && has_suffix(part, "]")) {
                    string content = part[1..<1];
                    string var_name, default_val, width, type;

                    // 输入框格式 [类型 变量名:...] 或 [变量名:默认值...宽度]
                    if(sscanf(content, "%s %s:..*%s...*%s", type, var_name, default_val, width) == 4 ||
                       sscanf(content, "%s:..*%s...*%s", var_name, default_val, width) == 3) {
                        html += format_html_input(var_name, default_val, width, txd, userid, (type == "passwd"));
                    }
                    else if(sscanf(content, "%s %s:...", type, var_name) == 2) {
                        int is_passwd = (type == "passwd" || type == "password");
                        html += format_html_input(var_name, "", "", txd, userid, is_passwd);
                    }
                    else if(search(content, ":") > 0 && has_suffix(content, ":...")) {
                        int colon_pos = search(content, ":");
                        string cmd_name = content[0..colon_pos-1];
                        html += format_html_command_input(cmd_name, txd, userid);
                    }
                    else if(has_suffix(content, " ...")) {
                        string cmd_name = content[0..sizeof(content)-5];
                        html += format_html_command_input(cmd_name, txd, userid);
                    }
                    else {
                        int pos = search(content, ":");
                        if(pos > 0) {
                            string label = content[0..pos-1];
                            string action_cmd = content[pos+1..];

                            // URL链接 [url 显示文本:https://...]
                            if(search(label, "url ") == 0 &&
                               (search(action_cmd, "http://") == 0 || search(action_cmd, "https://") == 0)) {
                                string display_text = label[4..];
                                html += sprintf("<a href=\"javascript:void(0)\" onclick=\"window.top.location='%s';return false;\" class=\"btn btn-outline-info btn-sm\">%s</a>",
                                                   action_cmd, format_text(display_text));
                            } else {
                                html += format_html_button(label, action_cmd, txd, userid);
                            }
                        } else {
                            html += format_text(part);
                        }
                    }
                } else {
                    html += format_text(part);
                }
            }
        } else {
            html += format_text(line);
        }
        html += "<br/>\n";
    }

    http_werror(" ===== parse_mud_content_to_html END =====\n");
    return html;
}

// ========================================================================
// 格式化函数
// ========================================================================

/**
 * 格式化文本（处理颜色代码）
 */
string format_text(string text)
{
    string result = "";
    int i = 0;

    while(i < sizeof(text)) {
        // 检查颜色代码 § (0xc2 0xa7 in UTF-8)
        if(i < sizeof(text) - 2 && (text[i] & 0xff) == 0xc2 && (text[i+1] & 0xff) == 0xa7) {
            int color_code = text[i+2] & 0xff;
            string color_html = "";

            switch(color_code) {
                case 0x30: color_html = "<span style='color:#000000'>"; break;
                case 0x31: color_html = "<span style='color:#FF0000;font-weight:bold'>"; break;
                case 0x32: color_html = "<span style='color:#00AA00;font-weight:bold'>"; break;
                case 0x33: color_html = "<span style='color:#0066CC;font-weight:bold'>"; break;
                case 0x34: color_html = "<span style='color:#FFD700;font-weight:bold'>"; break;
                case 0x35: color_html = "<span style='color:#8B00FF;font-weight:bold'>"; break;
                case 0x36: color_html = "<span style='color:#FF8C00;font-weight:bold'>"; break;
                case 0x37: color_html = "<span style='color:#FFFFFF;font-weight:bold'>"; break;
                case 0x38: color_html = "<span style='color:#888888'>"; break;
                case 0x39: color_html = "<span style='color:#003366;font-weight:bold'>"; break;
                case 0x61: color_html = "<span style='color:#90EE90;font-weight:bold'>"; break;  // §a 浅绿
                case 0x62: color_html = "<span style='color:#ADD8E6;font-weight:bold'>"; break;  // §b 浅蓝
                case 0x63: color_html = "<span style='color:#FF6B6B;font-weight:bold'>"; break;  // §c 浅红
                case 0x64: color_html = "<span style='color:#DDA0DD;font-weight:bold'>"; break;  // §d 浅紫
                case 0x65: color_html = "<span style='color:#FFFF00;font-weight:bold'>"; break;  // §e 黄色
                case 0x66: color_html = "<span style='color:#333333;font-weight:bold'>"; break;  // §f 深灰
                case 0x67: color_html = "<span class='ink-wash-gradient' style='font-weight:bold'>"; break;  // §g 水墨
                case 0x72: color_html = "</span>"; break;  // §r 重置
                // 大写字母颜色代码
                case 0x41: color_html = "<span style='color:#00FF00;font-weight:bold'>"; break;  // §A 亮绿
                case 0x42: color_html = "<span style='color:#0099FF;font-weight:bold'>"; break;  // §B 亮蓝
                case 0x43: color_html = "<span style='color:#FF0000;font-weight:bold'>"; break;  // §C 鲜红
                case 0x44: color_html = "<span style='color:#FF1493;font-weight:bold'>"; break;  // §D 深粉
                case 0x45: color_html = "<span style='color:#FFD700;font-weight:bold'>"; break;  // §E 金色
                case 0x46: color_html = "<span style='color:#FFFFFF;font-weight:bold'>"; break;  // §F 纯白
                case 0x52: color_html = "</span>"; break;  // §R 重置（大写）
                case 0x59: color_html = "<span style='color:#FFFF00;font-weight:bold'>"; break;  // §Y 黄色
                default:
                    i += 2;
                    continue;
            }

            result += color_html;
            i += 3;
        }
        else if((text[i] & 0xff) >= 0 && (text[i] & 0xff) < 128) {
            int c = text[i];
            if(c == '\n') {
                result += "<br/>";
            } else if(c == '&') {
                result += "&amp;";
            } else {
                result += sprintf("%c", c);
            }
            i++;
        }
        else {
            // UTF-8多字节字符
            int byte_count = 2;
            int first_byte = text[i] & 0xff;
            if((first_byte & 0xE0) == 0xC0) byte_count = 2;
            else if((first_byte & 0xF0) == 0xE0) byte_count = 3;
            else if((first_byte & 0xF8) == 0xF0) byte_count = 4;

            if(i + byte_count - 1 < sizeof(text)) {
                result += text[i..i+byte_count-1];
                i += byte_count;
            } else {
                result += text[i..];
                i = sizeof(text);
            }
        }
    }

    return result;
}

/**
 * 格式化HTML按钮
 */
string format_html_button(string label, string cmd, string txd, string userid)
{
    string css_class = "btn btn-outline-info btn-sm";

    // 方向按钮
    if(search(label, "东→") != -1 || search(label, "西←") != -1 ||
       search(label, "南↓") != -1 || search(label, "北↑") != -1) {
        css_class = "btn btn-outline-success btn-sm";
    }
    // 特殊功能按钮
    else if(search(label, "杀戮") != -1 || search(label, "商城") != -1 ||
            search(label, "锻造") != -1) {
        css_class = "btn btn-outline-warning btn-sm";
    }
    else if(search(label, "吃药") != -1) {
        css_class = "btn btn-outline-purple btn-sm";
    }
    // 新增境界颜色检测（按优先级从高到低）
    else if(search(label, "大道境-") != -1) {
        css_class = "btn btn-outline-dadao btn-sm";
    }
    else if(search(label, "超凡境-") != -1) {
        css_class = "btn btn-outline-chaofan btn-sm";
    }
    else if(search(label, "大罗境-") != -1) {
        css_class = "btn btn-outline-daluo btn-sm";
    }
    else if(search(label, "混元境-") != -1) {
        css_class = "btn btn-outline-hunyuan btn-sm";
    }
    else if(search(label, "太乙境-") != -1) {
        css_class = "btn btn-outline-taiyi btn-sm";
    }
    else if(search(label, "金仙境-") != -1) {
        css_class = "btn btn-outline-jinxian btn-sm";
    }
    else if(search(label, "天仙境-") != -1) {
        css_class = "btn btn-outline-tianxian btn-sm";
    }
    else if(search(label, "渡劫境-") != -1) {
        css_class = "btn btn-outline-dujie btn-sm";
    }
    else if(search(label, "破虚境-") != -1) {
        css_class = "btn btn-outline-poxu btn-sm";
    }
    else if(search(label, "离三界-高阶-") != -1) {
        css_class = "btn btn-outline-lisan3 btn-sm";
    }
    else if(search(label, "离三界-中阶-") != -1) {
        css_class = "btn btn-outline-lisan2 btn-sm";
    }
    else if(search(label, "离三界-初阶-") != -1) {
        css_class = "btn btn-outline-lisan1 btn-sm";
    }
    else if(search(label, "离三界-") != -1) {
        css_class = "btn btn-outline-lisan1 btn-sm";  // 兼容旧装备
    }
    else if(search(label, "无色界-") != -1) {
        css_class = "btn btn-outline-wuse btn-sm";
    }
    else if(search(label, "色界-") != -1) {
        css_class = "btn btn-outline-sejie btn-sm";
    }
    else if(search(label, "欲界-") != -1) {
        css_class = "btn btn-outline-yujie btn-sm";
    }

    string hidden_cmd = hide_command(userid, cmd);
    string label_formatted = format_text(label);

    return sprintf("<a href=\"/api/html?txd=%s&cmd=%s\" class=\"%s\">%s</a>",
                   txd, hidden_cmd, css_class, label_formatted);
}

/**
 * 格式化HTML输入框
 */
string format_html_input(string name, string default_val, string width, string txd, string userid, int is_passwd)
{
    string size = (sizeof(width) > 0) ? width : "20";
    string value = (sizeof(default_val) > 0) ? default_val : "";
    string input_type = is_passwd ? "password" : "text";

    string input_id = "input_" + name + "_" + (random(9000) + 1000);

    // 检查主题模式
    string border_color, input_bg, text_color;
    int use_dark_mode = 0;
    object player = find_player(userid);
    if(player && functionp(player->query_dark_mode) && player->query_dark_mode()) {
        use_dark_mode = 1;
    }

    if(use_dark_mode) {
        border_color = "#667eea";
        input_bg = "#2a2a4a";
        text_color = "#e0e0e0";
    } else {
        border_color = "#8B7765";
        input_bg = "#FFFEF8";
        text_color = "#3d2914";
    }

    return sprintf("<input type='%s' id='%s' size='%s' value='%s' placeholder='%s' " +
                   "style='padding:4px 8px;border:1px solid %s;border-radius:4px;background:%s;color:%s;' " +
                   "onkeypress='if(event.key==\"Enter\"){submitInput(\"%s\", \"%s\");return false;}'>",
                   input_type, input_id, size, value, name, border_color, input_bg, text_color, input_id, txd);
}

/**
 * 格式化HTML命令输入框（带确定按钮）
 */
string format_html_command_input(string cmd, string txd, string userid)
{
    string input_id = "input_cmd_" + (random(9000) + 1000);
    string hidden_cmd = hide_command(userid, cmd);

    // 检查主题模式
    string border_color, input_bg, text_color, btn_border, btn_bg, btn_text;
    int use_dark_mode = 0;
    object player = find_player(userid);
    if(player && functionp(player->query_dark_mode) && player->query_dark_mode()) {
        use_dark_mode = 1;
    }

    if(use_dark_mode) {
        border_color = "#667eea";
        input_bg = "#2a2a4a";
        text_color = "#e0e0e0";
        btn_border = "#48bb78";
        btn_bg = "#48bb78";
        btn_text = "#fff";
    } else {
        border_color = "#8B7765";
        input_bg = "#FFFEF8";
        text_color = "#3d2914";
        btn_border = "#228B22";
        btn_bg = "#228B22";
        btn_text = "#fff";
    }

    return sprintf("<input type='text' id='%s' placeholder='输入参数...' " +
                   "style='padding:4px 8px;border:1px solid %s;border-radius:4px;background:%s;color:%s;width:120px;' " +
                   "onkeypress='if(event.key==\"Enter\"){submitCmdInput(\"%s\", \"%s\", \"%s\");return false;}'> " +
                   "<a href=\"#\" onclick='submitCmdInput(\"%s\", \"%s\", \"%s\");return false;' " +
                   "style='padding:4px 12px;border:1px solid %s;border-radius:4px;background:%s;color:%s;text-decoration:none;'>确定</a>",
                   input_id, border_color, input_bg, text_color, input_id, hidden_cmd, txd,
                   input_id, hidden_cmd, txd, btn_border, btn_bg, btn_text);
}

// ========================================================================
// 聊天消息清理
// ========================================================================

/**
 * 清理聊天消息格式
 * 原始格式: (时间)[中文名:ui_char userid]：消息
 * 输出格式: (时间)中文名: 消息
 */
string clean_chat_message(string raw_msg)
{
    if(!raw_msg || sizeof(raw_msg) == 0) {
        return "";
    }

    int bracket_start = search(raw_msg, "[");
    int bracket_end = search(raw_msg, "]");

    string time_part = "";
    string name_part = "";
    string content_part = "";

    if(bracket_start != -1 && bracket_end != -1 && bracket_end > bracket_start) {
        if(bracket_start > 0) {
            time_part = raw_msg[0..bracket_start - 1];
        }

        string bracket_content = raw_msg[bracket_start + 1..bracket_end - 1];
        int colon_pos = search(bracket_content, ":");
        if(colon_pos != -1) {
            name_part = bracket_content[0..colon_pos - 1];
        }

        if(bracket_end < sizeof(raw_msg) - 1) {
            content_part = raw_msg[bracket_end + 1..];
            if(sizeof(content_part) > 0 && (content_part[0] == ':' || content_part[0] == '：')) {
                content_part = content_part[1..];
            }
            content_part = String.trim_all_whites(content_part);
        }
    }

    string result = "";
    if(sizeof(time_part) > 0) {
        result += time_part;
    }
    if(sizeof(name_part) > 0) {
        result += name_part;
    }
    if(sizeof(content_part) > 0) {
        result += ": " + content_part;
    }

    return sizeof(result) > 0 ? result : raw_msg;
}

// ========================================================================
// JSON响应解析
// ========================================================================

/**
 * 解析MUD响应为JSON
 */
mapping parse_response_to_json(string response, string userid)
{
    mapping result = ([ ]);
    result["timestamp"] = time();
    result["messages"] = ({});
    result["actions"] = ({});
    result["navigation"] = ([ "exits": ({}) ]);

    if(!response) response = "";

    response = remove_ansi_colors(response);
    array lines = response / "\n";

    foreach(lines, string line) {
        line = strip_wapmud_color_codes(line);
        line = String.trim_all_whites(line);
        if(!sizeof(line)) continue;

        // 检测按钮
        int has_button = 0;
        array parts = ({});
        int current = 0;
        while(current < sizeof(line)) {
            int start = search(line, "[", current);
            if(start == -1) {
                if(current < sizeof(line)) {
                    parts += ({line[current..]});
                }
                break;
            }
            if(start > current) {
                parts += ({line[current..start-1]});
            }
            int end = search(line, "]", start);
            if(end == -1) {
                parts += ({line[start..]});
                break;
            }
            parts += ({line[start..end]});
            current = end + 1;
            has_button = 1;
        }

        if(has_button) {
            foreach(parts, string part) {
                part = String.trim_all_whites(part);
                if(!sizeof(part)) continue;

                if(has_prefix(part, "[") && has_suffix(part, "]")) {
                    string content = part[1..<1];
                    int pos = search(content, ":");
                    if(pos > 0) {
                        string label = content[0..pos-1];
                        string action_cmd = content[pos+1..];

                        if(is_direction(label)) {
                            mapping exit = ([ ]);
                            exit["direction"] = label;
                            exit["label"] = label;
                            exit["command"] = action_cmd;
                            result["navigation"]["exits"] += ({exit});
                        } else {
                            mapping action = ([ ]);
                            action["label"] = label;
                            action["command"] = action_cmd;
                            action["style"] = get_action_style(label);
                            result["actions"] += ({action});
                        }
                    }
                } else if(sizeof(part) > 0) {
                    mapping msg = ([ ]);
                    msg["type"] = get_message_type(part);
                    msg["text"] = part;
                    msg["timestamp"] = time();
                    result["messages"] += ({msg});
                }
            }
        } else {
            mapping msg = ([ ]);
            msg["type"] = get_message_type(line);
            msg["text"] = line;
            msg["timestamp"] = time();
            result["messages"] += ({msg});
        }
    }

    object player = find_player(userid);
    if(player) {
        result["player"] = query_player_state(player);
    }

    return result;
}

/**
 * 查询玩家状态 (完全按照原始逻辑)
 */
mapping query_player_state(object player)
{
    if(!player) return 0;

    mapping result = ([ ]);

    // 玩家中文名
    string name_cn = "";
    if(functionp(player->query_name_cn)) {
        name_cn = player->query_name_cn();
    } else if(player->name_cn) {
        name_cn = player->name_cn;
    }
    result["name_cn"] = name_cn || "";

    // 自动战斗状态
    int autofight = 0;
    if(functionp(player->query_autofight)) {
        string af = player->query_autofight();
        autofight = (af == "enable") ? 1 : 0;
    }
    result["autofight"] = autofight;

    // 生命 HP
    int jing = player->jing;
    int jing_max = player->jing_max;
    result["hp"] = jing;
    result["hp_max"] = jing_max;

    // 精神 Spirit
    int shen = player->shen;
    int shen_max = player->shen_max;
    result["spirit"] = shen;
    result["spirit_max"] = shen_max;

    // 潜能 Potential
    int potential = player->potential;
    int limit_pot = player->query_limit_pot();
    result["potential"] = potential;
    result["potential_max"] = limit_pot;

    // 修为 Cultivation (中文显示)
    string daoheng_cn = "";
    if(functionp(player->daoheng_cn)) {
        daoheng_cn = player->daoheng_cn();
    } else if(player->daoheng_cn) {
        daoheng_cn = player->daoheng_cn;
    }
    result["cultivation"] = daoheng_cn || "未知";

    // 内力 Neili
    int qi = player->qi;
    int qi_max = player->query_qi_maxnum();
    result["neili"] = qi;
    result["neili_max"] = qi_max;

    return result;
}
