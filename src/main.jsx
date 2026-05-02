import React, { useEffect, useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import QRCode from "qrcode";
import {
  Archive,
  CalendarDays,
  CheckCircle2,
  Clipboard,
  Download,
  ExternalLink,
  Eye,
  MessageSquarePlus,
  Monitor,
  PencilLine,
  Pin,
  PinOff,
  Search,
  Send,
  Sparkles,
  Smartphone,
  Star,
  Trash2
} from "lucide-react";
import { eventData } from "./event.js";
import "./styles.css";

const TAGS = ["Platforms", "Claude", "Codex", "MCP", "Gramene", "Agent setup", "Demos", "Multi-agent"];
const STATUS = {
  new: { label: "New", icon: Star },
  followup: { label: "Answer later", icon: Archive },
  answered: { label: "Answered", icon: CheckCircle2 }
};
const STORAGE_KEY = "ai-ready-lab-hackathon-questions";

function readStoredQuestions() {
  try {
    return JSON.parse(window.localStorage.getItem(STORAGE_KEY) || "[]");
  } catch {
    return [];
  }
}

function writeStoredQuestions(questions) {
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(questions));
}

function useApi() {
  const [event, setEvent] = useState(eventData);
  const [questions, setQuestions] = useState([]);
  const [error, setError] = useState("");
  const [staticMode, setStaticMode] = useState(false);

  async function load() {
    try {
      const [eventResponse, questionResponse] = await Promise.all([
        fetch("/api/event"),
        fetch("/api/questions")
      ]);
      setEvent(await eventResponse.json());
      setQuestions(await questionResponse.json());
      setError("");
      setStaticMode(false);
    } catch {
      setEvent(eventData);
      setQuestions(readStoredQuestions());
      setStaticMode(true);
      setError("Hosted hub mode: responses are saved in this browser. For a shared live room hub, run the local server and share its QR code.");
    }
  }

  useEffect(() => {
    load();
    const timer = window.setInterval(load, 3500);
    return () => window.clearInterval(timer);
  }, []);

  async function createQuestion(payload) {
    if (staticMode) {
      const now = new Date().toISOString();
      const item = {
        id: crypto.randomUUID(),
        sessionId: payload.sessionId,
        name: payload.name?.trim() || "Anonymous",
        contact: payload.contact?.trim() || "",
        question: payload.question.trim(),
        tags: payload.tags.slice(0, 4),
        status: "new",
        answer: "",
        note: "",
        pinned: false,
        createdAt: now,
        updatedAt: now
      };
      if (item.question.length < 8) throw new Error("Question must be at least 8 characters.");
      const nextQuestions = [item, ...questions];
      writeStoredQuestions(nextQuestions);
      setQuestions(nextQuestions);
      return item;
    }
    const response = await fetch("/api/questions", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    });
    const body = await response.json();
    if (!response.ok) throw new Error(body.error || "Could not submit question.");
    setQuestions((items) => [body, ...items]);
    return body;
  }

  async function updateQuestion(id, patch) {
    if (staticMode) {
      const nextQuestions = questions.map((item) => (
        item.id === id ? { ...item, ...patch, updatedAt: new Date().toISOString() } : item
      ));
      writeStoredQuestions(nextQuestions);
      const updated = nextQuestions.find((item) => item.id === id);
      setQuestions(nextQuestions);
      return updated;
    }
    const response = await fetch(`/api/questions/${id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(patch)
    });
    const body = await response.json();
    if (!response.ok) throw new Error(body.error || "Could not update question.");
    setQuestions((items) => items.map((item) => (item.id === id ? body : item)));
    return body;
  }

  async function deleteQuestion(id) {
    if (staticMode) {
      const nextQuestions = questions.filter((item) => item.id !== id);
      writeStoredQuestions(nextQuestions);
      setQuestions(nextQuestions);
      return;
    }
    await fetch(`/api/questions/${id}`, { method: "DELETE" });
    setQuestions((items) => items.filter((item) => item.id !== id));
  }

  return { event, questions, error, staticMode, createQuestion, updateQuestion, deleteQuestion, reload: load };
}

function App() {
  const api = useApi();
  const params = new URLSearchParams(window.location.search);
  const initialView = params.get("view") === "ask" ? "ask" : "presenter";
  const [view, setView] = useState(initialView);
  const [sessionId, setSessionId] = useState(params.get("session") || "session-1");

  if (!api.event) {
    return <main className="loading">Opening question hub...</main>;
  }

  return (
    <main className="app-shell">
      <header className="topbar">
        <div>
          <p className="code">{api.event.code}</p>
          <h1>{api.event.title}</h1>
          <p className="event-meta">{api.event.date} · {api.event.time}</p>
        </div>
        <div className="view-switch" role="tablist" aria-label="View">
          <button className={view === "ask" ? "active" : ""} onClick={() => setView("ask")}>
            <Smartphone size={16} /> Audience
          </button>
          <button className={view === "presenter" ? "active" : ""} onClick={() => setView("presenter")}>
            <Monitor size={16} /> Presenter
          </button>
        </div>
      </header>

      {api.error && <div className="banner">{api.error}</div>}

      <SessionTabs event={api.event} sessionId={sessionId} setSessionId={setSessionId} />

      {view === "ask" ? (
        <AudienceView event={api.event} sessionId={sessionId} setSessionId={setSessionId} createQuestion={api.createQuestion} />
      ) : (
        <PresenterView event={api.event} sessionId={sessionId} questions={api.questions} updateQuestion={api.updateQuestion} deleteQuestion={api.deleteQuestion} />
      )}
    </main>
  );
}

function SessionTabs({ event, sessionId, setSessionId }) {
  return (
    <nav className="session-tabs" aria-label="Sessions">
      {event.sessions.map((session) => (
        <button key={session.id} className={sessionId === session.id ? "selected" : ""} onClick={() => setSessionId(session.id)}>
          <span>{session.label}</span>
          <small>{session.time}</small>
          <em>{session.topic}</em>
        </button>
      ))}
    </nav>
  );
}

function AudienceView({ event, sessionId, setSessionId, createQuestion }) {
  const [name, setName] = useState("");
  const [contact, setContact] = useState("");
  const [question, setQuestion] = useState("");
  const [tags, setTags] = useState(["MCP"]);
  const [message, setMessage] = useState("");

  async function submit(event) {
    event.preventDefault();
    setMessage("");
    try {
      await createQuestion({ sessionId, name, contact, question, tags });
      setQuestion("");
      setTags(["MCP"]);
      setMessage("Question saved. You can add another one anytime.");
    } catch (error) {
      setMessage(error.message);
    }
  }

  return (
    <section className="audience-grid">
      <div className="composer-panel">
        <div className="panel-heading">
          <MessageSquarePlus size={24} />
          <div>
            <h2>Ask without interrupting</h2>
            <p>Your question goes into the presenter queue for a later response.</p>
          </div>
        </div>
        <form onSubmit={submit} className="question-form">
          <label>
            Session
            <select value={sessionId} onChange={(event) => setSessionId(event.target.value)}>
              {event.sessions.map((session) => (
                <option key={session.id} value={session.id}>{session.label}</option>
              ))}
            </select>
          </label>
          <label>
            Name
            <input value={name} onChange={(event) => setName(event.target.value)} placeholder="Anonymous is okay" />
          </label>
          <label>
            Question
            <textarea value={question} onChange={(event) => setQuestion(event.target.value)} placeholder="What would you like answered after this agenda item?" rows={7} />
          </label>
          <div className="tag-row" aria-label="Question topics">
            {TAGS.map((tag) => (
              <button key={tag} type="button" className={tags.includes(tag) ? "picked" : ""} onClick={() => setTags((items) => items.includes(tag) ? items.filter((item) => item !== tag) : [...items, tag].slice(0, 4))}>
                {tag}
              </button>
            ))}
          </div>
          <label>
            Response contact
            <input value={contact} onChange={(event) => setContact(event.target.value)} placeholder="Email or Slack handle, optional" />
          </label>
          <button className="primary-action" type="submit">
            <Send size={18} /> Submit question
          </button>
          {message && <p className="form-message">{message}</p>}
        </form>
      </div>
      <div className="audience-side">
        <JoinPanel event={event} sessionId={sessionId} />
        <AgendaPanel event={event} sessionId={sessionId} />
      </div>
    </section>
  );
}

function AgendaPanel({ event, sessionId, compact = false }) {
  const items = event.agenda.filter((item) => item.sessionId === sessionId);
  return (
    <aside className={`agenda-panel ${compact ? "compact" : ""}`}>
      <div className="panel-heading compact">
        <CalendarDays size={21} />
        <div>
          <h2>Today&apos;s agenda</h2>
          <p>{event.date} · {event.time}</p>
        </div>
      </div>
      <ol className="agenda-list">
        {items.map((item) => (
          <li key={`${item.time}-${item.title}`}>
            <time>{item.time}</time>
            <div>
              <strong>{item.title}</strong>
              <span>{item.owner}{item.duration ? ` · ${item.duration}` : ""}</span>
            </div>
          </li>
        ))}
      </ol>
    </aside>
  );
}

function JoinPanel({ event, sessionId }) {
  const [qr, setQr] = useState("");
  const askUrl = `${window.location.origin}${window.location.pathname}?view=ask&session=${sessionId}`;

  useEffect(() => {
    QRCode.toDataURL(askUrl, { margin: 1, width: 240, color: { dark: "#152923", light: "#ffffff" } }).then(setQr);
  }, [askUrl]);

  return (
    <aside className="join-panel">
      <div className="live-pill"><Eye size={14} /> Ready for silent questions</div>
      <h2>Share this with the room</h2>
      <p>Put the QR code on a slide at the start and end of each session.</p>
      {qr && <img className="qr" src={qr} alt="Audience question QR code" />}
      <div className="share-line">
        <code>{askUrl.replace(/^https?:\/\//, "")}</code>
        <button type="button" onClick={() => navigator.clipboard?.writeText(askUrl)} aria-label="Copy audience link">
          <Clipboard size={17} />
        </button>
      </div>
      <div className="mini-sessions">
        {event.sessions.map((session) => (
          <span key={session.id} className={sessionId === session.id ? "current" : ""}>{session.label}</span>
        ))}
      </div>
    </aside>
  );
}

function PresenterView({ event, sessionId, questions, updateQuestion, deleteQuestion }) {
  const [query, setQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");
  const [selectedId, setSelectedId] = useState("");
  const sessionQuestions = useMemo(() => {
    return questions
      .filter((item) => item.sessionId === sessionId)
      .filter((item) => statusFilter === "all" || item.status === statusFilter)
      .filter((item) => `${item.name} ${item.question} ${item.tags.join(" ")}`.toLowerCase().includes(query.toLowerCase()))
      .sort((a, b) => Number(b.pinned) - Number(a.pinned) || new Date(b.createdAt) - new Date(a.createdAt));
  }, [questions, query, sessionId, statusFilter]);
  const selected = sessionQuestions.find((item) => item.id === selectedId) || sessionQuestions[0];
  const counts = {
    new: sessionQuestions.filter((item) => item.status === "new").length,
    followup: sessionQuestions.filter((item) => item.status === "followup").length,
    answered: sessionQuestions.filter((item) => item.status === "answered").length
  };

  function exportCsv() {
    const rows = [["Session", "Name", "Question", "Tags", "Status", "Answer", "Contact", "Created"]];
    for (const item of questions) {
      const session = event.sessions.find((entry) => entry.id === item.sessionId)?.label || item.sessionId;
      rows.push([session, item.name, item.question, item.tags.join("; "), item.status, item.answer, item.contact, item.createdAt]);
    }
    const csv = rows.map((row) => row.map((cell) => `"${String(cell || "").replaceAll('"', '""')}"`).join(",")).join("\n");
    const blob = new Blob([csv], { type: "text/csv" });
    const link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.download = "lab-questions.csv";
    link.click();
    URL.revokeObjectURL(link.href);
  }

  return (
    <section className="presenter-grid">
      <aside className="summary-rail">
        {Object.entries(STATUS).map(([key, value]) => {
          const Icon = value.icon;
          return (
            <div className="metric" key={key}>
              <Icon size={18} />
              <span>{value.label}</span>
              <strong>{counts[key]}</strong>
            </div>
          );
        })}
        <button className="export-button" type="button" onClick={exportCsv}>
          <Download size={17} /> Export CSV
        </button>
        <JoinPanel event={event} sessionId={sessionId} />
        <AgendaPanel event={event} sessionId={sessionId} compact />
      </aside>

      <section className="inbox-panel">
        <div className="toolbar">
          <label className="search-box">
            <Search size={17} />
            <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search questions" />
          </label>
          <a className="audience-link" href={`?view=ask&session=${sessionId}`} target="_blank" rel="noreferrer">
            <ExternalLink size={16} /> Audience link
          </a>
        </div>
        <div className="filter-tabs" aria-label="Question status filters">
          <button className={statusFilter === "all" ? "active" : ""} onClick={() => setStatusFilter("all")}>
            All <span>{counts.new + counts.followup + counts.answered}</span>
          </button>
          {Object.entries(STATUS).map(([key, value]) => (
            <button key={key} className={statusFilter === key ? "active" : ""} onClick={() => setStatusFilter(key)}>
              {value.label} <span>{counts[key]}</span>
            </button>
          ))}
        </div>
        <div className="question-list">
          {sessionQuestions.length === 0 && <div className="empty-state">No questions yet for this session.</div>}
          {sessionQuestions.map((item) => (
            <QuestionCard key={item.id} item={item} selected={selected?.id === item.id} onSelect={() => setSelectedId(item.id)} onUpdate={updateQuestion} />
          ))}
        </div>
      </section>

      <ResponsePanel question={selected} updateQuestion={updateQuestion} deleteQuestion={deleteQuestion} />
    </section>
  );
}

function QuestionCard({ item, selected, onSelect, onUpdate }) {
  return (
    <article className={`question-card ${selected ? "selected" : ""}`} onClick={onSelect}>
      <div className="card-topline">
        <button type="button" className="icon-button" onClick={(event) => { event.stopPropagation(); onUpdate(item.id, { pinned: !item.pinned }); }}>
          {item.pinned ? <PinOff size={15} /> : <Pin size={15} />}
        </button>
        <span>{item.name}</span>
        <time>{new Date(item.createdAt).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })}</time>
      </div>
      <p>{item.question}</p>
      <div className="card-tags">
        {item.tags.map((tag) => <span key={tag}>{tag}</span>)}
        <strong className={`status ${item.status}`}>{STATUS[item.status]?.label}</strong>
      </div>
    </article>
  );
}

function ResponsePanel({ question, updateQuestion, deleteQuestion }) {
  const [draft, setDraft] = useState("");
  const [note, setNote] = useState("");

  useEffect(() => {
    setDraft(question?.answer || "");
    setNote(question?.note || "");
  }, [question?.id]);

  if (!question) {
    return <aside className="response-panel empty-state">Select a question to prepare a response.</aside>;
  }

  return (
    <aside className="response-panel">
      <div className="panel-heading compact">
        <PencilLine size={22} />
        <div>
          <h2>Response workspace</h2>
          <p>{question.name} · {question.contact || "No contact shared"}</p>
        </div>
      </div>
      <blockquote>{question.question}</blockquote>
      <div className="status-row">
        {Object.entries(STATUS).map(([key, value]) => (
          <button key={key} className={question.status === key ? "active" : ""} onClick={() => updateQuestion(question.id, { status: key })}>
            {value.label}
          </button>
        ))}
      </div>
      <label>
        Private note
        <textarea value={note} onChange={(event) => setNote(event.target.value)} onBlur={() => updateQuestion(question.id, { note })} rows={4} />
      </label>
      <label>
        Draft answer
        <textarea value={draft} onChange={(event) => setDraft(event.target.value)} rows={7} placeholder="Write the answer you want to send or discuss later." />
      </label>
      <div className="response-actions">
        <button className="secondary-action" onClick={() => updateQuestion(question.id, { answer: draft, status: draft ? "answered" : question.status })}>
          <Sparkles size={17} /> Save answer
        </button>
        <button className="danger-action" onClick={() => deleteQuestion(question.id)}>
          <Trash2 size={17} /> Delete
        </button>
      </div>
    </aside>
  );
}

createRoot(document.getElementById("root")).render(<App />);
