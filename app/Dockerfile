# app/Dockerfile
FROM node:18-alpine

WORKDIR /app

# package.json 복사 및 의존성 설치
COPY package*.json ./
RUN npm install --production

# 애플리케이션 코드 복사
COPY src/ ./src/

# ★★★ 중요: booexercise.txt 파일 생성 (면접 요구사항) ★★★
# 본인 이름으로 변경하세요!
RUN echo "sunghyun.boo - BOO Security Exercise" > /app/wizexercise.txt

EXPOSE 3000

CMD ["node", "src/server.js"]
