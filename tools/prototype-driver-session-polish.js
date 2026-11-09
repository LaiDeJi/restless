// Driver for the session-polish prototype change: 40-character names, session
// drag order with a reload, the restart dialog, and the simulated completion
// alert. Run:
//   python3 tools/prototype-check.py tools/prototype-driver-session-polish.js --budget 90000
(function () {
  "use strict";

  var STAGE_KEY = "restless.probe.stage";
  var CAP_KEY = "restless.probe.cap";
  var SAVED_KEY = "restless.probe.saved";
  var LONG_NAME = "Single-arm cable lateral raise for the rear delt";

  function out() {
    var parts = [];
    for (var i = 0; i < arguments.length; i++) parts.push(String(arguments[i]));
    document.title = parts.join(" | ");
  }

  function names() {
    return Array.prototype.map.call(
      document.querySelectorAll(".session-row .sc-name"),
      function (el) { return el.textContent; }
    ).join(",");
  }

  function posText() {
    var strip = document.querySelector(".pos");
    return strip ? strip.textContent.replace(/ +/g, " ").trim() : "";
  }

  function primaryText() {
    var main = document.querySelector(".btn-main");
    return main ? main.textContent.trim() : "";
  }

  function click(selector) {
    var el = document.querySelector(selector);
    if (!el) return false;
    el.click();
    return true;
  }

  function drag(fromId, toId) {
    var handle = document.querySelector(
      '[data-drag-handle="session"][data-id="' + fromId + '"]'
    );
    var target = document.querySelector(
      '[data-drag-row="session"][data-id="' + toId + '"]'
    );
    if (!handle || !target) return false;
    var data = new DataTransfer();
    handle.dispatchEvent(new DragEvent("dragstart", { bubbles: true, dataTransfer: data }));
    target.dispatchEvent(new DragEvent("dragover", {
      bubbles: true, cancelable: true, dataTransfer: data
    }));
    target.dispatchEvent(new DragEvent("drop", {
      bubbles: true, cancelable: true, dataTransfer: data
    }));
    return true;
  }

  setTimeout(function () {
    var stage = sessionStorage.getItem(STAGE_KEY) || "order";

    if (stage === "order") {
      // 1. A 50-character name is capped at 40 by the field's maxlength and on
      // save; the saved card shows the whole 40.
      click('[data-act="tab-sessions"]');
      click('[data-act="add-session"]');
      var input = document.querySelector('[data-el="sessionName"]');
      var cap = input.getAttribute("maxlength");
      input.value = LONG_NAME + " and more text";
      input.dispatchEvent(new Event("input", { bubbles: true }));
      click('[data-act="done-session"]');
      var cards = document.querySelectorAll(".session-row .sc-name");
      var savedLength = cards.length ? cards[cards.length - 1].textContent.length : 0;
      sessionStorage.setItem(CAP_KEY, cap);
      sessionStorage.setItem(SAVED_KEY, String(savedLength));

      // 2. Drag Core above Chest, then reload to prove the order persisted.
      drag("s-core", "s-chest");
      sessionStorage.setItem(STAGE_KEY, "alert");
      location.reload();
      return;
    }

    // 3. After the reload the order came from storage.
    var cap = sessionStorage.getItem(CAP_KEY);
    var savedLength = sessionStorage.getItem(SAVED_KEY);
    click('[data-act="tab-sessions"]');
    var reloaded = names();
    click('[data-act="tab-timer"]');

    // 4. Start the first set, finish it, and let the 60 s set rest expire.
    click('[data-act="primary"]');   // START SESSION
    click('[data-act="primary"]');   // SET DONE -> resting 1:00

    var waited = 0;
    var poll = setInterval(function () {
      waited += 100;
      var card = document.querySelector(".alert-card");
      if (!card) {
        if (waited > 90000) {
          clearInterval(poll);
          out("cap=" + cap, "savedLength=" + savedLength,
              "reloaded=" + reloaded, "ALERT TIMEOUT", "pos=" + posText());
        }
        return;
      }
      clearInterval(poll);
      var island = document.querySelector("#island");
      var alertBits = [
        "cap=" + cap,
        "savedLength=" + savedLength,
        "reloaded=" + reloaded,
        "waited=" + waited,
        "alertTitle=" + card.querySelector(".alert-title").textContent,
        "alertBody=" + card.querySelector(".alert-body").textContent,
        "islandExpanded=" + island.classList.contains("expanded"),
        "islandWidth=" + island.style.width,
        "notificationCard=" + !!card
      ];

      // 5. The restart dialog: cancel changes nothing, confirm returns to the
      // start gate with no session running.
      var before = posText();
      var primaryBefore = primaryText();
      click('[data-act="restart"]');
      var dialog = document.querySelector(".confirm");
      var opened = !!dialog;
      var title = dialog ? dialog.querySelector(".confirm-title").textContent : "";
      var body = dialog ? dialog.querySelector(".confirm-body").textContent : "";
      click('[data-act="restart-cancel"]');
      var cancelled = !document.querySelector(".confirm");
      var afterCancel = posText();
      var primaryAfterCancel = primaryText();

      click('[data-act="restart"]');
      click('[data-act="restart-confirm"]');
      var afterConfirm = posText();
      var primaryAfterConfirm = primaryText();
      var confirmGone = !document.querySelector(".confirm");

      out.apply(null, alertBits.concat([
        "before=" + before,
        "primaryBefore=" + primaryBefore,
        "dialogOpened=" + opened,
        "title=" + title,
        "body=" + body,
        "cancelled=" + cancelled,
        "afterCancel=" + afterCancel,
        "primaryAfterCancel=" + primaryAfterCancel,
        "confirmGone=" + confirmGone,
        "afterConfirm=" + afterConfirm,
        "primaryAfterConfirm=" + primaryAfterConfirm
      ]));
    }, 100);
  }, 0);
})();
