# 4-2-ec2app

EC2デプロイのFastAPI + GitHub Actions CD

---

## 目的

ECSってデプロイが楽だよね、を実感する
EC2のデプロイを経験することで
ECSのありがたさがわかる！
ECSとの違い
├─ EC2はサーバーの管理が必要
├─ デプロイはSSH経由でファイルをコピー
├─ サービス再起動時にダウンタイムが発生
└─ スケールアップが大変


---

## 構成図

インターネット
↓
CloudFront（HTTPS・CDN）
↓
ALB（ロードバランサー）
↓
EC2（FastAPI + uvicorn）
↓
RDS MySQL（データベース）

---

## ECSとEC2のデプロイ比較

| 項目 | ECS | EC2 |
|------|-----|-----|
| デプロイ方法 | Dockerビルド → ECR push → タスク更新 | SSH → ファイルコピー → サービス再起動 |
| ダウンタイム | なし | 再起動時に発生 |
| サーバー管理 | 不要 | 必要（OSアップデート等） |
| スケールアップ | 簡単 | 大変 |
| コスト | やや高い | やや安い |
| 難易度 | 中 | 低〜中 |

---

## 使用技術

### アプリケーション
| 技術 | 用途 |
|------|------|
| Python + FastAPI | REST APIサーバー |
| SQLAlchemy | DBの操作（ORM） |
| uvicorn | ASGIサーバー |
| systemd | サービス管理・自動起動 |

### AWS インフラ
| サービス | 役割 |
|---------|------|
| EC2 | アプリケーションサーバー |
| RDS MySQL | データベース |
| ALB | ロードバランサー |
| CloudFront | CDN・HTTPS化 |

### ツール
| ツール | 用途 |
|--------|------|
| Terraform | インフラのコード管理（IaC） |
| GitHub Actions | 自動デプロイ（CD） |

---

## ファイル構成

4-2-ec2app/
├── backend/
│   ├── app/
│   │   ├── main.py          → アプリの入口
│   │   ├── database.py      → DB接続設定
│   │   ├── models.py        → DBテーブル定義
│   │   ├── schemas.py       → APIの入出力
│   │   └── routers/
│   │       └── items.py     → 商品APIエンドポイント
│   └── requirements.txt
└── infra/
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars     → gitignore済み
└── modules/
├── network/         → VPC・サブネット・IGW
├── security/        → セキュリティグループ
├── rds/             → データベース
├── ec2/             → EC2インスタンス・systemd設定
├── alb/             → ロードバランサー
└── cloudfront/      → CDN

---

## EC2とECSのセキュリティグループの違い

ECS（前回）
target_type = "ip"
└─ コンテナのIPアドレスを指定
└─ ポート80
EC2（今回）
target_type = "instance"
└─ EC2のインスタンスIDを指定
└─ ポート8000（uvicornが直接リッスン）

---

## systemdの設定

```ini
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
```

systemdとは？
└─ Linuxのサービス管理システム
設定の解説
├─ WorkingDirectory=/app  → 実行ディレクトリ
├─ EnvironmentFile=/app/.env → 環境変数の読み込み
├─ ExecStart → 実行するコマンド
├─ Restart=always → クラッシュしたら自動再起動
└─ WantedBy=multi-user.target → サーバー起動時に自動起動

---

## GitHub ActionsのCD設定

```yaml
# デプロイの流れ
1. backend/**が変更されたらワークフロー起動
2. SCPでEC2にファイルをコピー
3. SSHでsystemctlを再起動
4. ALBのヘルスチェックで動作確認
```

必要なSecrets
├─ AWS_ACCESS_KEY_ID     → AWSのアクセスキー
├─ AWS_SECRET_ACCESS_KEY → AWSのシークレットキー
├─ EC2_HOST              → EC2のパブリックIP
├─ EC2_USER              → ec2-user
└─ EC2_SSH_KEY           → SSHの秘密鍵（PEM形式）

---

## 環境の構築手順

### Step1: キーペアの作成

```bash
aws ec2 create-key-pair \
  --key-name ec2app-key \
  --query "KeyMaterial" \
  --output text \
  --region ap-northeast-1 > ~/.ssh/ec2app-key.pem

chmod 400 ~/.ssh/ec2app-key.pem
```

### Step2: terraform.tfvarsを作成

```bash
cat > infra/terraform.tfvars << 'EOF'
aws_region           = "ap-northeast-1"
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
db_subnet_cidrs      = ["10.0.5.0/24", "10.0.6.0/24"]
db_name              = "ec2appdb"
db_username          = "admin"
db_password          = "Password1234!"
ec2_instance_type    = "t3.micro"
key_name             = "ec2app-key"
EOF
```

### Step3: インフラを構築

```bash
cd infra
terraform init
terraform apply
```

### Step4: EC2にライブラリをインストール

```bash
ssh -i ~/.ssh/ec2app-key.pem ec2-user@<EC2_PUBLIC_IP>

sudo pip3 install fastapi uvicorn sqlalchemy pymysql \
  pydantic cryptography python-dotenv
```

### Step5: コードをEC2にコピー

```bash
# EC2内でディレクトリの権限を設定
sudo mkdir -p /app/app
sudo chown -R ec2-user:ec2-user /app

# ローカルからコードをコピー
scp -i ~/.ssh/ec2app-key.pem -r \
  backend/app/ \
  ec2-user@<EC2_PUBLIC_IP>:/app/app/
```

### Step6: 環境変数を設定してFastAPIを起動

```bash
echo "DATABASE_URL=mysql+pymysql://admin:PASSWORD@RDS_ENDPOINT:3306/ec2appdb" > /app/.env
sudo systemctl restart fastapi
sudo systemctl status fastapi
```

### Step7: RDSにmigration

```bash
python3 << 'EOF'
from sqlalchemy import create_engine, Column, Integer, String, Text, DateTime
from sqlalchemy.orm import declarative_base
from sqlalchemy.sql import func

DATABASE_URL = "mysql+pymysql://admin:PASSWORD@RDS_ENDPOINT:3306/ec2appdb"
engine = create_engine(DATABASE_URL)
Base = declarative_base()

class Item(Base):
    __tablename__ = "items"
    id = Column(Integer, primary_key=True)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    price = Column(Integer, nullable=False)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now())

Base.metadata.create_all(bind=engine)
print("Migration completed!")
EOF
```

---

## トラブルシューティング

### Python3.7の互換性エラー

TypeError: 'type' object is not subscriptable
原因
└─ Amazon Linux 2はPython3.7
└─ list[str]という書き方はPython3.9以降
解決方法
from typing import List
list[schemas.ItemResponse] → List[schemas.ItemResponse]

### ポートが使用中エラー

[Errno 98] address already in use
解決方法
sudo pkill -f uvicorn
sudo systemctl restart fastapi

### systemdが起動しない場合

```bash
# ログを確認
sudo journalctl -u fastapi -n 50 --no-pager

# 直接実行して確認
cd /app && /usr/bin/python3 -m uvicorn app.main:app \
  --host 0.0.0.0 --port 8000
```

---

## 環境の削除手順

```bash
cd infra
terraform destroy
```

> ⚠️ キーペアはTerraformで管理していないので別途削除：
> ```bash
> aws ec2 delete-key-pair --key-name ec2app-key --region ap-northeast-1
> rm ~/.ssh/ec2app-key.pem
> ```

