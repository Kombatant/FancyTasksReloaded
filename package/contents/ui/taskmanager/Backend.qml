import QtQuick 2.15
import org.kde.plasma.plasma5support 2.0 as P5Support

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

    function cancelHighlightWindows() {
    }

    function windowsHovered(winIds, hovered) {
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

    function placesActions(launcherUrl, showAllPlaces, parent) {
        return [];
    }

    function recentDocumentActions(launcherUrl, parent) {
        return [];
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