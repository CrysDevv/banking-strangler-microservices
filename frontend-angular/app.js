const API_BASE = "/api/v1/bff";
const elements = {
  status: document.querySelector("#connection-status"),
  tokenDialog: document.querySelector("#connect-dialog"),
  tokenInput: document.querySelector("#api-token"),
  clientInput: document.querySelector("#client-id"),
  connectForm: document.querySelector("#connect-form"),
  connectFeedback: document.querySelector("#connect-feedback"),
  accountList: document.querySelector("#account-list"),
  originAccount: document.querySelector("#origin-account"),
  movementAccount: document.querySelector("#movement-account"),
  movementList: document.querySelector("#movement-list"),
  transferForm: document.querySelector("#transfer-form"),
  transferSubmit: document.querySelector("#transfer-submit"),
  formFeedback: document.querySelector("#form-feedback"),
  confirmDialog: document.querySelector("#confirm-dialog"),
  confirmSummary: document.querySelector("#confirmation-summary"),
  confirmFeedback: document.querySelector("#confirm-feedback"),
};

let accessToken = "";
let clientId = 1;
let accounts = [];
let pendingTransfer = null;

const currency = (amount, code = "CLP") =>
  new Intl.NumberFormat("es-CL", {
    style: "currency",
    currency: code,
    maximumFractionDigits: code === "CLP" ? 0 : 2,
  }).format(Number(amount) || 0);

function feedback(target, message, success = false) {
  target.textContent = message;
  target.classList.toggle("is-success", success);
}

function setConnected(connected) {
  elements.status.classList.toggle("is-connected", connected);
  elements.status.innerHTML = `<span class="status-dot"></span>${connected ? "Conectado" : "Sin conexión"}`;
}

function setTransferEnabled(enabled) {
  elements.originAccount.disabled = !enabled;
  document.querySelector("#destination-account").disabled = !enabled;
  document.querySelector("#amount").disabled = !enabled;
  document.querySelector("#memo").disabled = !enabled;
  elements.transferSubmit.disabled = !enabled;
  elements.movementAccount.disabled = !enabled;
}

async function apiRequest(path, options = {}) {
  const response = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
      "X-Correlation-ID": crypto.randomUUID(),
      ...options.headers,
    },
  });
  const body = await response.json().catch(() => null);
  if (!response.ok) {
    const message = body?.message;
    throw new Error(Array.isArray(message) ? message.join(". ") : message || `Error HTTP ${response.status}`);
  }
  return body;
}

function accountMarkup(account, index) {
  const active = account.estado === "ACTIVA";
  return `
    <article class="account-card${index === 0 ? " is-selected" : ""}" data-account="${account.numeroCuenta}">
      <span class="account-icon" aria-hidden="true">
        <svg viewBox="0 0 24 24"><rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 10h18M7 15h3"/></svg>
      </span>
      <div class="account-main">
        <span class="account-type">${escapeHtml(account.tipo || "Cuenta")} <span class="state-pill${active ? "" : " is-blocked"}">${active ? "Activa" : "Bloqueada"}</span></span>
        <span class="account-number">•••• ${escapeHtml(String(account.numeroCuenta).slice(-4))} · ${escapeHtml(account.moneda || "CLP")}</span>
      </div>
      <div class="account-balance">
        <strong>${currency(account.saldo, account.moneda || "CLP")}</strong>
        <span>Saldo disponible</span>
      </div>
    </article>`;
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (char) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  })[char]);
}

function updateAccountSelectors() {
  const availableAccounts = accounts.filter((account) => account.estado === "ACTIVA");
  const accountOptions = availableAccounts.map((account) =>
    `<option value="${escapeHtml(account.numeroCuenta)}">${escapeHtml(account.tipo)} · •••• ${escapeHtml(String(account.numeroCuenta).slice(-4))} · ${currency(account.saldo, account.moneda)}</option>`,
  ).join("");

  elements.originAccount.innerHTML = availableAccounts.length
    ? accountOptions
    : '<option value="">No hay cuentas activas</option>';
  elements.movementAccount.innerHTML = availableAccounts.length
    ? accountOptions
    : '<option value="">No hay cuentas activas</option>';
  elements.movementAccount.value = elements.originAccount.value;
}

async function loadMovements(accountNumber) {
  if (!accountNumber) return;
  elements.movementList.innerHTML = '<tr><td class="table-empty" colspan="4">Cargando movimientos…</td></tr>';
  try {
    const movements = await apiRequest(`/cuentas/${encodeURIComponent(accountNumber)}/movimientos`);
    const rows = [...(Array.isArray(movements) ? movements : [])].sort((a, b) =>
      new Date(b.fechaMovimiento) - new Date(a.fechaMovimiento),
    );
    document.querySelector("#movement-count").textContent = rows.length;
    document.querySelector("#activity-caption").textContent = `${rows.length} movimientos en la cuenta seleccionada`;
    elements.movementList.innerHTML = rows.length
      ? rows.slice(0, 6).map((movement) => {
        const credit = movement.tipo === "CREDITO";
        const sign = credit ? "+" : "−";
        const date = movement.fechaMovimiento
          ? new Intl.DateTimeFormat("es-CL", { dateStyle: "medium" }).format(new Date(movement.fechaMovimiento))
          : "—";
        return `<tr>
          <td><span class="movement-description"><span class="movement-icon${credit ? "" : " is-debit"}" aria-hidden="true">${credit ? "↓" : "↑"}</span>${escapeHtml(movement.glosa || (credit ? "Abono recibido" : "Transferencia enviada"))}</span></td>
          <td>${escapeHtml(date)}</td>
          <td><span class="state-pill">Completado</span></td>
          <td class="amount-column">${sign}${currency(movement.monto)}</td>
        </tr>`;
      }).join("")
      : '<tr><td class="table-empty" colspan="4">Todavía no hay movimientos para esta cuenta.</td></tr>';
  } catch (error) {
    elements.movementList.innerHTML = `<tr><td class="table-empty" colspan="4">${escapeHtml(error.message)}</td></tr>`;
  }
}

async function loadDashboard() {
  const result = await apiRequest(`/clientes/${encodeURIComponent(clientId)}/cuentas`);
  if (!Array.isArray(result)) throw new Error("La respuesta de cuentas no tiene el formato esperado.");
  accounts = result;
  const total = accounts.reduce((sum, account) => sum + Number(account.saldo || 0), 0);
  const activeCount = accounts.filter((account) => account.estado === "ACTIVA").length;
  document.querySelector("#total-balance").textContent = currency(total);
  document.querySelector("#active-count").textContent = activeCount;
  document.querySelector("#account-count").textContent = `${accounts.length} ${accounts.length === 1 ? "cuenta registrada" : "cuentas registradas"}`;
  elements.accountList.innerHTML = accounts.length
    ? accounts.map(accountMarkup).join("")
    : '<div class="empty-state"><strong>Sin cuentas disponibles</strong><p>Este cliente todavía no tiene productos asociados.</p></div>';
  updateAccountSelectors();
  setTransferEnabled(activeCount > 0);
  setConnected(true);
  elements.tokenDialog.close();
  if (activeCount > 0) await loadMovements(elements.movementAccount.value);
}

function openTokenDialog() {
  elements.connectFeedback.textContent = "";
  elements.tokenDialog.showModal();
  elements.tokenInput.focus();
}

document.querySelector("#token-open").addEventListener("click", openTokenDialog);
document.querySelector("#connect-button").addEventListener("click", openTokenDialog);
document.querySelector("#refresh-button").addEventListener("click", async () => {
  if (!accessToken) return openTokenDialog();
  try {
    await loadDashboard();
  } catch (error) {
    setConnected(false);
    openTokenDialog();
    feedback(elements.connectFeedback, error.message);
  }
});

elements.connectForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  accessToken = elements.tokenInput.value.trim();
  clientId = elements.clientInput.value.trim();
  feedback(elements.connectFeedback, "Conectando…", true);
  try {
    await loadDashboard();
    elements.tokenInput.value = "";
  } catch (error) {
    accessToken = "";
    setConnected(false);
    feedback(elements.connectFeedback, error.message);
  }
});

elements.accountList.addEventListener("click", (event) => {
  const card = event.target.closest(".account-card");
  if (!card) return;
  document.querySelectorAll(".account-card").forEach((item) => item.classList.toggle("is-selected", item === card));
  elements.movementAccount.value = card.dataset.account;
  loadMovements(card.dataset.account);
});

elements.originAccount.addEventListener("change", () => {
  const account = accounts.find((item) => item.numeroCuenta === elements.originAccount.value);
  document.querySelectorAll(".account-card").forEach((card) =>
    card.classList.toggle("is-selected", card.dataset.account === elements.originAccount.value),
  );
  if (account) {
    elements.movementAccount.value = account.numeroCuenta;
    loadMovements(account.numeroCuenta);
  }
});
elements.movementAccount.addEventListener("change", () => loadMovements(elements.movementAccount.value));
document.querySelector("#new-transfer-button").addEventListener("click", () => {
  document.querySelector("#transfer-panel").scrollIntoView({ behavior: "smooth", block: "center" });
  document.querySelector("#destination-account").focus({ preventScroll: true });
});
document.querySelector("#cancel-transfer").addEventListener("click", () => elements.confirmDialog.close());

elements.transferForm.addEventListener("submit", (event) => {
  event.preventDefault();
  const formData = new FormData(elements.transferForm);
  const source = accounts.find((account) => account.numeroCuenta === formData.get("cuentaOrigen"));
  const destination = String(formData.get("cuentaDestino")).trim();
  const amount = Number(formData.get("monto"));
  if (!source || !destination || !Number.isFinite(amount) || amount <= 0) {
    return feedback(elements.formFeedback, "Revisa la cuenta de origen, el destino y el monto.");
  }
  if (destination === source.numeroCuenta) {
    return feedback(elements.formFeedback, "La cuenta de destino debe ser distinta a la cuenta de origen.");
  }
  if (amount > Number(source.saldo)) {
    return feedback(elements.formFeedback, "El monto supera el saldo disponible de esta cuenta.");
  }
  pendingTransfer = {
    cuentaOrigen: source.numeroCuenta,
    cuentaDestino: destination,
    monto: amount,
    glosa: String(formData.get("glosa")).trim(),
    idempotencyKey: `web-${crypto.randomUUID()}`,
  };
  elements.confirmSummary.innerHTML = `
    <div class="confirm-line"><span>Desde</span><strong>•••• ${escapeHtml(source.numeroCuenta.slice(-4))}</strong></div>
    <div class="confirm-line"><span>Hacia</span><strong>${escapeHtml(destination)}</strong></div>
    <div class="confirm-line"><span>Monto</span><strong>${currency(amount, source.moneda || "CLP")}</strong></div>
    <div class="confirm-line"><span>Mensaje</span><strong>${escapeHtml(pendingTransfer.glosa || "—")}</strong></div>`;
  feedback(elements.formFeedback, "");
  feedback(elements.confirmFeedback, "");
  elements.confirmDialog.showModal();
});

document.querySelector("#confirm-transfer").addEventListener("click", async (event) => {
  if (!pendingTransfer) return;
  const button = event.currentTarget;
  button.disabled = true;
  button.textContent = "Enviando…";
  feedback(elements.confirmFeedback, "");
  try {
    const result = await apiRequest("/transferencias", {
      method: "POST",
      body: JSON.stringify(pendingTransfer),
    });
    elements.confirmDialog.close();
    elements.transferForm.reset();
    feedback(elements.formFeedback, `Transferencia ${result?.estado || "procesada"} · ID ${result?.transferenciaId || "registrada"}`, true);
    await loadDashboard();
  } catch (error) {
    feedback(elements.confirmFeedback, error.message);
  } finally {
    button.disabled = false;
    button.innerHTML = "Confirmar envío";
  }
});

const today = new Intl.DateTimeFormat("es-CL", { weekday: "long", day: "numeric", month: "long" }).format(new Date());
document.querySelector("#today-label").textContent = today.toLocaleUpperCase("es-CL");
