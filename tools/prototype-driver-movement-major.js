// Driver for the movement-major-rounds prototype change: run order inside a
// block, the rest at a movement switch, block totals, the map rows, and the
// removed rounds floor. Run:
//   python3 tools/prototype-check.py tools/prototype-driver-movement-major.js --budget 90000
(function () {
  "use strict";

  var STAGE_KEY = "restless.probe.stage";
  var KEY = "restless.sessions.v4";

  function out() {
    var parts = [];
    for (var i = 0; i < arguments.length; i++) parts.push(String(arguments[i]));
    document.title = parts.join(" | ");
  }

  function text(selector) {
    var el = document.querySelector(selector);
    return el ? el.textContent.replace(/ +/g, " ").trim() : "";
  }

  function click(selector) {
    var el = document.querySelector(selector);
    if (!el) return false;
    el.click();
    return true;
  }

  function disabled(selector) {
    var el = document.querySelector(selector);
    return !el || el.disabled;
  }

  function cardMeta(id) {
    var card = document.querySelector('[data-act="open-session"][data-id="' + id + '"]');
    if (!card) return "";
    var meta = card.querySelector(".sc-meta");
    return meta ? meta.textContent.replace(/ +/g, " ").trim() : "";
  }

  function mapRows() {
    var rows = [];
    Array.prototype.forEach.call(document.querySelectorAll(".map-row"), function (row) {
      rows.push({
        label: row.querySelector(".map-label") ? row.querySelector(".map-label").textContent : "",
        dots: row.querySelectorAll(".map-dot").length,
        gaps: row.querySelectorAll(".map-gap").length,
        active: row.classList.contains("active"),
        movement: row.getAttribute("data-m"),
        round: row.getAttribute("data-r")
      });
    });
    return rows;
  }

  function rowSignature(rows) {
    return rows.map(function (row) {
      return row.label + ":" + row.dots + (row.gaps ? "g" : "") + (row.active ? "*" : "");
    }).join(",");
  }

  function seed() {
    function movement(id, name) {
      return { id: id, name: name, group: name, defaultCondition: "manual", defaultTarget: null };
    }
    function row(id, movementId) {
      return { id: id, movementId: movementId, endCondition: "manual", target: null };
    }
    var data = {
      v: 4,
      activeId: "s-arms",
      movements: [
        movement("m-biceps", "Biceps"),
        movement("m-triceps", "Triceps"),
        movement("m-bench", "Bench"),
        movement("m-curl", "Curl")
      ],
      sessions: [
        {
          id: "s-arms",
          name: "Arms",
          blocks: [{
            id: "b-arms",
            name: "Arms",
            rounds: 3,
            setsPerRound: 2,
            setRest: 60,
            roundRest: 120,
            movements: [row("bm-biceps", "m-biceps"), row("bm-triceps", "m-triceps")]
          }]
        },
        {
          id: "s-bench",
          name: "Bench",
          blocks: [{
            id: "b-bench",
            name: "Bench",
            rounds: 4,
            setsPerRound: 4,
            setRest: 60,
            roundRest: 120,
            movements: [row("bm-bench", "m-bench")]
          }]
        },
        {
          id: "s-core",
          name: "Core",
          blocks: [{
            id: "b-core",
            name: "Core",
            rounds: 1,
            setsPerRound: 3,
            setRest: 60,
            roundRest: 120,
            movements: [row("bm-plank", "m-bench")]
          }]
        }
      ]
    };
    localStorage.setItem(KEY, JSON.stringify(data));
  }

  function walkArms() {
    var bits = [];
    click('[data-act="tab-timer"]');
    click('[data-act="primary"]');           // START SESSION
    bits.push("start=" + text(".pos"));

    for (var set = 1; set <= 6; set++) {
      click('[data-act="primary"]');         // SET DONE
      bits.push("set" + set + "=" + text('[data-el="kicker"]') + "/" + text('[data-el="sub"]'));
      if (set === 1) bits.push("afterFirst=" + text(".pos"));
      if (set === 6) {
        bits.push("afterSix=" + text(".pos"));
        var rows = mapRows();
        bits.push("rows=" + rows.length);
        bits.push("dots=" + rows.map(function (row) { return row.dots; }).join(""));
        bits.push("gaps=" + rows.map(function (row) { return row.gaps; }).join(""));
        bits.push("map=" + rowSignature(rows));
        bits.push("activeRow=" + rows.filter(function (row) { return row.active; })
          .map(function (row) { return row.movement + "/" + row.round; }).join(","));
      }
      var skip = document.querySelector('[data-act="skip"]');
      if (skip) skip.click();
    }

    click('[data-act="primary"]');           // seventh set: first Triceps set
    bits.push("set7=" + text('[data-el="kicker"]') + "/" + text('[data-el="sub"]'));
    bits.push("triceps=" + text(".pos"));
    var skip7 = document.querySelector('[data-act="skip"]');
    if (skip7) skip7.click();
    return bits;
  }

  function walkBench() {
    click('[data-act="tab-sessions"]');
    click('[data-act="open-session"][data-id="s-bench"]');
    click('[data-act="use-session"]');
    click('[data-act="primary"]');           // START SESSION
    var rows = mapRows();
    return [
      "benchRows=" + rows.length,
      "benchDots=" + rows.map(function (row) { return row.dots; }).join(""),
      "benchMap=" + rowSignature(rows)
    ];
  }

  setTimeout(function () {
    if (sessionStorage.getItem(STAGE_KEY) !== "walk") {
      seed();
      sessionStorage.setItem(STAGE_KEY, "walk");
      location.reload();
      return;
    }

    var bits = [];
    click('[data-act="tab-sessions"]');
    bits.push("armsCard=" + cardMeta("s-arms"));
    bits.push("benchCard=" + cardMeta("s-bench"));

    // The rounds floor is gone: a second movement leaves a one-round block at 1.
    click('[data-act="open-session"][data-id="s-core"]');
    click('[data-act="open-block"][data-id="b-core"]');
    var before = text('[data-act="edit-number"][data-key="rounds"]');
    click('[data-act="add-from-library"][data-id="m-curl"]');
    var after = text('[data-act="edit-number"][data-key="rounds"]');
    bits.push("roundsBefore=" + before);
    bits.push("roundsAfter=" + after);
    bits.push("minusDisabled=" + disabled('[data-act="bump-block"][data-key="rounds"][data-dir="-1"]'));

    bits = bits.concat(walkArms());
    bits = bits.concat(walkBench());
    out.apply(null, bits);
  }, 0);
})();
