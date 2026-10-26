// Web app windows hand new links to a normal window; send those to the default browser instead.
const handled = new Set();

async function redirect(tab, url) {
  if (handled.has(tab.id) || !/^https?:\/\//i.test(url || "")) return;
  const win = await chrome.windows.get(tab.windowId).catch(() => null);
  if (win?.type !== "normal") return;
  handled.add(tab.id);
  chrome.runtime.sendNativeMessage("com.lkshrk.open_url", { url }).catch(() => {});
  chrome.tabs.remove(tab.id).catch(() => {});
}

chrome.tabs.onCreated.addListener((tab) => redirect(tab, tab.pendingUrl || tab.url));
chrome.tabs.onUpdated.addListener((_id, info, tab) => redirect(tab, info.url));
chrome.tabs.onRemoved.addListener((id) => handled.delete(id));
