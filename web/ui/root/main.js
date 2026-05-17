const routes = {
  "/": {
    title: "Codex MK3",
    body: "A controllable structure for core logic, interface routing, application flow, brand voice, and prelaunch execution.",
    panels: ["CORE online", "WEB online", "APP pending", "MANTRA pending", "PRELAUNCH pending"]
  },
  "/about": {
    title: "Identity",
    body: "The MK3 identity is direct, structured, and user-controlled.",
    panels: ["Tone: precise", "Promise: agency", "Boundary: supervised autonomy"]
  },
  "/mk3": {
    title: "System Overview",
    body: "Modules are installed from the integration map, registered by file ID, and validated by target path.",
    panels: ["Parser v3", "Mimic engine v3", "WEB router v1"]
  },
  "/contact": {
    title: "Contact",
    body: "The POST /submit endpoint is reserved for contact and feedback intake.",
    panels: ["GET /status", "POST /submit", "GET /mk3/info"]
  }
};

function currentPath() {
  const hash = window.location.hash.replace(/^#/, "");
  return routes[hash] ? hash : "/";
}

function render() {
  const route = routes[currentPath()];
  const panels = route.panels.map((item) => `<article class="panel"><h3>${item}</h3><p>Status surface ready for implementation.</p></article>`).join("");
  document.querySelector("#app").innerHTML = `
    <section class="hero">
      <div>
        <span class="status">WEB_ONLINE</span>
        <h1>${route.title}</h1>
        <p>${route.body}</p>
      </div>
      <div class="signal" role="img" aria-label="Codex MK3 interface signal"></div>
    </section>
    <section class="grid">${panels}</section>
  `;
}

window.addEventListener("hashchange", render);
render();
