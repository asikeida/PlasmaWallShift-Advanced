// SPDX-License-Identifier: GPL-3.0-or-later

.pragma library

var imagePattern = /\.(jpe?g|png|webp|bmp)$/i;
var videoPattern = /\.(mp4|m4v|webm|mkv|mov)$/i;

function kindForPath(path) {
    var value = String(path || "");
    if (imagePattern.test(value))
        return "image";
    if (videoPattern.test(value))
        return "video";
    return "unsupported";
}

function isSupportedPath(path, includeImages, includeVideos) {
    var kind = kindForPath(path);
    return (includeImages && kind === "image") || (includeVideos && kind === "video");
}

function makeEntry(path, name, modified, url) {
    return {
        "path": String(path || ""),
        "url": String(url || path || ""),
        "name": String(name || path || ""),
        "modified": Number(modified || 0),
        "kind": kindForPath(path)
    };
}

function nameFilters(includeImages, includeVideos) {
    var filters = [];
    if (includeImages)
        filters = filters.concat(["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp", "*.JPG", "*.JPEG", "*.PNG", "*.WEBP", "*.BMP"]);
    if (includeVideos)
        filters = filters.concat(["*.mp4", "*.m4v", "*.webm", "*.mkv", "*.mov", "*.MP4", "*.M4V", "*.WEBM", "*.MKV", "*.MOV"]);
    return filters.length > 0 ? filters : ["__wallshift_no_media__"];
}
