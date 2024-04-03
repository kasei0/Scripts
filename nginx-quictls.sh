#!/bin/bash

# Exit on errors
set -e

# Update and install dependencies
apt update
apt install -y build-essential ca-certificates zlib1g-dev libpcre3 libpcre3-dev tar unzip libssl-dev wget curl git cmake ninja-build mercurial libunwind-dev pkg-config libjemalloc-dev

# Install Go
#wget https://dl.google.com/go/go1.22.1.linux-amd64.tar.gz
#rm -rf /usr/local/go && tar -C /usr/local -xzf go1.22.1.linux-amd64.tar.gz
#export PATH=$PATH:/usr/local/go/bin

# Verify Go installation
#go version

# Compile  QuicTLS
cd /usr/local/src
wget https://github.com/quictls/openssl/archive/refs/tags/openssl-3.1.5-quic1.tar.gz
tar -xzf openssl-3.1.5-quic1.tar.gz 
cd openssl-openssl-3.1.5-quic1
./config --prefix=$(pwd)/build no-shared
make
make install_sw

# Install Brotli compression
cd /usr/local/src
git clone --recurse-submodules -j8 https://github.com/google/ngx_brotli
cd ngx_brotli/deps/brotli
mkdir out && cd out
cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_FLAGS="-Ofast -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_CXX_FLAGS="-Ofast -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_INSTALL_PREFIX=./installed ..
cmake --build . --config Release --target brotlienc

# Clone Nginx and configure with  QuicTLS and Brotli
cd /usr/local/src
hg clone https://hg.nginx.org/nginx
cd nginx
./auto/configure --user=www --group=www --prefix=/www/nginx --with-pcre-jit  --add-module=/usr/local/src/ngx_brotli --with-http_v2_module --with-stream --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module --with-http_ssl_module --with-http_gzip_static_module --with-http_auth_request_module --with-http_stub_status_module --with-http_gunzip_module --with-http_sub_module --with-http_flv_module --with-http_addition_module --with-http_realip_module --with-threads --with-http_slice_module --with-http_random_index_module --with-http_secure_link_module --with-http_mp4_module --with-ld-opt=-Wl,-E --with-cc-opt=-Wno-error --with-ld-opt=-ljemalloc --with-http_dav_module --with-http_v3_module  --with-cc-opt="-I../openssl-openssl-3.1.5-quic1/build/include" --with-ld-opt="-L../openssl-openssl-3.1.5-quic1/build/lib64" --add-module=/usr/local/src/njs/nginx
make
make install

# Add Nginx user and group
groupadd -f www
useradd -g www -s /sbin/nologin www || true

ln -s /etc/local/src/nginx/sbin/nginx /usr/sbin/nginx
ln -s /www/nginx/sbin/nginx /usr/sbin/nginx

# Create systemd service file for Nginx
cat <<EOF > /usr/lib/systemd/system/nginx.service
[Unit]
Description=A high performance web server and a reverse proxy server
After=network.target nss-lookup.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t -q -g 'daemon on; master_process on;'
ExecStart=/usr/sbin/nginx -g 'daemon on; master_process on;'
ExecReload=/usr/sbin/nginx -g 'daemon on; master_process on;' -s reload
ExecStop=-/sbin/start-stop-daemon --quiet --stop --retry QUIT/5 --pidfile /run/nginx.pid
TimeoutStopSec=5
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd daemon and enable Nginx service
systemctl daemon-reload
systemctl enable nginx.service

echo "Nginx installed and service created. Use 'systemctl start nginx' to start Nginx."
