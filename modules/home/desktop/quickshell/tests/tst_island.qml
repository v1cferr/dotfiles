// IslandMath: what the island shows when events compete (priority, in-place updates, the queue,
// the interrupted event's return, the freeze).
import QtQuick
import QtTest
import "../island"

TestCase {
    name: "Island"

    IslandMath {
        id: m
    }
    function ev(kind, id, ttl) {
        return m.event(kind, {}, ttl, id);
    }

    function test_an_empty_island_shows_what_arrives() {
        const s = m.push(m.idle, ev("bluetooth"), 1000);
        compare(s.current.kind, "bluetooth");
        compare(s.current.until, 4000, "a Bluetooth device stays 3 s");
        compare(s.seq, 1);
    }
    function test_the_same_event_updates_in_place() {
        let s = m.push(m.idle, m.event("volume", {
            level: 0.4
        }), 1000);
        s = m.push(s, m.event("volume", {
            level: 0.5
        }), 1400);
        compare(s.current.data.level, 0.5);
        compare(s.current.until, 2900, "its clock restarts from the last change");
        compare(s.seq, 1, "no new entrance: it is the same thing moving");
        compare(s.queue.length, 0);
    }
    function test_a_more_urgent_event_interrupts_and_the_other_returns_once() {
        let s = m.push(m.idle, ev("notification"), 0);
        s = m.push(s, ev("volume"), 1000);
        compare(s.current.kind, "volume");
        compare(s.queue.length, 1);
        compare(s.queue[0].ttl, 4000, "the notification keeps what it had left");
        s = m.tick(s, 2500);
        compare(s.current.kind, "notification");
        compare(s.current.until, 6500);
        s = m.push(s, ev("volume"), 3000);
        compare(s.queue.length, 0, "interrupted a second time, it does not come back");
    }
    function test_an_event_almost_over_does_not_return() {
        let s = m.push(m.idle, ev("bluetooth"), 0);
        s = m.push(s, ev("volume"), 2500);
        compare(s.queue.length, 0, "under a second left: not worth a second showing");
    }
    function test_a_less_urgent_event_waits_its_turn() {
        let s = m.push(m.idle, ev("volume"), 0);
        s = m.push(s, ev("bluetooth"), 100);
        s = m.push(s, ev("notification"), 200);
        compare(s.current.kind, "volume");
        s = m.tick(s, 1500);
        compare(s.current.kind, "notification", "the more urgent of the two that waited");
        s = m.tick(s, 6500);
        compare(s.current.kind, "bluetooth");
        s = m.tick(s, 9500);
        compare(s.current, null);
    }
    function test_tick_does_nothing_before_the_deadline() {
        const s = m.push(m.idle, ev("bluetooth"), 0);
        compare(m.tick(s, 2999), s);
    }
    function test_an_event_with_no_end_stays_and_survives_an_interruption() {
        let s = m.push(m.idle, ev("vpn", "fai", 0), 0);
        compare(m.deadline(s), 0, "connecting has no clock");
        s = m.push(s, ev("volume"), 1000);
        s = m.tick(s, 2500);
        compare(s.current.key, "vpn:fai", "still connecting, so still there");
        s = m.push(s, ev("vpn", "fai"), 3000);
        compare(s.current.until, 7000, "the result takes its place, with a clock");
        compare(s.seq, 3);
    }
    function test_two_vpns_are_two_events() {
        let s = m.push(m.idle, ev("vpn", "fai", 0), 0);
        s = m.push(s, ev("vpn", "ufscar", 0), 100);
        compare(s.current.key, "vpn:fai");
        compare(s.queue[0].key, "vpn:ufscar");
    }
    function test_a_frozen_island_changes_only_for_a_critical_event() {
        let s = m.push(m.idle, ev("notification"), 0);
        s = m.freeze(s, true, 2000);
        s = m.push(s, ev("volume"), 2500);
        compare(s.current.kind, "notification", "the pointer is on it: the volume waits");
        compare(m.tick(s, 9000).current.kind, "notification", "and its clock is stopped");
        s = m.push(s, ev("critical", "disk"), 3000);
        compare(s.current.kind, "critical");
    }
    function test_unfreezing_gives_back_what_was_left() {
        let s = m.push(m.idle, ev("notification"), 0);
        s = m.freeze(s, true, 2000);
        s = m.freeze(s, false, 9000);
        compare(s.current.until, 12000, "3 s were left when the pointer arrived");
        s = m.push(m.idle, ev("volume"), 0);
        s = m.freeze(s, true, 1400);
        s = m.freeze(s, false, 5000);
        compare(s.current.until, 6000, "never less than a second to read it");
    }
    function test_the_queue_keeps_one_per_key_and_drops_the_least_urgent() {
        let s = m.push(m.idle, ev("critical", "disk"), 0);
        for (const k of ["bluetooth", "notification", "vpn", "mic"])
            s = m.push(s, ev(k), 10);
        compare(s.queue.length, 3);
        compare(s.queue.map(e => e.kind).indexOf("bluetooth"), -1, "the least urgent left");
        s = m.push(s, ev("notification"), 20);
        compare(s.queue.filter(e => e.kind === "notification").length, 1);
    }
    function test_media_rests_in_the_island_and_returns_after_every_interruption() {
        let s = m.push(m.idle, ev("media"), 0);
        compare(m.deadline(s), 0, "playing has no clock");
        s = m.push(s, ev("volume"), 1000);
        compare(s.current.kind, "volume");
        s = m.tick(s, 2500);
        compare(s.current.kind, "media");
        s = m.push(s, ev("notification"), 3000);
        s = m.tick(s, 8000);
        compare(s.current.kind, "media", "interrupted twice, it is still what plays");
    }
    function test_a_new_track_updates_the_media_in_place() {
        let s = m.push(m.idle, m.event("media", {
            title: "one"
        }), 0);
        s = m.push(s, m.event("media", {
            title: "two"
        }), 5000);
        compare(s.current.data.title, "two");
        compare(s.seq, 1, "the same media, another title: no new entrance");
    }
    function test_pausing_removes_the_media_shown_or_waiting() {
        let s = m.push(m.idle, ev("media"), 0);
        s = m.drop(s, "media:", 100);
        compare(s.current, null);
        s = m.push(m.idle, ev("media"), 0);
        s = m.push(s, ev("volume"), 100);
        s = m.drop(s, "media:", 200);
        s = m.tick(s, 1600);
        compare(s.current, null, "paused while the volume showed: nothing to return to");
    }
    function test_the_queue_never_drops_an_event_with_no_end() {
        let s = m.push(m.idle, ev("critical", "disk"), 0);
        s = m.push(s, ev("media"), 5);
        for (const k of ["bluetooth", "notification", "vpn", "mic"])
            s = m.push(s, ev(k), 10);
        compare(s.queue.filter(e => e.kind === "media").length, 1, "the least urgent of all, and it stays");
        compare(s.queue.length, 4, "the media and three moments");
    }
    function test_drop_removes_an_event_wherever_it_is() {
        let s = m.push(m.idle, ev("critical", "disk"), 0);
        s = m.push(s, ev("bluetooth"), 10);
        s = m.drop(s, "bluetooth:", 20);
        compare(s.queue.length, 0);
        s = m.drop(s, "critical:disk", 30);
        compare(s.current, null);
    }
}
