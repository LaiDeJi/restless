// Driver for the done-state celebration: the burst appears when the last set
// completes, survives a re-render, does not block START AGAIN, and disappears
// after about 2.5 seconds. Run:
//   python3 tools/prototype-check.py tools/prototype-driver-celebration.js
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

  function mainText() {
    var el = document.querySelector(".btn-main");
    return el ? el.textContent.trim() : "";
  }

  function celebration() {
    return document.querySelector(".celebration");
  }

  setTimeout(function () {
    click('[data-act="tab-timer"]');
    click('[data-act="primary"]'); // START SESSION

    var guard = 0;
    while (mainText() === "SET DONE" && guard < 200) {
      click('[data-act="primary"]');
      click('[data-act="skip"]');
      guard += 1;
    }

    var doneMain = mainText();
    var atDone = celebration();
    var pieces = atDone ? atDone.querySelectorAll(".confetti").length : 0;
    var style = atDone ? window.getComputedStyle(atDone) : null;
    var result = [
      "setsClicked=" + guard,
      "doneMain=" + doneMain,
      "celebrationAtDone=" + !!atDone,
      "pieces=" + pieces,
      "pointerEvents=" + (style ? style.pointerEvents : "missing"),
      "hidden=" + (atDone ? atDone.getAttribute("aria-hidden") : "missing")
    ];

    // A re-render must not lose the effect or restart it from scratch.
    click('[data-act="tab-timer"]');
    result.push("survivesRerender=" + !!celebration());

    // START AGAIN stays usable during the burst: the overlay ignores taps.
    var startAgain = mainText();
    result.push("startAgainDuring=" + startAgain);

    setTimeout(function () {
      result.push(
        "celebrationAfter2s=" + !!celebration(),
        "doneMainAfter=" + mainText()
      );
      click('[data-act="primary"]'); // START AGAIN
      result.push(
        "restarted=" + (mainText() === "SET DONE"),
        "celebrationAfterRestart=" + !!celebration()
      );
      out.apply(null, result);
    }, 2600);
  }, 0);
})();
