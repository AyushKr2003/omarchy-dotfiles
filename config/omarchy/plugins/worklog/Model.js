// Small, local-only helpers for the work-log history.
function normalizeStatus(value) {
    return value === "in-progress" || value === "done" ? value : "todo";
}

function parseEntries(raw) {
    var entries = [];
    try {
        var parsed = JSON.parse(String(raw || "[]"));
        if (!Array.isArray(parsed)) return entries;
        for (var i = 0; i < parsed.length; ++i) {
            var item = parsed[i];
            if (!item || typeof item.title !== "string") continue;
            var title = item.title.replace(/^\s+|\s+$/g, "");
            if (title === "") continue;
            entries.push({
                title: title,
                body: typeof item.body === "string" ? item.body : "",
                date: typeof item.date === "string" ? item.date : "",
                status: normalizeStatus(item.status)
            });
        }
    } catch (e) {
        return [];
    }
    return entries;
}

function nowISO() {
    return new Date().toISOString();
}

function formatDate(iso) {
    if (!iso || typeof iso !== "string") return "";
    var d = new Date(iso);
    if (isNaN(d.getTime())) return "";
    var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    var h = d.getHours();
    var m = d.getMinutes();
    var hh = (h < 10 ? "0" : "") + h;
    var mm = (m < 10 ? "0" : "") + m;
    return months[d.getMonth()] + " " + d.getDate() + ", " + d.getFullYear() + " " + hh + ":" + mm;
}

if (typeof module !== "undefined") {
    module.exports = { parseEntries: parseEntries, normalizeStatus: normalizeStatus, nowISO: nowISO, formatDate: formatDate };
}
