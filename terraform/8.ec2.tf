# terraform/ec2.tf
# 키 페어 생성 (SSH 접속용)
resource "aws_key_pair" "mongodb" {
  key_name   = "${var.project_name}-key"
# public_key = file("~/.ssh/id_rsa.pub")
  public_key = "${var.ssh_public_key}"  # file() 대신 변수로 받음
}

# Ubuntu 20.04 (1년 이상 오래된 버전) AMI 조회
data "aws_ami" "ubuntu_old" {
  most_recent = false
  owners      = ["099720109477"] # Canonical (Ubuntu 공식)
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-20250603"]
  }
}

resource "aws_instance" "mongodb" {
  ami                    = data.aws_ami.ubuntu_old.id
  instance_type          = "t3.medium"
  key_name               = aws_key_pair.mongodb.key_name
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.mongodb_vm.id]
  iam_instance_profile   = aws_iam_instance_profile.mongodb_vm.name

# MongoDB 자동 설치 스크립트
  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    # MongoDB 5.0 설치 (오래된 버전 - 의도적 취약점)
    wget -qO - https://www.mongodb.org/static/pgp/server-5.0.asc | apt-key add -
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/5.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-5.0.list
    apt-get update
    apt-get install -y mongodb-org=5.0.14 mongodb-org-server=5.0.14

    # MongoDB 설정 - auth 활성화, 외부 바인딩
    cat > /etc/mongod.conf << 'MONGOCFG'
    storage:
      dbPath: /var/lib/mongodb
    net:
      port: 27017
      bindIp: 0.0.0.0
    MONGOCFG

    systemctl start mongod
    systemctl enable mongod
    sleep 10

    # 사용자 생성
    #mongosh admin --eval "db.createUser({user: 'admin', pwd: 'BooExercise2024', roles: [{role: 'root', db: 'admin'}]})"
    mongosh admin --eval "
      // 관리자 생성
      db.createUser({
        user: 'admin',
        pwd: 'BooExercise2024',
        roles: [{role: 'root', db: 'admin'}]
      });

      // todouser 및 초기 데이터 생성
      var todoDB = db.getSiblingDB('todoapp');
      todoDB.createUser({
        user: 'todouser',
        pwd: 'TodoPass2024!',
        roles: [{ role: 'readWrite', db: 'todoapp' }]
      });

      todoDB.todos.insertOne({
        title: 'Setup BOO Exercise',
        completed: false,
        createdAt: new Date()
      });
    "

    #인증 기능을 켜고 재시작
    cat >> /etc/mongod.conf << 'AUTHCFG'
    security:
      authorization: enabled
    AUTHCFG

    systemctl restart mongod

    # 백업 스크립트 설정
    cat > /usr/local/bin/mongodb_backup.sh << 'BACKUP'
    #!/bin/bash
    DATE=$(date +%Y%m%d_%H%M%S)
    BUCKET=${aws_s3_bucket.mongodb_backup.bucket}
    mongodump --uri="mongodb://admin:${var.mongodb_password}@localhost:27017/admin" --out=/tmp/backup_$DATE
    aws s3 sync /tmp/backup_$DATE s3://$BUCKET/backups/$DATE/
    rm -rf /tmp/backup_$DATE
    BACKUP
    chmod +x /usr/local/bin/mongodb_backup.sh

    # 매일 자정 자동 백업 크론 설정
    echo "0 0 * * * root /usr/local/bin/mongodb_backup.sh >> /var/log/mongodb_backup.log 2>&1" >> /etc/crontab
  EOF

  tags = {
    Name = "${var.project_name}-mongodb"
  }
}
