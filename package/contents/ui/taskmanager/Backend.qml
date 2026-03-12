import QtQuick 2.15

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

    function placesActions(launcherUrl, showAllPlaces, parent) {
        return [];
    }

    function recentDocumentActions(launcherUrl, parent) {
        return [];
    }

    function jumpListActions(launcherUrl, parent) {
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