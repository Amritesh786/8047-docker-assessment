const statusLine = document.querySelector("#status");
const form = document.querySelector("#form");
const formMessage = document.querySelector("#form-message");
const list = document.querySelector("#list");
const empty = document.querySelector("#empty");
const count = document.querySelector("#count");

async function refresh() {
  const [healthResponse, registrationsResponse] = await Promise.all([
    fetch("/api/health"),
    fetch("/api/registrations"),
  ]);
  if (!healthResponse.ok || !registrationsResponse.ok) {
    throw new Error("Backend not reachable");
  }

  const health = await healthResponse.json();
  const registrations = await registrationsResponse.json();
  document.querySelector("#regno").textContent = health.regno;
  statusLine.textContent = `REGNO ${health.regno} | backend ${health.version} on ${health.container} | database ${health.database ? "connected" : "not connected"}`;

  list.replaceChildren(...registrations.map((registration) => {
    const item = document.createElement("li");
    const number = document.createElement("span");
    const details = document.createElement("span");
    const name = document.createElement("strong");
    const event = document.createElement("span");
    number.className = "entry-number";
    number.textContent = String(registration.id).padStart(3, "0");
    details.className = "entry-details";
    name.textContent = registration.name;
    event.className = "entry-event";
    event.textContent = registration.event;
    details.append(name, event);
    item.append(number, details);
    return item;
  }));
  empty.hidden = registrations.length > 0;
  count.textContent = `${registrations.length} ${registrations.length === 1 ? "PERSON" : "PEOPLE"}`;
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  formMessage.textContent = "";
  const button = form.querySelector("button");
  button.disabled = true;
  try {
    const response = await fetch("/api/registrations", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(Object.fromEntries(new FormData(form))),
    });
    const result = await response.json();
    if (!response.ok) throw new Error(result.error || "Registration failed");
    form.reset();
    formMessage.textContent = "You are on the list.";
    await refresh();
  } catch (error) {
    formMessage.textContent = error.message;
  } finally {
    button.disabled = false;
  }
});

refresh().catch(() => {
  statusLine.textContent = "Backend not reachable";
});