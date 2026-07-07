const params = new URLSearchParams(window.location.search);
const queryEmployee = params.get("employee") || "";
const querySelected = params.get("selected") || "";
const today = new Date();
const todayIso = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, "0")}-${String(today.getDate()).padStart(2, "0")}`;

const state = {
  date: params.get("date") || todayIso,
  loading: true,
  error: "",
  workers: [],
  lineOverview: null,
  managerSignals: null,
  latestRuns: {},
  refreshedAt: "",
  selectedWorkerId: queryEmployee || querySelected
};

const app = document.querySelector("#app");
const toast = document.querySelector("#toast");

async function loadAssignments() {
  state.loading = true;
  state.error = "";
  render();

  try {
    const apiParams = new URLSearchParams({ date: state.date });
    if (queryEmployee) apiParams.set("employee", queryEmployee);
    const response = await fetch(`/api/daily-assignments?${apiParams.toString()}`, { cache: "no-store" });
    const payload = await response.json();
    if (!response.ok || !payload.ok) throw new Error(payload.error || "Unable to load Hawley assignments.");

    state.workers = payload.workers || [];
    state.lineOverview = payload.lineOverview || null;
    state.managerSignals = payload.managerSignals || null;
    state.latestRuns = payload.latestRuns || {};
    state.refreshedAt = payload.refreshedAt || "";
    if (!state.selectedWorkerId && state.workers.length === 1) state.selectedWorkerId = state.workers[0].id;
  } catch (error) {
    state.error = error.message || String(error);
  } finally {
    state.loading = false;
    render();
  }
}

function render() {
  const locked = Boolean(queryEmployee);
  const selectedWorker = selectedWorkerForView();

  app.innerHTML = `
    <div class="shell ${locked ? "locked" : ""}">
      ${renderSidebar(selectedWorker, locked)}
      <main class="main">
        ${renderTopbar(selectedWorker, locked)}
        ${state.loading ? renderLoading() : state.error ? renderError() : locked || selectedWorker ? renderWorker(selectedWorker, locked) : renderManager()}
      </main>
    </div>
  `;

  bindEvents();
}

function renderSidebar(selectedWorker, locked) {
  if (locked) {
    return `
      <aside class="sidebar">
        <div class="brand">
          <span>H.A.W.L.E.</span>
          <strong>${escapeHtml(selectedWorker?.name || "Worker")}</strong>
        </div>
        ${renderWorkerMini(selectedWorker)}
      </aside>
    `;
  }

  return `
    <aside class="sidebar">
      <div class="brand">
        <span>H.A.W.L.E.</span>
        <strong>Worker Pilot</strong>
      </div>
      <button class="worker-row ${selectedWorker ? "" : "active"}" type="button" data-action="dashboard">
        <span class="dot"></span>
        <span>
          <strong>Manager</strong>
          <small>${state.workers.length} workers</small>
        </span>
      </button>
      <div class="worker-list">
        ${state.workers.map(worker => renderWorkerButton(worker, selectedWorker)).join("") || `<div class="empty">No workers for this date.</div>`}
      </div>
    </aside>
  `;
}

function renderWorkerButton(worker, selectedWorker) {
  const active = selectedWorker && selectedWorker.id === worker.id ? "active" : "";
  return `
    <button class="worker-row ${active}" type="button" data-worker="${escapeAttr(worker.id)}">
      <span class="dot ${worker.remainingHours > 0 ? "open" : "done"}"></span>
      <span>
        <strong>${escapeHtml(worker.name)}</strong>
        <small>${escapeHtml(worker.phase || worker.cycle || worker.email || "Worker")}</small>
      </span>
    </button>
  `;
}

function renderWorkerMini(worker) {
  if (!worker) return `<div class="empty">No assignment snapshot.</div>`;
  return `
    <div class="mini-card">
      <span>${escapeHtml(worker.status)}</span>
      <strong>${formatHours(worker.remainingHours)} remaining</strong>
      <small>${worker.completedTaskCount || 0}/${worker.taskCount || 0} tasks complete</small>
    </div>
  `;
}

function renderTopbar(worker, locked) {
  const title = locked ? worker?.name || "Worker page" : worker ? worker.name : "Manager dashboard";
  return `
    <header class="topbar">
      <div>
        <p>${locked ? "Worker View" : "Hawley Pilot"}</p>
        <h1>${escapeHtml(title)}</h1>
      </div>
      <div class="topbar-actions">
        ${locked ? "" : `<input class="date-input" type="date" value="${escapeAttr(state.date)}" />`}
        ${locked ? "" : `<button class="btn" type="button" data-action="reload">Reload</button>`}
        ${worker && !locked ? `<button class="btn primary" type="button" data-action="copy-link">Copy link</button>` : ""}
        ${worker && !locked ? `<button class="btn" type="button" data-action="dashboard">Dashboard</button>` : ""}
      </div>
    </header>
  `;
}

function renderManager() {
  const line = state.lineOverview || {};
  const signals = state.managerSignals || {};
  return `
    <section class="dashboard">
      <div class="metrics">
        ${renderMetric("Assigned", formatHours(line.assignedHours))}
        ${renderMetric("Remaining", formatHours(line.remainingHours))}
        ${renderMetric("Complete", `${formatNumber(line.completionPercent)}%`)}
        ${renderMetric("Open Tasks", signals.openTasks ?? 0)}
      </div>
      <div class="panel">
        <div class="panel-head">
          <h2>Daily Line</h2>
          <span>${escapeHtml(formatLongDate(state.date))}</span>
        </div>
        <div class="line-grid">
          ${renderLineItem("Cycle", line.cycle || "Current")}
          ${renderLineItem("Workers", `${signals.openWorkers || 0} open / ${signals.completeWorkers || 0} complete`)}
          ${renderLineItem("Tasks", `${line.completedTaskCount || 0}/${line.taskCount || 0}`)}
          ${renderLineItem("Source", sourceFreshness())}
        </div>
      </div>
      <div class="worker-grid">
        ${state.workers.map(renderWorkerCard).join("") || `<div class="empty panel">No Hawley assignments for ${escapeHtml(state.date)}.</div>`}
      </div>
    </section>
  `;
}

function renderWorkerCard(worker) {
  return `
    <article class="worker-card" data-worker="${escapeAttr(worker.id)}">
      <div>
        <h3>${escapeHtml(worker.name)}</h3>
        <p>${escapeHtml(worker.phase || worker.cycle || worker.email || "Daily assignment")}</p>
      </div>
      <div class="progress">
        <span style="width: ${completionPercent(worker)}%"></span>
      </div>
      <div class="worker-card-row">
        <strong>${formatHours(worker.remainingHours)}</strong>
        <span>${worker.completedTaskCount || 0}/${worker.taskCount || 0} tasks</span>
      </div>
    </article>
  `;
}

function renderWorker(worker, locked) {
  if (!worker) return `<section class="panel"><div class="empty">No worker found for this page.</div></section>`;
  const openTasks = worker.tasks.filter(task => !task.completed);
  const doneTasks = worker.tasks.filter(task => task.completed);

  return `
    <section class="worker-page">
      <div class="worker-hero">
        <div>
          <p>${escapeHtml(worker.email || worker.phase || "Daily assignment")}</p>
          <h2>${escapeHtml(worker.name)}</h2>
        </div>
        <div class="hero-metrics">
          ${renderMetric("Assigned", formatHours(worker.assignedHours))}
          ${renderMetric("Remaining", formatHours(worker.remainingHours))}
          ${renderMetric("Tasks", `${worker.completedTaskCount || 0}/${worker.taskCount || 0}`)}
        </div>
      </div>
      <div class="task-section">
        <div class="section-title">
          <h3>Open Work</h3>
          <span>${openTasks.length} tasks</span>
        </div>
        <div class="task-list">
          ${openTasks.map(task => renderTask(task, locked)).join("") || `<div class="empty">All assigned tasks are complete.</div>`}
        </div>
      </div>
      ${locked ? "" : `
        <div class="task-section">
          <div class="section-title">
            <h3>Completed</h3>
            <span>${doneTasks.length} tasks</span>
          </div>
          <div class="task-list compact">
            ${doneTasks.map(task => renderTask(task, locked)).join("") || `<div class="empty">No completed tasks for this date.</div>`}
          </div>
        </div>
      `}
    </section>
  `;
}

function renderTask(task, locked) {
  const links = [
    task.sopUrl ? `<a class="btn small" href="${escapeAttr(task.sopUrl)}" target="_blank" rel="noreferrer">SOP</a>` : "",
    task.sourceUrl ? `<a class="btn small" href="${escapeAttr(task.sourceUrl)}" target="_blank" rel="noreferrer">Source</a>` : ""
  ].filter(Boolean).join("");

  return `
    <article class="task-card ${task.completed ? "done" : ""}">
      <div class="task-main">
        <span class="status ${task.completed ? "done" : "open"}">${task.completed ? "Done" : "Open"}</span>
        <h4>${escapeHtml(task.title)}</h4>
        <p>${escapeHtml([task.workArea, task.cycle, task.vin ? `VIN ${task.vin}` : ""].filter(Boolean).join(" · "))}</p>
      </div>
      <div class="task-side">
        <strong>${formatMinutes(task.estimatedMinutes)}</strong>
        <small>${task.actualTimeMinutes ? `${formatMinutes(task.actualTimeMinutes)} actual` : "No actual time"}</small>
        <div class="task-actions">${links || `<span class="muted">No links</span>`}</div>
      </div>
    </article>
  `;
}

function renderMetric(label, value) {
  return `<div class="metric"><span>${escapeHtml(label)}</span><strong>${escapeHtml(String(value ?? "--"))}</strong></div>`;
}

function renderLineItem(label, value) {
  return `<div class="line-item"><span>${escapeHtml(label)}</span><strong>${escapeHtml(String(value || "--"))}</strong></div>`;
}

function renderLoading() {
  return `<section class="panel"><div class="loading">Loading Hawley assignments...</div></section>`;
}

function renderError() {
  return `
    <section class="panel error-panel">
      <h2>Hawley could not load assignments</h2>
      <p>${escapeHtml(state.error)}</p>
      <button class="btn primary" type="button" data-action="reload">Retry</button>
    </section>
  `;
}

function bindEvents() {
  document.querySelectorAll("[data-worker]").forEach(element => {
    element.addEventListener("click", () => {
      state.selectedWorkerId = element.dataset.worker;
      const url = new URL(window.location.href);
      url.searchParams.set("selected", state.selectedWorkerId);
      url.searchParams.delete("employee");
      history.replaceState(null, "", url);
      render();
    });
  });

  document.querySelectorAll("[data-action='dashboard']").forEach(button => {
    button.addEventListener("click", () => {
      state.selectedWorkerId = "";
      const url = new URL(window.location.href);
      url.searchParams.delete("selected");
      history.replaceState(null, "", url);
      render();
    });
  });

  document.querySelectorAll("[data-action='reload']").forEach(button => {
    button.addEventListener("click", loadAssignments);
  });

  document.querySelector(".date-input")?.addEventListener("change", event => {
    state.date = event.target.value || todayIso;
    const url = new URL(window.location.href);
    url.searchParams.set("date", state.date);
    history.replaceState(null, "", url);
    loadAssignments();
  });

  document.querySelector("[data-action='copy-link']")?.addEventListener("click", async () => {
    const worker = selectedWorkerForView();
    if (!worker) return;
    await navigator.clipboard.writeText(employeeUrl(worker.id));
    showToast("Worker link copied");
  });
}

function selectedWorkerForView() {
  const desired = queryEmployee || state.selectedWorkerId;
  return state.workers.find(worker => worker.id === desired) || null;
}

function employeeUrl(workerId) {
  const url = new URL(window.location.href);
  url.searchParams.delete("selected");
  url.searchParams.set("employee", workerId);
  return url.toString();
}

function completionPercent(worker) {
  if (!worker.assignedHours) return 0;
  return Math.min(100, Math.round((Number(worker.completedHours || 0) / Number(worker.assignedHours || 0)) * 100));
}

function sourceFreshness() {
  const runs = Object.values(state.latestRuns || {}).filter(Boolean);
  const latest = runs.map(run => run.ended_at).filter(Boolean).sort().pop();
  return latest ? formatDateTime(latest) : "Unknown";
}

function formatHours(value) {
  const num = Number(value || 0);
  return `${formatNumber(num)}h`;
}

function formatMinutes(value) {
  const minutes = Math.round(Number(value || 0));
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  const remainder = minutes % 60;
  return remainder ? `${hours}h ${remainder}m` : `${hours}h`;
}

function formatNumber(value) {
  const num = Number(value || 0);
  return Number.isInteger(num) ? String(num) : num.toFixed(1);
}

function formatLongDate(date) {
  const parsed = new Date(`${date}T00:00:00`);
  return parsed.toLocaleDateString(undefined, { weekday: "long", month: "short", day: "numeric" });
}

function formatDateTime(value) {
  return new Date(value).toLocaleString(undefined, { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" });
}

function showToast(message) {
  toast.textContent = message;
  toast.classList.add("show");
  window.clearTimeout(showToast.timer);
  showToast.timer = window.setTimeout(() => toast.classList.remove("show"), 2200);
}

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function escapeAttr(value) {
  return escapeHtml(value);
}

loadAssignments();
