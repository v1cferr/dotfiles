// The island's state machine, as pure functions: no Quickshell imports, so qmltestrunner can test
// it. Island.qml runs it. The priorities and the rules: docs/notes/desktop/island.md
import QtQml

QtObject {
    // Nothing shown, nothing waiting. `seq` counts every change of WHAT is shown, so a view can
    // tell a new event (an entrance) from the same one updating in place.
    readonly property var idle: ({
            current: null,
            queue: [],
            frozen: false,
            seq: 0
        })
    // Lower is more urgent. A level the user is setting beats a result, which beats news.
    readonly property var prio: ({
            critical: 1,
            volume: 3,
            mic: 3,
            brightness: 3,
            dpi: 3,
            vpn: 4,
            notification: 5,
            bluetooth: 6,
            media: 8
        })
    // How long each stays, in ms; 0 stays until something ends it.
    readonly property var life: ({
            critical: 0,
            volume: 1500,
            mic: 1500,
            brightness: 1500,
            dpi: 1500,
            vpn: 4000,
            notification: 5000,
            bluetooth: 3000,
            media: 0
        })
    readonly property int queueMax: 3
    readonly property int resumeFloor: 1000 // an interrupted event comes back only with this much left

    // `id` tells two events of one kind apart (two VPNs); events with one key update in place.
    function event(kind, data, ttl, id) {
        return {
            kind: kind,
            key: kind + ":" + (id || ""),
            prio: prio[kind] || 9,
            ttl: ttl === undefined ? (life[kind] || 0) : ttl,
            data: data || {},
            resumed: false,
            until: 0,
            left: 0
        };
    }
    function shown(s, ev, queue, now) {
        return {
            current: ev ? Object.assign({}, ev, {
                until: ev.ttl > 0 ? now + ev.ttl : 0
            }) : null,
            queue: queue,
            frozen: ev ? s.frozen : false,
            seq: s.seq + 1
        };
    }
    // One per key. Past the cap the least urgent MOMENT goes, the oldest of those first; an event
    // with no end is a state (media playing, a VPN connecting) and never leaves this way.
    function enqueue(queue, ev) {
        const q = queue.filter(e => e.key !== ev.key).concat([ev]);
        if (q.filter(e => e.ttl > 0).length <= queueMax)
            return q;
        let worst = -1;
        for (let i = 0; i < q.length; i++)
            if (q[i].ttl > 0 && (worst < 0 || q[i].prio > q[worst].prio))
                worst = i;
        return q.filter((e, i) => i !== worst);
    }
    function push(s, ev, now) {
        const c = s.current;
        if (!c)
            return shown(s, ev, s.queue, now);
        // The same thing again (the volume still moving, a VPN reaching its result): in place.
        if (c.key === ev.key)
            return Object.assign({}, s, {
                current: Object.assign({}, c, {
                    data: ev.data,
                    ttl: ev.ttl,
                    until: ev.ttl > 0 ? now + ev.ttl : 0,
                    left: ev.ttl
                })
            });
        // Held by the pointer or an open panel: only a critical event may take the place.
        if (s.frozen && ev.prio !== 1)
            return Object.assign({}, s, {
                queue: enqueue(s.queue, ev)
            });
        if (ev.prio < c.prio) {
            const left = c.until > 0 ? c.until - now : 0;
            let q = s.queue;
            // What was interrupted returns once, if it had time left; what has no end always returns.
            if (c.ttl === 0)
                q = enqueue(q, c);
            else if (left > resumeFloor && !c.resumed)
                q = enqueue(q, Object.assign({}, c, {
                    ttl: left,
                    resumed: true
                }));
            return shown(s, ev, q, now);
        }
        return Object.assign({}, s, {
            queue: enqueue(s.queue, ev)
        });
    }
    // The most urgent that waits, the oldest among equals; nothing waiting empties the island.
    function next(s, now) {
        if (s.queue.length === 0)
            return shown(s, null, [], now);
        let best = 0;
        for (let i = 1; i < s.queue.length; i++)
            if (s.queue[i].prio < s.queue[best].prio)
                best = i;
        return shown(s, s.queue[best], s.queue.filter((e, i) => i !== best), now);
    }
    function tick(s, now) {
        const c = s.current;
        if (!c || s.frozen || c.until === 0 || now < c.until)
            return s;
        return next(s, now);
    }
    // The user answered it, or what it reported is over: gone wherever it is.
    function drop(s, key, now) {
        if (s.current && s.current.key === key)
            return next(Object.assign({}, s, {
                frozen: false
            }), now);
        return Object.assign({}, s, {
            queue: s.queue.filter(e => e.key !== key)
        });
    }
    // The pointer rests on it, or its panel is open: the clock stops, and restarts with what was left.
    function freeze(s, on, now) {
        const c = s.current;
        if (!c || s.frozen === on)
            return s;
        if (on)
            return Object.assign({}, s, {
                frozen: true,
                current: Object.assign({}, c, {
                    left: c.until > 0 ? Math.max(0, c.until - now) : 0
                })
            });
        return Object.assign({}, s, {
            frozen: false,
            current: Object.assign({}, c, {
                until: c.ttl > 0 ? now + Math.max(c.left, resumeFloor) : 0
            })
        });
    }
    // When the timer must fire next; 0 means never.
    function deadline(s) {
        return !s.current || s.frozen ? 0 : s.current.until;
    }
}
