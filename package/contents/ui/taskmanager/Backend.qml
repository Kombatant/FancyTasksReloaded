import QtQuick 2.15
import org.kde.plasma.plasma5support 2.0 as P5Support
import org.kde.taskmanager 0.1 as TaskManager

QtObject {
    id: backend

    enum MiddleClickAction {
        None,
        Close,
        NewInstance,
        ToggleMinimized,
        ToggleGrouping,
        BringToCurrentDesktop
    }

    property Item taskManagerItem: null
    property bool highlightWindows: false
    readonly property bool windowViewAvailable: false

    signal addLauncher(url url)
    signal showAllPlaces()

    // Window-highlight state for debounced KWin D-Bus calls.
    // Debouncing avoids race conditions when the mouse rapidly transitions
    // between thumbnails, which would otherwise fire concurrent D-Bus processes.
    property var _pendingHighlightWinIds: []
    property bool _pendingHighlightActive: false

    function _highlightCommand(winIds) {
        var cmd = "dbus-send --session --dest=org.kde.KWin --type=method_call " +
                  "/org/kde/KWin/HighlightWindow org.kde.KWin.HighlightWindow.highlightWindows ";
        var args = [];
        for (var i = 0; i < winIds.length; i++) {
            var uuid = winIds[i].toString();
            // Validate UUID format to guard against injection.
            if (/^\{?[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\}?$/i.test(uuid)) {
                args.push(uuid);
            }
        }
        return cmd + "array:string:" + args.join(",");
    }

    property Timer _highlightTimer: Timer {
        interval: 30
        repeat: false
        onTriggered: {
            var cmd = backend._highlightCommand(
                backend._pendingHighlightActive ? backend._pendingHighlightWinIds : []);
            backend._processRunner.connectSource(cmd);
        }
    }

    function cancelHighlightWindows() {
        _pendingHighlightWinIds = [];
        _pendingHighlightActive = false;
        _highlightTimer.restart();
    }

    function windowsHovered(winIds, hovered) {
        if (!highlightWindows) {
            return;
        }
        var uuids = [];
        if (hovered && winIds) {
            for (var i = 0; i < winIds.length; i++) {
                var w = winIds[i];
                if (w !== undefined && w !== null && w.toString() !== "0") {
                    uuids.push(w.toString());
                }
            }
        }
        _pendingHighlightWinIds = uuids;
        _pendingHighlightActive = hovered && uuids.length > 0;
        _highlightTimer.restart();
    }

    function activateWindowView(winIds) {
    }

    function ungrabMouse(item) {
    }

    function setActionGroup(action) {
    }

    // --- Process launcher for desktop actions ---

    readonly property P5Support.DataSource _processRunner: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
        onNewData: function(source) { disconnectSource(source) }
    }

    // DataSource for reading files via cat — results populate _desktopFileCache
    readonly property P5Support.DataSource _fileReader: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            var stdout = data["stdout"] || "";
            var key = backend._pendingReads[source];
            if (key !== undefined) {
                delete backend._pendingReads[source];
                if (stdout) {
                    // File found — cache content
                    backend._desktopFileCache[key] = stdout;
                    delete backend._searchState[key];
                } else {
                    // File not found — try next search dir
                    backend._tryNextDir(key);
                }
            }
            disconnectSource(source);
        }
    }

    // Pending reads: { "cat /path": "applications:foo.desktop" }
    property var _pendingReads: ({})
    // Track which search dir index we're on: { "applications:foo.desktop": dirIndex }
    property var _searchState: ({})

    function launchExec(exec) {
        var cmd = exec.replace(/%[fFuUdDnNickKvm]/g, "").replace(/\s+/g, " ").trim();
        if (cmd) {
            _processRunner.connectSource(cmd);
        }
    }

    function launchDesktopEntry(launcherUrl) {
        if (!launcherUrl) return false;

        var value = launcherUrl.toString().split("?")[0];
        var desktopId = "";

        if (value.startsWith("applications:")) {
            desktopId = value.substring(13);
        } else if (value.startsWith("file://")) {
            var lastSlash = value.lastIndexOf("/");
            desktopId = lastSlash !== -1 ? value.substring(lastSlash + 1) : value.substring(7);
        } else if (value.endsWith(".desktop")) {
            var slash = value.lastIndexOf("/");
            desktopId = slash !== -1 ? value.substring(slash + 1) : value;
        }

        if (!desktopId) {
            return false;
        }

        _processRunner.connectSource("gtk-launch '" + desktopId.replace(/'/g, "'\\''") + "'");
        return true;
    }

    // --- Desktop file resolution and parsing ---

    readonly property var _desktopSearchDirs: {
        var dirs = [];
        // Derive user data dir from this plasmoid's installed path
        var myPath = Qt.resolvedUrl(".").toString();
        var idx = myPath.indexOf("/plasma/plasmoids/");
        if (idx > 0) {
            var userDataDir = myPath.substring(7, idx); // strip file://
            dirs.push(userDataDir + "/applications/");
        }
        dirs.push("/usr/share/applications/");
        dirs.push("/usr/local/share/applications/");
        dirs.push("/var/lib/flatpak/exports/share/applications/");
        if (idx > 0) {
            var userDataDir2 = myPath.substring(7, idx);
            var homeIdx = userDataDir2.indexOf("/.local/share");
            if (homeIdx > 0) {
                dirs.push(userDataDir2.substring(0, homeIdx) + "/.local/share/flatpak/exports/share/applications/");
            }
        }
        return dirs;
    }

    // Cache for desktop file contents: { "applications:foo.desktop": "content..." }
    property var _desktopFileCache: ({})

    function _tryNextDir(key) {
        var idx = (_searchState[key] || 0) + 1;
        _searchState[key] = idx;

        if (key.startsWith("applications:")) {
            var name = key.substring(13);
            if (idx < _desktopSearchDirs.length) {
                _startFileRead(key, _desktopSearchDirs[idx] + name);
            } else {
                // All dirs exhausted — mark as empty
                _desktopFileCache[key] = "";
                delete _searchState[key];
            }
        }
    }

    function _startFileRead(cacheKey, filePath) {
        // Use cat with shell-safe quoting
        var cmd = "cat '" + filePath.replace(/'/g, "'\\''") + "'";
        _pendingReads[cmd] = cacheKey;
        _fileReader.connectSource(cmd);
    }

    // Pre-cache desktop file content for a launcher URL
    function cacheDesktopFile(launcherUrl) {
        if (!launcherUrl) return;
        var key = launcherUrl.toString();
        if (!key.endsWith(".desktop")) return;
        if (_desktopFileCache[key] !== undefined) return; // already cached or in-flight
        if (_searchState[key] !== undefined) return; // search in progress

        var url = key;
        if (url.startsWith("file://")) {
            _desktopFileCache[key] = null; // mark in-flight
            _startFileRead(key, url.substring(7));
            return;
        }

        if (url.startsWith("applications:")) {
            var name = url.substring(13);
            _searchState[key] = 0;
            if (_desktopSearchDirs.length > 0) {
                _startFileRead(key, _desktopSearchDirs[0] + name);
            }
            return;
        }
    }

    function _parseDesktopActions(content) {
        var locale = Qt.locale().name;          // e.g. "en_US"
        var lang = locale.split("_")[0];          // e.g. "en"
        var lines = content.split("\n");
        var actionsLine = "";
        var sections = {};
        var currentSection = "";

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line.startsWith("[")) {
                currentSection = line;
                continue;
            }
            if (currentSection === "[Desktop Entry]" && line.startsWith("Actions=")) {
                actionsLine = line.substring(8);
            } else if (currentSection.startsWith("[Desktop Action ")) {
                var actionId = currentSection.substring(16, currentSection.length - 1);
                if (!sections[actionId]) sections[actionId] = { text: "", icon: "", exec: "" };

                if (line.startsWith("Name[" + locale + "]=")) {
                    sections[actionId].text = line.substring(6 + locale.length);
                } else if (line.startsWith("Name[" + lang + "]=") && !sections[actionId].text) {
                    sections[actionId].text = line.substring(6 + lang.length);
                } else if (line.startsWith("Name=") && !line.startsWith("Name[")) {
                    sections[actionId]._fallbackText = line.substring(5);
                } else if (line.startsWith("Icon=")) {
                    sections[actionId].icon = line.substring(5);
                } else if (line.startsWith("Exec=")) {
                    sections[actionId].exec = line.substring(5);
                }
            }
        }

        var actionIds = actionsLine.split(";").filter(Boolean);
        var result = [];
        for (var i = 0; i < actionIds.length; i++) {
            var action = sections[actionIds[i]];
            if (action) {
                if (!action.text) action.text = action._fallbackText || "";
                delete action._fallbackText;
                if (action.text) result.push(action);
            }
        }
        return result;
    }

    function _desktopEntryExec(launcherUrl) {
        if (!launcherUrl) return "";

        var key = launcherUrl.toString();
        var content = _desktopFileCache[key];
        if (!content) {
            cacheDesktopFile(launcherUrl);
            return "";
        }

        var lines = content.split("\n");
        var currentSection = "";

        for (var i = 0; i < lines.length; ++i) {
            var line = lines[i].trim();
            if (line.startsWith("[")) {
                currentSection = line;
                continue;
            }

            if (currentSection === "[Desktop Entry]" && line.startsWith("Exec=")) {
                return line.substring(5);
            }
        }

        return "";
    }

    function desktopEntryIcon(launcherUrl) {
        if (!launcherUrl) return "";

        var key = launcherUrl.toString();
        var content = _desktopFileCache[key];
        if (!content) {
            cacheDesktopFile(launcherUrl);
            return "";
        }

        var lines = content.split("\n");
        var currentSection = "";

        for (var i = 0; i < lines.length; ++i) {
            var line = lines[i].trim();
            if (line.startsWith("[")) {
                currentSection = line;
                continue;
            }

            if (currentSection === "[Desktop Entry]" && line.startsWith("Icon=")) {
                return line.substring(5);
            }
        }

        return "";
    }

    function requestNewInstance(index, launcherUrl) {
        if (launcherUrl) {
            var launcherPosition = tasksModel.launcherPosition(launcherUrl);
            if (launcherPosition !== -1) {
                tasksModel.requestNewInstance(tasksModel.makeModelIndex(launcherPosition));
                return;
            }

            if (launchDesktopEntry(launcherUrl)) {
                return;
            }

            var exec = _desktopEntryExec(launcherUrl);
            if (exec) {
                launchExec(exec);
                return;
            }
        }

        tasksModel.requestNewInstance(index);
    }

    function jumpListActions(launcherUrl, parent) {
        if (!launcherUrl) return [];
        var key = launcherUrl.toString();
        var content = _desktopFileCache[key];
        if (!content) {
            // Not cached yet — trigger async load for next time
            cacheDesktopFile(launcherUrl);
            return [];
        }
        return _parseDesktopActions(content);
    }

    // --- Places actions (for file managers) ---

    // Cache: { "applications:org.kde.dolphin.desktop": [ {text, icon, exec}, ... ] or null (in-flight) }
    property var _placesCache: ({})
    property var _placesCacheTime: ({})
    property var _placesPending: ({})
    property var _fileManagerCache: ({}) // storageId -> true/false/null(in-flight)

    readonly property P5Support.DataSource _placesReader: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            var stdout = (data["stdout"] || "").trim();
            var key = backend._placesPending[source];
            if (key !== undefined) {
                delete backend._placesPending[source];
                var results = [];
                if (stdout) {
                    var lines = stdout.split("\n");
                    for (var i = 0; i < lines.length; i++) {
                        var parts = lines[i].split("\t");
                        if (parts.length < 3) continue;
                        var icon = parts[0] || "folder";
                        var title = parts[1];
                        var href = parts[2];
                        results.push({
                            text: title,
                            icon: icon,
                            exec: "xdg-open '" + href.replace(/'/g, "'\\''") + "'"
                        });
                    }
                }
                backend._placesCache[key] = results;
                backend._placesCacheTime[key] = Date.now();
            }
            disconnectSource(source);
        }
    }

    function _isFileManager(launcherUrl) {
        if (!launcherUrl) return false;
        var key = launcherUrl.toString();
        var content = _desktopFileCache[key];
        if (!content) {
            cacheDesktopFile(launcherUrl);
            return false;
        }
        var lines = content.split("\n");
        var inEntry = false;
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line === "[Desktop Entry]") { inEntry = true; continue; }
            if (line.startsWith("[") && inEntry) break;
            if (inEntry && line.startsWith("Categories=")) {
                return line.indexOf("FileManager") !== -1;
            }
        }
        return false;
    }

    function _queryPlaces(cacheKey) {
        _placesCache[cacheKey] = null;
        var xbelPath = _recentDocsDbPath().replace(
            "/kactivitymanagerd/resources/database",
            "/user-places.xbel");
        var cmd = "python3 -c \""
            + "import xml.etree.ElementTree as ET\\n"
            + "tree = ET.parse('" + xbelPath.replace(/'/g, "'\\''") + "')\\n"
            + "ns = {'bookmark': 'http://www.freedesktop.org/standards/desktop-bookmarks'}\\n"
            + "for bm in tree.findall('.//bookmark'):\\n"
            + "    href = bm.get('href', '')\\n"
            + "    if not href.startswith('file://'): continue\\n"
            + "    title = bm.findtext('title', '')\\n"
            + "    icon_el = bm.find('.//bookmark:icon', ns)\\n"
            + "    icon = icon_el.get('name', '') if icon_el is not None else 'folder'\\n"
            + "    hidden = bm.findtext('.//{http://www.kde.org}IsHidden', 'false')\\n"
            + "    if hidden != 'true':\\n"
            + "        print(f'{icon}\\\\t{title}\\\\t{href}')\\n"
            + "\"";
        _placesPending[cmd] = cacheKey;
        _placesReader.connectSource(cmd);
    }

    function placesActions(launcherUrl, showAllPlaces, parent) {
        if (!launcherUrl) return [];

        if (!_isFileManager(launcherUrl)) return [];

        var cacheKey = launcherUrl.toString();
        var cached = _placesCache[cacheKey];
        var cacheTime = _placesCacheTime[cacheKey] || 0;
        var stale = (Date.now() - cacheTime) > 60000; // refresh every 60s

        if (cached === undefined || (cached !== null && stale)) {
            _queryPlaces(cacheKey);
            return [];
        }
        if (cached === null) return []; // in-flight

        if (!showAllPlaces && cached.length > 7) {
            return cached.slice(0, 5);
        }
        return cached;
    }

    // --- Recent document actions ---

    // Cache: { "org.kde.dolphin": [ {text, icon, exec}, ... ] or null (in-flight) }
    property var _recentDocsCache: ({})
    // Timestamp of last query per agent, to allow periodic refresh
    property var _recentDocsCacheTime: ({})

    readonly property P5Support.DataSource _recentDocsReader: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            var stdout = (data["stdout"] || "").trim();
            var agent = backend._recentDocsPending[source];
            if (agent !== undefined) {
                delete backend._recentDocsPending[source];
                var results = [];
                if (stdout) {
                    var lines = stdout.split("\n");
                    for (var i = 0; i < lines.length; i++) {
                        var path = lines[i].trim();
                        if (!path) continue;
                        var fileName = path.substring(path.lastIndexOf("/") + 1);
                        // Determine icon from mime by extension
                        var icon = "document-open-recent";
                        results.push({
                            text: fileName,
                            icon: icon,
                            exec: "xdg-open '" + path.replace(/'/g, "'\\''") + "'"
                        });
                    }
                }
                backend._recentDocsCache[agent] = results;
                backend._recentDocsCacheTime[agent] = Date.now();
            }
            disconnectSource(source);
        }
    }

    property var _recentDocsPending: ({})

    function _storageIdFromLauncherUrl(launcherUrl) {
        if (!launcherUrl) return "";
        var url = launcherUrl.toString().split("?")[0];
        var desktopId = "";
        if (url.startsWith("applications:")) {
            desktopId = url.substring(13);
        } else if (url.endsWith(".desktop")) {
            var lastSlash = url.lastIndexOf("/");
            desktopId = lastSlash !== -1 ? url.substring(lastSlash + 1) : url;
        }
        if (desktopId.endsWith(".desktop")) {
            desktopId = desktopId.substring(0, desktopId.length - 8);
        }
        return desktopId;
    }

    function _queryRecentDocs(storageId) {
        if (!storageId) return;
        // Mark as in-flight
        _recentDocsCache[storageId] = null;
        var dbPath = _recentDocsDbPath();
        if (!dbPath) return;
        // Query both with and without org.kde. prefix variants
        // Use sqlite3 to get recent file paths for this agent
        var cmd = "sqlite3 -separator $'\\n' '" + dbPath.replace(/'/g, "'\\''") + "' "
            + "\"SELECT DISTINCT targettedResource FROM ResourceScoreCache "
            + "WHERE (initiatingAgent = '" + storageId.replace(/'/g, "''") + "' "
            + "OR initiatingAgent = '" + storageId.replace(/'/g, "''").replace(/^.*\./, '') + "') "
            + "AND targettedResource LIKE '/%' "
            + "ORDER BY lastUpdate DESC LIMIT 6\"";
        _recentDocsPending[cmd] = storageId;
        _recentDocsReader.connectSource(cmd);
    }

    function _recentDocsDbPath() {
        var myPath = Qt.resolvedUrl(".").toString();
        var idx = myPath.indexOf("/.local/share/");
        if (idx > 0) {
            var home = myPath.substring(7, idx); // strip file://
            return home + "/.local/share/kactivitymanagerd/resources/database";
        }
        // fallback: use $HOME via shell expansion
        return "$HOME/.local/share/kactivitymanagerd/resources/database";
    }

    function recentDocumentActions(launcherUrl, parent) {
        var storageId = _storageIdFromLauncherUrl(launcherUrl);
        if (!storageId) return [];

        var cached = _recentDocsCache[storageId];
        var cacheTime = _recentDocsCacheTime[storageId] || 0;
        var stale = (Date.now() - cacheTime) > 30000; // refresh every 30s

        if (cached === undefined) {
            // Not queried yet — trigger async query and return empty for first load
            _queryRecentDocs(storageId);
            return [];
        }

        if (cached === null) {
            // Query in-flight
            return [];
        }

        // If we have cached results but they're stale, refresh in background
        // but return the cached list immediately so the menu isn't empty.
        if (stale) {
            _queryRecentDocs(storageId);
        }

        return cached;
    }

    function jsonArrayToUrlList(urls) {
        return urls || [];
    }

    function parentPid(pid) {
        return pid || 0;
    }

    function isApplication(item) {
        const value = item ? item.toString() : "";
        return value.endsWith(".desktop") || value.startsWith("applications:");
    }

    function applicationCategories(launcherUrl) {
        const value = launcherUrl ? launcherUrl.toString().toLowerCase() : "";
        const browsers = ["firefox", "chrome", "chromium", "brave", "vivaldi", "opera", "edge"];
        return browsers.some(function(browser) { return value.includes(browser); }) ? ["WebBrowser"] : [];
    }

    // --- Precaching ---

    property var _precachedUrls: ({})

    function precacheForLauncher(launcherUrl) {
        if (!launcherUrl) return;
        var key = launcherUrl.toString();
        if (_precachedUrls[key]) return;
        _precachedUrls[key] = true;

        // Trigger desktop file cache (needed for jump list + FileManager check)
        cacheDesktopFile(launcherUrl);

        // Trigger recent docs cache
        var storageId = _storageIdFromLauncherUrl(launcherUrl);
        if (storageId && _recentDocsCache[storageId] === undefined) {
            _queryRecentDocs(storageId);
        }

        // Trigger places cache (will self-check FileManager category once desktop file is loaded)
        if (_placesCache[key] === undefined) {
            // Delay places query slightly to let desktop file cache populate first
            _placesTimer.launcherUrl = key;
            _placesTimer.restart();
        }
    }

    readonly property Timer _placesTimer: Timer {
        property string launcherUrl: ""
        interval: 500
        repeat: false
        onTriggered: {
            if (launcherUrl && backend._isFileManager(launcherUrl)) {
                backend._queryPlaces(launcherUrl);
            }
        }
    }

    function precacheAllLaunchers(model) {
        if (!model) return;
        for (var i = 0; i < model.count; i++) {
            var idx = model.makeModelIndex(i);
            var url = model.data(idx, TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon);
            if (url && url.toString()) {
                precacheForLauncher(url);
            }
        }
    }

    function globalRect(item) {
        if (!item) {
            return Qt.rect(0, 0, 0, 0);
        }

        if (item.mapToGlobal) {
            const point = item.mapToGlobal(0, 0);
            return Qt.rect(point.x, point.y, item.width || 0, item.height || 0);
        }

        return Qt.rect(item.x || 0, item.y || 0, item.width || 0, item.height || 0);
    }
}
