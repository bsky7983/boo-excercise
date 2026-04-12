// app/src/server.js
require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const bodyParser = require('body-parser');
const path = require('path');
const app = express();
const PORT = process.env.PORT || 3000;
// MongoDB 연결 (환경변수에서 URL 읽기)
const MONGODB_URI = process.env.MONGODB_URI ||
'mongodb://todouser:TodoPass2024!@localhost:27017/todoapp';
mongoose.connect(MONGODB_URI)
.then(() => console.log('MongoDB 연결 성공!'))
.catch(err => console.error('MongoDB 연결 실패:', err));
// Todo 스키마 정의
const todoSchema = new mongoose.Schema({
title: { type: String, required: true },
completed: { type: Boolean, default: false },
createdAt: { type: Date, default: Date.now }
});
const Todo = mongoose.model('Todo', todoSchema);
// 미들웨어 설정
app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));
// 라우트 - 메인 페이지
app.get('/', async (req, res) => {
const todos = await Todo.find().sort({ createdAt: -1 });
res.render('index', { todos });
});
// 라우트 - Todo 추가
app.post('/todos', async (req, res) => {
const todo = new Todo({ title: req.body.title });
await todo.save();
res.redirect('/');
});
// 라우트 - Todo 완료 토글
app.post('/todos/:id/toggle', async (req, res) => {
const todo = await Todo.findById(req.params.id);
todo.completed = !todo.completed;
await todo.save();
res.redirect('/');
});
// 라우트 - Todo 삭제
app.delete('/todos/:id', async (req, res) => {
await Todo.findByIdAndDelete(req.params.id);
res.json({ success: true });
});
// Health check
app.get('/health', (req, res) => {
res.json({ status: 'ok', mongodb: mongoose.connection.readyState });
});
app.listen(PORT, () => {
console.log(`서버 실행 중: http://localhost:${PORT}`);
});
