管理员您好：

目标：在 Caddy 的站点 kunkka.spailab.com 内增加子路径反代，把 https://kunkka.spailab.com/option-learner-guide 转发到 127.0.0.1:3101（需保留前缀，不要使用 handle_path）。

建议变更：
1) 备份 Caddyfile
2) 检测 kunkka.spailab.com 站点块是否存在：
   - 如存在：在该站点块内加入以下片段（放在 '}' 闭合前）：
        handle /option-learner-guide* {
            reverse_proxy 127.0.0.1:3101 {
                header_up Host {host}
                transport http {
                    read_timeout 3600s
                    write_timeout 3600s
                    dial_timeout 10s
                    keepalive 64
                }
            }
        }
   - 如不存在：新增站点块：
        kunkka.spailab.com {
            encode zstd gzip
            handle /option-learner-guide* {
                reverse_proxy 127.0.0.1:3101 {
                    header_up Host {host}
                    transport http {
                        read_timeout 3600s
                        write_timeout 3600s
                        dial_timeout 10s
                        keepalive 64
                    }
                }
            }
        }
3) 验证并重载：
   caddy validate --config /etc/caddy/Caddyfile
   systemctl reload caddy

回归验证（应返回 200）：
   curl -I https://kunkka.spailab.com/option-learner-guide
   curl -s https://kunkka.spailab.com/option-learner-guide/api/teaching | head -5
   timeout 6 curl -Ns https://kunkka.spailab.com/option-learner-guide/api/stream | head -1
