# EC2インスタンス
resource "aws_instance" "app" {
  ami                    = "ami-01d413d3f44ff987f"
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.ec2_sg_id]
  key_name               = var.key_name

  user_data = <<-EOF
    #!/bin/bash
    # システムアップデート
    yum update -y

    # Python3とpipをインストール
    yum install -y python3 python3-pip git

    # アプリ用ディレクトリを作成
    mkdir -p /app
    cd /app

    # 環境変数ファイルを作成
    echo "DATABASE_URL=${var.database_url}" > /app/.env

    # requirements.txtを作成
    cat > /app/requirements.txt << 'REQUIREMENTS'
fastapi==0.111.0
uvicorn==0.29.0
sqlalchemy==2.0.30
pymysql==1.1.1
pydantic==2.7.1
cryptography==42.0.7
python-dotenv==1.0.0
REQUIREMENTS

    # ライブラリをインストール
    pip3 install -r /app/requirements.txt

    # systemdサービスファイルを作成
    cat > /etc/systemd/system/fastapi.service << 'SERVICE'
[Unit]
Description=FastAPI Application
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/app
EnvironmentFile=/app/.env
ExecStart=/usr/bin/python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SERVICE

    # systemdを有効化
    systemctl daemon-reload
    systemctl enable fastapi
  EOF

  tags = { Name = "ec2app-server" }
}