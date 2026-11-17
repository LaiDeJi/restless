// Driver for the dotted transition rest copy: a movement-switch rest reads
// NEXT · <movement> and a block-transition rest reads NEXT · <block>, with
// no AFTER text. Run:
//   python3 tools/prototype-check.py tools/prototype-driver-rest-label.js
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

  function seed() {
    function movement(id, name) {
      return { id: id, name: name, group: name, defaultCondition: "manual", defaultTarget: null };
    }
    function row(id, movementId) {
      return { id: id, movementId: movementId, endCondition: "manual", target: null };
    }
    var data = {
      v: 4,
      activeId: "s-split",
      movements: [
        movement("m-biceps", "Biceps"),
        movement("m-triceps", "Triceps"),
        movement("m-bench", "Bench")
      ],
      sessions: [
        {
          id: "s-split",
          name: "Split",
          blocks: [
            {
              id: "b-arms",
              name: "Arms",
              rounds: 1,
              setsPerRound: 1,
              setRest: 60,
              roundRest: 90,
              movements: [row("bm-biceps", "m-biceps"), row("bm-triceps", "m-triceps")]
            },
            {
              id: "b-chest",
              name: "Chest",
              rounds: 1,
              setsPerRound: 1,
              setRest: 60,
              roundRest: 90,
              movements: [row("bm-bench", "m-bench")]
            }
          ]
        }
      ]
    };
    localStorage.setItem(KEY, JSON.stringify(data));
  }

  setTimeout(function () {
    if (sessionStorage.getItem(STAGE_KEY) !== "walk") {
      seed();
      sessionStorage.setItem(STAGE_KEY, "walk");
      location.reload();
      return;
    }

    click('[data-act="tab-timer"]');
    click('[data-act="primary"]');           // START SESSION — Biceps set
    click('[data-act="primary"]');           // SET DONE — movement-switch rest

    var movementLabel = text('[data-el="sub"]');
    var bits = [
      "movementRest=" + movementLabel,
      "movementPass=" + (movementLabel === "NEXT · TRICEPS" ? "PASS" : "FAIL"),
      "noAfterPass=" + (movementLabel.indexOf("AFTER") === -1 ? "PASS" : "FAIL"),
      "kicker=" + text('[data-el="kicker"]')
    ];

    var skip = document.querySelector('[data-act="skip"]');
    if (skip) skip.click();                  // into the Triceps set
    click('[data-act="primary"]');           // SET DONE — block-transition rest

    var blockLabel = text('[data-el="sub"]');
    bits.push("blockRest=" + blockLabel);
    bits.push("blockPass=" + (blockLabel === "NEXT · CHEST" ? "PASS" : "FAIL"));
    bits.push("blockNoAfterPass=" + (blockLabel.indexOf("AFTER") === -1 ? "PASS" : "FAIL"));

    out.apply(null, bits);
  }, 0);
})();
