import QtQuick 2.15

QtObject {
    id: dragHelper

    property int dragIconSize: 0

    signal dropped()

    function isDrag(pressX, pressY, mouseX, mouseY) {
        const deltaX = mouseX - pressX;
        const deltaY = mouseY - pressY;
        return Math.sqrt(deltaX * deltaX + deltaY * deltaY) >= 8;
    }

    function startDrag(source, mimeType, mimeData, launcherUrl, decoration) {
        dropped();
    }
}