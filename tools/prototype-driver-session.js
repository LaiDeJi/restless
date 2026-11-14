// Driver for the session-round-experience new-session default: the draft starts
// with one movement-less block, DONE and USE THIS SESSION stay disabled, and
// adding a movement enables both. Run:
//   python3 tools/prototype-check.py tools/prototype-driver-session.js
(function () {
  "use strict";

  function out() {
    var parts = [];
    for (var i = 0; i < arguments.length; i++) parts.push(String(arguments[i]));
    document.title = parts.join(" | ");
  }

  function click(selector) {
    var el = document.querySelector(selector);
    if (!el) return false;
    el.click();
    return true;
  }

  function storedSessions() {
    try {
      var raw = JSON.parse(localStorage.getItem("restless.sessions.v4"));
      var list = Array.isArray(raw) ? raw : (raw && raw.sessions) || [];
      return list.length;
    } catch (error) {
      return -1;
    }
  }

  function blocked(selector) {
    var el = document.querySelector(selector);
    return el ? String(el.disabled) : "missing";
  }

  function text(selector) {
    var el = document.querySelector(selector);
    return el ? el.textContent.replace(/\s+/g, " ").trim() : "missing";
  }

  setTimeout(function () {
    click('[data-act="tab-sessions"]');
    var sessionsBefore = storedSessions();
    click('[data-act="add-session"]');

    var emptyMeta = text(".block-row .br-meta");
    var emptyNote = text(".sheet-note");
    var hint = text(".sheet-warn");
    var doneEmpty = blocked('[data-act="done-session"]');
    var useEmpty = blocked('[data-act="use-session"]');

    // A disabled DONE must not save and must leave the draft open.
    click('[data-act="done-session"]');
    var stillDraft = document.querySelector('[data-el="sessionName"]') !== null;
    var savedByClick = storedSessions() - sessionsBefore;

    // Open the block, add the first library movement, return to the session.
    click('[data-act="open-block"]');
    var added = click('[data-act="add-from-library"]');
    click('[data-act="back-session"]');

    var filledMeta = text(".block-row .br-meta");
    var filledNote = text(".sheet-note");
    var doneFilled = blocked('[data-act="done-session"]');
    var useFilled = blocked('[data-act="use-session"]');
    var hintAfter = document.querySelector(".sheet-warn");

    out(
      "emptyMeta=" + emptyMeta,
      "emptyNote=" + emptyNote,
      "hint=" + hint,
      "doneEmpty=" + doneEmpty,
      "useEmpty=" + useEmpty,
      "stillDraft=" + stillDraft,
      "savedByClick=" + savedByClick,
      "added=" + added,
      "filledMeta=" + filledMeta,
      "filledNote=" + filledNote,
      "doneFilled=" + doneFilled,
      "useFilled=" + useFilled,
      "hintAfter=" + !!hintAfter
    );
  }, 0);
})();
