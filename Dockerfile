FROM php:8.2-fpm

WORKDIR /var/www

# 安装 nginx 及常用工具
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    nginx \
    && rm -rf /var/lib/apt/lists/*

# 安装 PHP MySQL 扩展
RUN docker-php-ext-install mysqli pdo pdo_mysql

# 写入完整 nginx 配置（含 nginx.txt 里的 rewrite 规则）
RUN cat > /etc/nginx/sites-enabled/default <<'NGINX_EOF'
server {
    listen 8080;
    server_name _;
    root /var/www;
    index index.php index.html;

    # 屏蔽插件和 includes 目录的直接访问
    location ^~ /plugins {
        deny all;
    }
    location ^~ /includes {
        deny all;
    }

    location / {
        if (!-e $request_filename) {
            rewrite ^/(.[a-zA-Z0-9\-\_]+)\.html$ /index.php?mod=$1 last;
        }
        rewrite ^/pay/(.*)$ /pay.php?s=$1 last;
        rewrite ^/api/(.*)$ /api.php?s=$1 last;
        rewrite ^/doc/(.[a-zA-Z0-9\-\_]+)\.html$ /index.php?doc=$1 last;
        try_files $uri $uri/ /index.php$is_args$args;
    }

    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.*)$;
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT $realpath_root;
    }

    # 关闭访问日志，减少容器内 I/O
    access_log off;
    error_log /dev/stderr warn;
}
NGINX_EOF

COPY . /var/www

RUN chown -R www-data:www-data /var/www

EXPOSE 8080

CMD ["sh", "-c", "php-fpm -D && nginx -g 'daemon off;'"]
