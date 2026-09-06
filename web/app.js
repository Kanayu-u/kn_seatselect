/*
 * kn_seatselect / NUI
 *
 * Lua からのメッセージ:
 *   { action: 'hint',  visible: bool, text: string }
 *   { action: 'open',  closeHint, occupiedLabel, seats: [{ index, label, free }] }
 *   { action: 'close' }
 *
 * Lua へ返すコールバック:
 *   selectSeat { seat: <GTA の座席インデックス> }
 *   closeUi
 */

(function () {
    "use strict";

    var hintEl = document.getElementById("hint");
    var overlayEl = document.getElementById("overlay");
    var panelEl = document.getElementById("panel");
    var footEl = document.getElementById("panel-foot");
    var seatsEl = document.getElementById("seats");

    var isOpen = false;
    var hintWanted = false;
    var selectableSeats = []; // 数字キー選択用 (空席のみ)

    function post(name, payload) {
        return fetch("https://" + GetParentResourceName() + "/" + name, {
            method: "POST",
            headers: { "Content-Type": "application/json; charset=UTF-8" },
            body: JSON.stringify(payload || {})
        }).catch(function () {
            /* ブラウザ単体で開いた場合など。UI 側の状態は既に更新済み */
        });
    }

    function syncHint() {
        // ヒントと座席リストは同じ位置に出るので排他にする
        hintEl.hidden = !hintWanted || isOpen;
    }

    function hide() {
        if (!isOpen) {
            return;
        }
        isOpen = false;
        panelEl.hidden = true;
        overlayEl.hidden = true;
        seatsEl.innerHTML = "";
        selectableSeats = [];
        syncHint();
    }

    function selectSeat(seatIndex) {
        hide();
        post("selectSeat", { seat: seatIndex });
    }

    function closeUi() {
        hide();
        post("closeUi");
    }

    function buildSeat(seat, hotkey, occupiedLabel) {
        var button = document.createElement("button");
        button.type = "button";
        button.className = "seat" + (seat.free ? "" : " is-occupied");
        button.disabled = !seat.free;

        var key = document.createElement("span");
        key.className = "seat-key";
        key.textContent = hotkey === null ? "" : String(hotkey);
        button.appendChild(key);

        var label = document.createElement("span");
        label.className = "seat-label";
        label.textContent = seat.label;
        button.appendChild(label);

        if (!seat.free) {
            var state = document.createElement("span");
            state.className = "seat-state";
            state.textContent = occupiedLabel;
            button.appendChild(state);
        } else {
            button.addEventListener("click", function () {
                selectSeat(seat.index);
            });
        }

        return button;
    }

    function open(data) {
        var seats = Array.isArray(data.seats) ? data.seats : [];

        footEl.textContent = data.closeHint || "";
        seatsEl.innerHTML = "";
        selectableSeats = [];

        seats.forEach(function (seat) {
            var hotkey = null;
            if (seat.free && selectableSeats.length < 9) {
                selectableSeats.push(seat.index);
                hotkey = selectableSeats.length;
            }

            seatsEl.appendChild(buildSeat(seat, hotkey, data.occupiedLabel || ""));
        });

        isOpen = true;
        panelEl.hidden = false;
        overlayEl.hidden = false;
        syncHint();
    }

    window.addEventListener("message", function (event) {
        var data = event.data || {};

        switch (data.action) {
            case "hint":
                hintEl.textContent = data.text || "";
                hintWanted = !!data.visible;
                syncHint();
                break;

            case "open":
                open(data);
                break;

            case "close":
                hide();
                break;
        }
    });

    document.addEventListener("keydown", function (event) {
        if (!isOpen) {
            return;
        }

        if (event.key === "Escape" || event.key === "Backspace") {
            event.preventDefault();
            closeUi();
            return;
        }

        // 数字キーで空席を直接選ぶ
        var n = parseInt(event.key, 10);
        if (!isNaN(n) && n >= 1 && n <= selectableSeats.length) {
            event.preventDefault();
            selectSeat(selectableSeats[n - 1]);
        }
    });

    // パネルの外側クリックで閉じる
    overlayEl.addEventListener("mousedown", function () {
        closeUi();
    });
})();
