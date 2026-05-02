import express from "express";
import { promises as fs } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { eventData } from "../src/event.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dataDir = path.join(__dirname, "data");
const dataFile = path.join(dataDir, "questions.json");
const app = express();
const port = process.env.PORT || 4174;

const event = eventData;

app.use(express.json({ limit: "1mb" }));

async function readQuestions() {
  try {
    const raw = await fs.readFile(dataFile, "utf8");
    return JSON.parse(raw);
  } catch (error) {
    if (error.code === "ENOENT") return [];
    throw error;
  }
}

async function writeQuestions(questions) {
  await fs.mkdir(dataDir, { recursive: true });
  await fs.writeFile(dataFile, JSON.stringify(questions, null, 2));
}

app.get("/api/event", (_req, res) => {
  res.json(event);
});

app.get("/api/questions", async (_req, res, next) => {
  try {
    res.json(await readQuestions());
  } catch (error) {
    next(error);
  }
});

app.post("/api/questions", async (req, res, next) => {
  try {
    const { sessionId, name, question, tags = [], contact = "" } = req.body;
    if (!event.sessions.some((session) => session.id === sessionId)) {
      return res.status(400).json({ error: "Choose a valid session." });
    }
    if (!question || question.trim().length < 8) {
      return res.status(400).json({ error: "Question must be at least 8 characters." });
    }

    const questions = await readQuestions();
    const now = new Date().toISOString();
    const item = {
      id: crypto.randomUUID(),
      sessionId,
      name: name?.trim() || "Anonymous",
      contact: contact.trim(),
      question: question.trim(),
      tags: tags.slice(0, 4),
      status: "new",
      answer: "",
      note: "",
      pinned: false,
      createdAt: now,
      updatedAt: now
    };
    questions.unshift(item);
    await writeQuestions(questions);
    res.status(201).json(item);
  } catch (error) {
    next(error);
  }
});

app.patch("/api/questions/:id", async (req, res, next) => {
  try {
    const questions = await readQuestions();
    const index = questions.findIndex((question) => question.id === req.params.id);
    if (index === -1) return res.status(404).json({ error: "Question not found." });
    questions[index] = {
      ...questions[index],
      ...req.body,
      id: questions[index].id,
      updatedAt: new Date().toISOString()
    };
    await writeQuestions(questions);
    res.json(questions[index]);
  } catch (error) {
    next(error);
  }
});

app.delete("/api/questions/:id", async (req, res, next) => {
  try {
    const questions = await readQuestions();
    const nextQuestions = questions.filter((question) => question.id !== req.params.id);
    await writeQuestions(nextQuestions);
    res.status(204).end();
  } catch (error) {
    next(error);
  }
});

app.use((_req, res) => {
  res.status(404).json({ error: "Not found." });
});

app.listen(port, "0.0.0.0", () => {
  console.log(`Question API listening on http://localhost:${port}`);
});
