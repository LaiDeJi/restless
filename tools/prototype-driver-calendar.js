// Driver for the calendar prototype: the round-based rest gap, the closed
// session day, the weekday and dated exceptions, the skip mark, the per-date
// exercise change, the new round, the fixed Monday grid, and the reorder
// boundary. Run:
//   python3 tools/prototype-check.py tools/prototype-driver-calendar.js
// The page reloads once so the persisted anchor, skips and settings are read
// back through the same paths the app uses.
// Expected on the demo order Chest, Arms, Core: a gap of 1 plans Chest, Arms,
// Core then REST; a gap of 2 plans Chest, Arms, Core then two REST days; a
// closed or skipped session day keeps its place and the rest day stays.
(function () {
  "use strict";

  var STAGE_KEY = "restless.calendar.probe.stage";
  var LOG_KEY = "restless.calendar.probe.log";
  var SKIP_KEY = "restless.calendar.probe.skipped";
  var ANCHOR_KEY = "restless.calendar.probe.anchor";
  var CAL_KEY = "restless.calendar.v2";

  function $(selector, root) {
    return (root || document).querySelector(selector);
  }
  function $$(selector, root) {
    return Array.prototype.slice.call((root || document).querySelectorAll(selector));
  }
  function text(selector, root) {
    var el = $(selector, root);
    return el ? el.textContent.replace(/\s+/g, " ").trim() : "";
  }
  function click(selector, root) {
    var el = $(selector, root);
    if (!el) return false;
    el.click();
    return true;
  }
  function keyOf(date) {
    var pad = function (n) { return (n < 10 ? "0" : "") + n; };
    return date.getFullYear() + "-" + pad(date.getMonth() + 1) + "-" + pad(date.getDate());
  }
  function addDays(count) {
    var now = new Date();
    return new Date(now.getFullYear(), now.getMonth(), now.getDate() + count);
  }
  function keyPlus(count) { return keyOf(addDays(count)); }
  function cellFor(key) {
    return $('[data-act="open-cal-day"][data-key="' + key + '"]');
  }
  function cellMark(key) {
    var cell = cellFor(key);
    if (!cell) return "NO-CELL";
    var mark = $(".cal-mark", cell);
    return mark ? mark.textContent.trim() : "";
  }
  function cellFill(key) {
    var cell = cellFor(key);
    var bar = cell ? $(".cal-bar i", cell) : null;
    return bar ? bar.getAttribute("style") : "";
  }
  function weekdays() {
    return $$(".cal-weekday").map(function (el) { return el.textContent.trim(); }).join(" ");
  }
  function gapValue() { return text('[data-el="calGapValue"]'); }
  function stepGap(delta) {
    return click('[data-act="cal-gap-step"][data-value="' + delta + '"]');
  }
  function openDay(key) {
    return click('[data-act="open-cal-day"][data-key="' + key + '"]');
  }
  function sheetTag() { return text(".cal-sheet .cal-tag"); }
  function sheetTitle() { return text(".cal-sheet-title"); }
  function footer() {
    return $$(".cal-footer button").map(function (button) {
      return button.textContent.replace(/\s+/g, " ").trim();
    }).join(",");
  }
  function press(act) { return click('[data-act="' + act + '"]'); }
  function setInput(name, value) {
    var el = $('[data-el="' + name + '"]');
    if (!el) return false;
    el.value = value;
    el.dispatchEvent(new Event("input", { bubbles: true }));
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
  function sessionOrder() {
    click('[data-act="tab-sessions"]');
    var names = $$(".session-row .sc-name").map(function (el) { return el.textContent; });
    click('[data-act="tab-calendar"]');
    return names.join(",");
  }
  function savedCalendar() {
    try {
      return JSON.parse(localStorage.getItem(CAL_KEY) || "{}");
    } catch (e) {
      return {};
    }
  }
  function weekdayFull(number) {
    return ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"][number - 1];
  }

  var log = [];

  setTimeout(function () {
    var stage = sessionStorage.getItem(STAGE_KEY) || "main";

    if (stage === "reload") {
      var saved = JSON.parse(sessionStorage.getItem(LOG_KEY) || "[]");
      var skippedKey = sessionStorage.getItem(SKIP_KEY) || "";
      var anchorBefore = sessionStorage.getItem(ANCHOR_KEY) || "";
      click('[data-act="tab-calendar"]');
      var stored = savedCalendar();
      var reloaded = [
        "weekAfterReload=" + weekdays().split(" ")[0],
        "monthAfterReload=" + text(".cal-month-label"),
        "gapAfterReload=" + gapValue(),
        "restRowAfterReload=" + text('.cal-setting-row[data-kind="restDays"] .cal-setting-value'),
        "exceptionsRowAfterReload=" + text('.cal-setting-row[data-kind="exceptions"] .cal-setting-value'),
        "orderAfterReload=" + sessionOrder(),
        "skipMarkAfterReload=" + cellMark(skippedKey),
        "storedVersion=" + stored.v,
        "storedGap=" + stored.restDaysBetween,
        "storedSkips=" + (stored.skippedDays || []).length,
        "storedChanges=" + (stored.dayChanges || []).length,
        "anchorKeptBySkip=" + (stored.anchor === anchorBefore)
      ];

      openDay(skippedKey);
      press("cal-unskip");
      reloaded.push(
        "unskippedMark=" + cellMark(skippedKey),
        "unskippedSheetStaysOpen=" + !!$(".cal-sheet")
      );

      var up = 0;
      while (up < 9) { stepGap(1); up += 1; }
      var gapMax = gapValue();
      var down = 0;
      while (down < 10) { stepGap(-1); down += 1; }
      var gapMin = gapValue();
      reloaded.push("gapMax=" + gapMax, "gapMin=" + gapMin);

      document.title = saved.concat(reloaded).join(" | ");
      return;
    }

    // 1. The tab, the fixed Monday grid, and the marks.
    click('[data-act="tab-calendar"]');
    var tabs = $$(".tabbar button").map(function (button) {
      return button.querySelector("span").textContent.trim();
    }).join(",");
    var todayKey = keyPlus(0);
    var tomorrowKey = keyPlus(1);
    var recordCell = $(".cal-mark.record");
    var recordKey = recordCell ? recordCell.closest("[data-key]").getAttribute("data-key") : "";
    var pastKey = keyPlus(-1);
    var adjacent = $$(".cal-cell.adjacent");
    var adjacentInert = adjacent.every(function (cell) {
      return !cell.hasAttribute("data-act") && cell.tagName !== "BUTTON";
    });
    log.push(
      "tabs=" + tabs,
      "monthLabel=" + text(".cal-month-label"),
      "weekdays=" + weekdays(),
      "weekFirst=" + weekdays().split(" ")[0],
      "noWeekStartRow=" + !$('[data-kind="weekStart"]'),
      "todayRing=" + !!$(".cal-cell.today"),
      "adjacentInert=" + adjacentInert,
      "chips=" + $$(".cal-chip").map(function (chip) { return chip.textContent.trim(); }).join(","),
      "upNext=" + text(".cal-upnext"),
      "settingRows=" + $$(".cal-setting-label").map(function (el) { return el.textContent.trim(); }).join(","),
      "gapInitial=" + gapValue(),
      "restRowValue=" + text('.cal-setting-row[data-kind="restDays"] .cal-setting-value'),
      "exceptionsRow=" + text('.cal-setting-row[data-kind="exceptions"] .cal-setting-value')
    );

    // 2. The rest gap: one day between sessions leaves alternating REST days.
    stepGap(1);
    log.push(
      "gapOne=" + gapValue(),
      "gapOneToday=" + cellMark(keyPlus(0)),
      "gapOneTomorrow=" + cellMark(tomorrowKey),
      "gapOneDay2=" + cellMark(keyPlus(2)),
      "gapOneDay3=" + cellMark(keyPlus(3)),
      "gapOneDay4=" + cellMark(keyPlus(4)),
      "restCellsAtOne=" + $$(".cal-mark.word").filter(function (el) {
        return el.textContent.trim() === "REST";
      }).length
    );
    stepGap(-1);
    log.push("gapBackToZero=" + gapValue(), "gapZeroTomorrow=" + cellMark(tomorrowKey));

    // 2b. A gap of 2 leaves two rest days after the round's last session.
    stepGap(1);
    stepGap(1);
    log.push(
      "gapTwo=" + gapValue(),
      "gapTwoDay2=" + cellMark(keyPlus(2)),
      "gapTwoDay3=" + cellMark(keyPlus(3)),
      "gapTwoDay4=" + cellMark(keyPlus(4)),
      "gapTwoDay5=" + cellMark(keyPlus(5))
    );
    stepGap(-1);
    stepGap(-1);
    log.push("gapBackToZeroAfterTwo=" + gapValue());

    // 3. With a gap of 1 a closure of two session days leaves their places and
    // the round's rest day, and the next open day carries the next session.
    stepGap(1);
    click('[data-act="open-cal-setting"][data-kind="exceptions"]');
    log.push(
      "exceptionModes=" + $$(".cal-mode").map(function (el) { return el.textContent.trim(); }).join(","),
      "datedForm=" + (!!$('[data-el="calStart"]') && !!$('[data-el="calEnd"]'))
    );
    setInput("calStart", keyPlus(1));
    setInput("calEnd", keyPlus(2));
    setInput("calLabel", "Gym closed");
    press("cal-add-exception");
    log.push(
      "exceptionRows=" + $$(".cal-exception").length,
      "exceptionLabel=" + text(".cal-exception-label"),
      "exceptionDays=" + text(".cal-exception-days")
    );
    press("close-cal-sheet");
    log.push(
      "closedDay1=" + cellMark(keyPlus(1)),
      "closedDay2=" + cellMark(keyPlus(2)),
      "closedRestDay=" + cellMark(keyPlus(3)),
      "day4AfterClosure=" + cellMark(keyPlus(4)),
      "day5AfterClosure=" + cellMark(keyPlus(5))
    );

    // 4. Both exception kinds share one list; a weekday closes every match.
    var tomorrowNumber = addDays(1).getDay() + 1;
    click('[data-act="open-cal-setting"][data-kind="exceptions"]');
    click('.cal-mode[data-value="weekday"]');
    click('.cal-option[data-value="' + tomorrowNumber + '"]');
    setInput("calLabel", "Travel");
    press("cal-add-exception");
    log.push(
      "exceptionRows=" + $$(".cal-exception").length,
      "exceptionLabels=" + $$(".cal-exception-label").map(function (el) { return el.textContent.trim(); }).join(","),
      "exceptionDays=" + $$(".cal-exception-days").map(function (el) { return el.textContent.trim(); }).join(",")
    );
    press("cal-add-exception");
    log.push(
      "duplicateWeekdayError=" + text(".cal-sheet-note"),
      "afterDuplicate=" + $$(".cal-exception").length
    );
    press("close-cal-sheet");
    log.push(
      "weekdayClosesTomorrow=" + cellMark(tomorrowKey),
      "weekdayClosesNextWeek=" + cellMark(keyPlus(8)),
      "weekdayNextPlan=" + cellMark(keyPlus(4))
    );
    click('[data-act="open-cal-setting"][data-kind="exceptions"]');
    var guard = 0;
    while ($(".cal-exception-delete") && guard < 8) {
      click(".cal-exception-delete");
      guard += 1;
    }
    var rowsLeft = $$(".cal-exception").length;
    press("close-cal-sheet");
    log.push(
      "afterRemoveRows=" + rowsLeft,
      "weekdayRemovedTomorrow=" + cellMark(tomorrowKey),
      "day2AfterRemove=" + cellMark(keyPlus(2)),
      "day3AfterRemove=" + cellMark(keyPlus(3))
    );
    // 5. SKIP hides the plan, leaves the next day, and UNSKIP restores it.
    openDay(tomorrowKey);
    log.push(
      "plannedTitle=" + sheetTitle(),
      "plannedTag=" + (sheetTag() || "NONE"),
      "plannedStart=" + $$('.cal-sheet [data-act="cal-start"]').length,
      "plannedFooter=" + footer()
    );
    press("cal-skip");
    log.push(
      "skippedMark=" + cellMark(tomorrowKey),
      "skippedNextDay=" + cellMark(keyPlus(2)),
      "skippedSheetStaysOpen=" + !!$(".cal-sheet"),
      "skippedTitle=" + sheetTitle(),
      "skippedTag=" + sheetTag(),
      "skippedStart=" + $$('.cal-sheet [data-act="cal-start"]').length,
      "skippedFooter=" + footer(),
      "skippedNextText=" + text(".cal-next")
    );
    press("cal-unskip");
    log.push(
      "unskippedMark=" + cellMark(tomorrowKey),
      "unskippedSheetStaysOpen=" + !!$(".cal-sheet"),
      "unskippedTitle=" + sheetTitle(),
      "unskippedStart=" + $$('.cal-sheet [data-act="cal-start"]').length
    );
    press("close-cal-sheet");

    // 6. CHANGE plans another session on the date and leaves the next date.
    openDay(tomorrowKey);
    press("cal-open-change");
    log.push(
      "pickerTitle=" + text(".cal-sheet .cal-sheet-kicker"),
      "pickerRows=" + $$(".cal-picker-name").map(function (el) { return el.textContent; }).join(","),
      "pickerScheduled=" + text(".cal-picker-row .cal-tag"),
      "pickerChecked=" + text(".cal-picker-row .cal-picker-check")
    );
    click('.cal-picker-row[data-id="s-chest"]');
    log.push(
      "changedGridTomorrow=" + cellMark(tomorrowKey),
      "changedNextGrid=" + cellMark(keyPlus(2)),
      "changedTitle=" + sheetTitle(),
      "changedTag=" + sheetTag()
    );
    press("cal-open-change");
    click('.cal-picker-row[data-id="s-arms"]');
    log.push(
      "clearedGridTomorrow=" + cellMark(tomorrowKey),
      "clearedNextGrid=" + cellMark(keyPlus(2)),
      "clearedTitle=" + sheetTitle(),
      "clearedTag=" + (sheetTag() || "NONE")
    );
    press("close-cal-sheet");

    // 7. A new round on a future rest day re-phases the codes and clears facts.
    openDay(keyPlus(3));
    log.push(
      "restTitle=" + sheetTitle(),
      "restMeta=" + text(".cal-sheet-meta"),
      "restStart=" + $$('.cal-sheet [data-act="cal-start"]').length,
      "restFooter=" + footer()
    );
    press("cal-new-round");
    var afterRound = savedCalendar();
    log.push(
      "roundDay3=" + cellMark(keyPlus(3)),
      "roundDay4=" + cellMark(keyPlus(4)),
      "roundDay5=" + cellMark(keyPlus(5)),
      "roundDay6=" + cellMark(keyPlus(6)),
      "roundDay7=" + cellMark(keyPlus(7)),
      "roundSkips=" + (afterRound.skippedDays || []).length,
      "roundChanges=" + (afterRound.dayChanges || []).length,
      "roundAnchor=" + afterRound.anchor
    );

    // 8. A past date and a past record offer no round; a future rest day does.
    openDay(pastKey);
    log.push(
      "pastKey=" + pastKey,
      "pastTitle=" + sheetTitle(),
      "pastFooter=" + (footer() || "NONE")
    );
    press("close-cal-sheet");
    openDay(recordKey);
    log.push(
      "recordTitle=" + sheetTitle(),
      "recordTag=" + sheetTag(),
      "recordTime=" + text(".cal-record-block"),
      "recordInputs=" + $$(".cal-sheet input").length,
      "recordStart=" + $$('.cal-sheet [data-act="cal-start"]').length,
      "recordFooter=" + footer()
    );
    press("close-cal-sheet");
    openDay(keyPlus(6));
    log.push("futureRestFooter=" + footer());
    press("close-cal-sheet");

    // 9. The reorder boundary: a past record is fixed, the next slot restarts.
    var recordTextBefore = cellMark(recordKey);
    var recordFillBefore = cellFill(recordKey);
    click('[data-act="tab-sessions"]');
    var orderBefore = $$(".session-row .sc-name").map(function (el) { return el.textContent; }).join(",");
    drag("s-core", "s-chest");
    click('[data-act="tab-calendar"]');
    log.push(
      "orderBefore=" + orderBefore,
      "orderAfter=" + sessionOrder(),
      "reorderDay3=" + cellMark(keyPlus(3)),
      "reorderDay4=" + cellMark(keyPlus(4)),
      "reorderDay5=" + cellMark(keyPlus(5)),
      "reorderDay6=" + cellMark(keyPlus(6)),
      "pastRecordBefore=" + recordTextBefore,
      "pastRecordAfter=" + cellMark(recordKey),
      "pastFillBefore=" + recordFillBefore,
      "pastFillAfter=" + cellFill(recordKey)
    );

    // 10. START opens TIMER at the gate; a run with a set asks first.
    var startKey = keyPlus(4);
    openDay(startKey);
    press("cal-start");
    var gatePrimary = text(".btn-main");
    var tabAfterStart = text(".tabbar button.on span");
    click('[data-act="primary"]');
    click('[data-act="primary"]');
    click('[data-act="tab-calendar"]');
    openDay(startKey);
    press("cal-start");
    log.push(
      "gatePrimary=" + gatePrimary,
      "tabAfterStart=" + tabAfterStart,
      "confirmTitle=" + sheetTitle(),
      "confirmAction=" + text(".cal-primary")
    );
    press("close-cal-sheet");
    log.push("confirmCancelled=" + !$(".cal-sheet"));

    // 11. Leave a future skip for the reload stage to read back.
    var skipKey = keyPlus(5);
    var beforeSkip = savedCalendar();
    openDay(skipKey);
    press("cal-skip");
    var afterSkip = savedCalendar();
    sessionStorage.setItem(SKIP_KEY, skipKey);
    sessionStorage.setItem(ANCHOR_KEY, beforeSkip.anchor || "");
    log.push(
      "skipBeforeReload=" + cellMark(skipKey),
      "anchorKeptInPlace=" + (beforeSkip.anchor === afterSkip.anchor),
      "skipsInPlace=" + (afterSkip.skippedDays || []).length
    );

    sessionStorage.setItem(LOG_KEY, JSON.stringify(log));
    sessionStorage.setItem(STAGE_KEY, "reload");
    location.reload();
  }, 0);
})();
